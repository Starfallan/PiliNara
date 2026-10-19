import 'dart:async' show unawaited;

import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/services/download/download_library_service.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';

/// 文件夹里一个条目解析后的样子。
///
/// 能列出来就说明至少还有一个成员；成员暂时被删光的条目会消失，缓存再下回来
/// 又会自己出现，不需要用户重新加一次。
class ResolvedFolderItem {
  final DownloadFolderItem item;

  /// 所属合集：合集条目就是它自己，视频页 / 单个视频条目是它所在的合集。
  final DownloadSeasonInfo? season;
  final DownloadPageInfo? page;
  final BiliDownloadEntryInfo? entry;

  /// 实时成员，顺序与播放列表一致。
  final List<BiliDownloadEntryInfo> entries;

  const ResolvedFolderItem({
    required this.item,
    required this.entries,
    this.season,
    this.page,
    this.entry,
  });
}

/// 手动文件夹：用户自己分的组，成员是有序的顶层条目。
///
/// 与自动分组（合集 / 视频页 / 分P）互不干涉：后者由条目自身的归属推导，删条目
/// 即自动出组；这里只维护用户显式建立的关联。合集与视频页条目只记容器标识，
/// 成员在读取时实时解析，所以合集新缓存的集数会自己出现在那张卡片里；独立条目
/// 记 cid，条目被删就要修剪掉。
class DownloadFolderService extends GetxService {
  static const _version = 2;

  final _downloadService = Get.find<DownloadService>();

  /// 延后取，避免与 [DownloadLibraryService] 在构造期互相查找。
  DownloadLibraryService get _library => Get.find<DownloadLibraryService>();

  final flagNotifier = SetNotifier();

  /// 按用户排出的顺序暴露，UI 直接消费。
  final folders = RxList<DownloadFolder>();

  final List<DownloadFolder> _records = <DownloadFolder>[];
  final List<String> _folderOrder = <String>[];

  late final Future<void> waitForInitialization;

  @override
  void onInit() {
    super.onInit();
    waitForInitialization = _init();
  }

  @override
  void onClose() {
    _downloadService.flagNotifier.remove(_onDownloadChanged);
    super.onClose();
  }

  Future<void> _init() async {
    await _downloadService.waitForInitialization;
    // 新键不存在时才尝试导入旧数据，导入后立即落盘，之后不再重复导入。
    if (!_readFromStorage() && _importLegacy()) {
      await _save();
    } else {
      _publish();
    }
    await syncWithDownloads(notify: false);
    _downloadService.flagNotifier.add(_onDownloadChanged);
  }

  void _onDownloadChanged() => unawaited(syncWithDownloads());

  /// 读新键；返回是否读到了已保存的数据。
  bool _readFromStorage() {
    final raw = GStorage.localCache.get(LocalCacheKey.downloadFolders);
    if (raw is! Map) {
      return false;
    }
    final json = raw.cast<dynamic, dynamic>();
    final validCids = _validCids();
    _records
      ..clear()
      ..addAll([
        for (final item in (json['folders'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => item.cast<dynamic, dynamic>()))
          DownloadFolder(
            id: item['id'] as String,
            title: item['title'] as String? ?? '',
            createdAt: item['createdAt'] as int? ?? 0,
            items: _readItems(item, validCids),
          ),
      ]);
    _folderOrder
      ..clear()
      ..addAll(
        (json['folderOrder'] as List? ?? const <dynamic>[]).whereType<String>(),
      );
    _publish();
    return true;
  }

  /// 一次性导入旧数据，只取用户手工建的文件夹。
  ///
  /// 旧 `downloadCollections` 里自动归组的那些带 `sourceKey`，内容现在由
  /// `season_info` 表达，一并导入会与合集卡片重复，所以只接收没有 `sourceKey`
  /// 的；成员按现有缓存过滤，空文件夹不再恢复。
  bool _importLegacy() {
    final raw = GStorage.localCache.get(
      LocalCacheKey.legacyDownloadCollections,
    );
    if (raw is! Map) {
      return false;
    }
    final json = raw.cast<dynamic, dynamic>();
    final validCids = _validCids();
    final legacyOrder = (json['folderOrder'] as List? ?? const <dynamic>[])
        .whereType<String>()
        .toList();
    final manual = (json['folders'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => item.cast<dynamic, dynamic>())
        .where((item) => item['sourceKey'] == null)
        .toList()
      // 沿用当时的文件夹顺序，顺序键缺失的排在后面。
      ..sort((a, b) {
        final aIndex = legacyOrder.indexOf(a['id'] as String? ?? '');
        final bIndex = legacyOrder.indexOf(b['id'] as String? ?? '');
        return (aIndex < 0 ? legacyOrder.length : aIndex).compareTo(
          bIndex < 0 ? legacyOrder.length : bIndex,
        );
      });
    var stamp = DateTime.now().microsecondsSinceEpoch;
    for (final item in manual) {
      final items = _readItems(item, validCids);
      if (items.isEmpty) {
        continue;
      }
      final folder = DownloadFolder(
        id: item['id'] as String? ?? (stamp++).toString(),
        title: item['title'] as String? ?? '',
        createdAt: item['createdAt'] as int? ?? 0,
        items: items,
      );
      _records.add(folder);
      _folderOrder.add(folder.id);
    }
    _publish();
    return _records.isNotEmpty;
  }

  /// 读一条文件夹记录里的条目。
  ///
  /// 已经是结构化条目的直接收下；只剩扁平 cid 的（内部版本的 `videoCids`，以及
  /// 更早的 `downloadCollections`）按归属重组一次，不做逐条兼容。
  List<DownloadFolderItem> _readItems(
    Map<dynamic, dynamic> json,
    Set<int> validCids,
  ) {
    if (json['items'] is List) {
      return (json['items'] as List)
          .whereType<Map>()
          .map(
            (item) => DownloadFolderItem.fromJson(item.cast<String, dynamic>()),
          )
          .whereType<DownloadFolderItem>()
          .toList();
    }
    final cids = (json['videoCids'] as List? ?? const <dynamic>[])
        .whereType<int>()
        .where(validCids.contains);
    return _regroupCids(cids);
  }

  /// 把一批扁平 cid 还原成结构化条目。
  ///
  /// 当时整份合集 / 整个视频都放进来了，就还原成那张聚合卡片（此后新缓存的集数
  /// 会自己跟上）；只放了其中一部分，就按原样留成独立条目——不能因为在分组里
  /// 就悄悄扩容成整个合集。
  List<DownloadFolderItem> _regroupCids(Iterable<int> cids) {
    final byCid = {
      for (final entry in _downloadService.downloadList) entry.cid: entry,
    };
    final members = cids
        .map((cid) => byCid[cid])
        .whereType<BiliDownloadEntryInfo>()
        .toList();
    if (members.isEmpty) {
      return const <DownloadFolderItem>[];
    }
    final all = _downloadService.downloadList;
    final items = <DownloadFolderItem>[];
    for (final group in DownloadLibraryService.groupSeasons(members)) {
      final seasonInfo = group.seasonInfo;
      if (seasonInfo != null) {
        final member = [for (final page in group.pages) ...page.entries];
        final total = all
            .where((entry) => entry.seasonInfo == seasonInfo)
            .length;
        if (member.length >= total) {
          items.add(DownloadFolderItem.season(group.playlistKey));
        } else {
          items.addAll(DownloadFolderItem.ofEntries(member));
        }
        continue;
      }
      final page = group.pages.first;
      final total = all.where((entry) => entry.pageId == page.pageId).length;
      if (page.entries.length > 1 && page.entries.length >= total) {
        items.add(DownloadFolderItem.page(page.pageId));
      } else {
        items.addAll(DownloadFolderItem.ofEntries(page.entries));
      }
    }
    return items;
  }

  Future<void> _save() {
    _publish();
    return GStorage.localCache.put(LocalCacheKey.downloadFolders, {
      'version': _version,
      'folders': _records.map((item) => item.toJson()).toList(),
      'folderOrder': _folderOrder,
    });
  }

  void _publish() {
    final ordered = <DownloadFolder>[];
    for (final id in _folderOrder) {
      final folder = _records.firstWhereOrNull((item) => item.id == id);
      if (folder != null) {
        ordered.add(folder);
      }
    }
    // 顺序键里没有的（新建后未落盘、导入时缺失）按创建时间倒序补在后面。
    ordered.addAll(
      _records.where((item) => !_folderOrder.contains(item.id)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
    folders.value = ordered;
    flagNotifier.refresh();
  }

  Set<int> _validCids() => _downloadService.downloadList
      .followedBy(_downloadService.waitDownloadQueue)
      .map((item) => item.cid)
      .toSet();

  DownloadFolder? getFolder(String folderId) =>
      _records.firstWhereOrNull((item) => item.id == folderId);

  /// 条目实时成员：独立条目就是它自己，视频页 / 合集条目按当前缓存取。
  List<BiliDownloadEntryInfo> resolveItemEntries(DownloadFolderItem item) {
    switch (item.kind) {
      case DownloadFolderItemKind.entry:
        final cid = item.cid;
        final entry =
            _downloadService.downloadList.firstWhereOrNull(
              (e) => e.cid == cid,
            ) ??
            _downloadService.waitDownloadQueue.firstWhereOrNull(
              (e) => e.cid == cid,
            );
        return entry == null ? const [] : [entry];
      case DownloadFolderItemKind.page:
        final page = _pageOf(item.id!);
        return page == null ? const [] : _library.entriesOfPage(page);
      case DownloadFolderItemKind.season:
        final season = _library.seasonByKey(item.id!);
        return season == null ? const [] : _library.entriesOfSeason(season);
    }
  }

  /// 文件夹里还列得出来的条目，按用户排出的顶层顺序。
  List<ResolvedFolderItem> resolveItems(String folderId) {
    final folder = getFolder(folderId);
    if (folder == null) {
      return const <ResolvedFolderItem>[];
    }
    return [for (final item in folder.items) ?resolveItem(item)];
  }

  /// 解析一个条目；成员全没了就返回空，调用点据此把它藏起来。
  ResolvedFolderItem? resolveItem(DownloadFolderItem item) {
    switch (item.kind) {
      case DownloadFolderItemKind.entry:
        final entries = resolveItemEntries(item);
        if (entries.isEmpty) {
          return null;
        }
        return ResolvedFolderItem(
          item: item,
          entries: entries,
          entry: entries.first,
        );
      case DownloadFolderItemKind.page:
        final season = _seasonOfPage(item.id!);
        final page = season?.pages.firstWhereOrNull(
          (page) => page.pageId == item.id,
        );
        if (page == null) {
          return null;
        }
        final entries = _library.entriesOfPage(page);
        if (entries.isEmpty) {
          return null;
        }
        return ResolvedFolderItem(
          item: item,
          entries: entries,
          season: season,
          page: page,
        );
      case DownloadFolderItemKind.season:
        final season = _library.seasonByKey(item.id!);
        if (season == null) {
          return null;
        }
        final entries = _library.entriesOfSeason(season);
        if (entries.isEmpty) {
          return null;
        }
        return ResolvedFolderItem(
          item: item,
          entries: entries,
          season: season,
        );
    }
  }

  /// 整个文件夹的成员，按顶层条目顺序递归摊平；「播放全部」与导出都用它。
  List<BiliDownloadEntryInfo> resolveFolderEntries(String folderId) {
    final folder = getFolder(folderId);
    if (folder == null) {
      return const <BiliDownloadEntryInfo>[];
    }
    return [for (final item in folder.items) ...resolveItemEntries(item)];
  }

  DownloadPageInfo? _pageOf(String pageId) => _seasonOfPage(
    pageId,
  )?.pages.firstWhereOrNull((page) => page.pageId == pageId);

  DownloadSeasonInfo? _seasonOfPage(String pageId) => _library.seasons
      .firstWhereOrNull((item) => item.pages.any((p) => p.pageId == pageId));

  String buildDefaultFolderTitle([String base = '新建文件夹']) {
    final titles = _records.map((item) => item.title).toSet();
    if (!titles.contains(base)) {
      return base;
    }
    var index = 2;
    while (titles.contains('$base $index')) {
      index++;
    }
    return '$base $index';
  }

  Future<DownloadFolder> createFolder(String title) async {
    final folder = DownloadFolder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      items: <DownloadFolderItem>[],
    );
    _records.add(folder);
    _folderOrder.add(folder.id);
    await _save();
    return folder;
  }

  Future<void> renameFolder(String folderId, String title) async {
    final folder = getFolder(folderId);
    if (folder == null || folder.title == title) {
      return;
    }
    folder.title = title;
    await _save();
  }

  /// 删除文件夹只断开关联，缓存文件与自动分组都不受影响。
  Future<void> deleteFolder(String folderId) async {
    _records.removeWhere((item) => item.id == folderId);
    _folderOrder.removeWhere((id) => id == folderId);
    await _save();
  }

  Future<void> reorderFolders(List<String> folderIds) async {
    _folderOrder
      ..clear()
      ..addAll(folderIds);
    await _save();
  }

  /// 把条目加进文件夹，返回真正新加进去的条数。
  ///
  /// 同一个视频不会在文件夹里出现两次：加进来的是聚合条目（整份合集 / 整个
  /// 视频）时，本来单独放着的那些成员由它接管，一并撤掉；加进来的是单个视频，
  /// 而它已经被文件夹里的某张卡片装着时，就什么都不做。
  Future<int> addItemsToFolders(
    Iterable<DownloadFolderItem> items,
    Iterable<String> folderIds,
  ) async {
    final list = items.toList(growable: false);
    if (list.isEmpty) {
      return 0;
    }
    var added = 0;
    var changed = false;
    for (final folderId in folderIds) {
      final folder = getFolder(folderId);
      if (folder == null) {
        continue;
      }
      final existing = folder.items.map((item) => item.key).toSet();
      final incoming = [
        for (final item in list)
          if (existing.add(item.key)) item,
      ];
      if (incoming.isEmpty) {
        continue;
      }
      final covered = <int>{
        for (final item in incoming) ...resolveItemEntries(item).map((e) => e.cid),
      };
      final before = folder.items.length;
      folder.items.removeWhere(
        (item) => resolveItemEntries(
          item,
        ).every((entry) => covered.contains(entry.cid)),
      );
      if (folder.items.length != before || incoming.length != list.length) {
        changed = true;
      }
      folder.items.addAll(incoming);
      added += incoming.length;
      changed = true;
    }
    if (changed) {
      await _save();
    }
    return added;
  }

  Future<void> removeItemsFromFolders(
    Iterable<DownloadFolderItem> items,
    Iterable<String> folderIds,
  ) async {
    final keys = items.map((item) => item.key).toSet();
    if (keys.isEmpty) {
      return;
    }
    var changed = false;
    for (final folderId in folderIds) {
      final folder = getFolder(folderId);
      if (folder == null) {
        continue;
      }
      final before = folder.items.length;
      folder.items.removeWhere((item) => keys.contains(item.key));
      if (folder.items.length != before) {
        changed = true;
      }
    }
    if (changed) {
      await _save();
    }
  }

  /// 写入顶层顺序。
  ///
  /// [items] 是排序页里看得到的那些条目，顺序即新顺序；看不见的条目（成员全被
  /// 删掉的）排在后面，保持原有相对顺序。
  Future<void> reorderItems(
    String folderId,
    List<DownloadFolderItem> items,
  ) async {
    final folder = getFolder(folderId);
    if (folder == null) {
      return;
    }
    final keys = items.map((item) => item.key).toSet();
    folder.items
      ..clear()
      ..addAll(items)
      ..addAll(folder.items.where((item) => !keys.contains(item.key)));
    await _save();
  }

  /// 按合集原顺序重排顶层条目：合集成员先按 `SeasonInfo.id`，再按
  /// `SeasonInfo.index`，最后按页内 / 分P 序号；不属于任何合集的排在后面，
  /// 各自保持原有相对顺序。
  ///
  /// 对只装零散视频的文件夹是空操作。
  Future<void> applyCollectionOrder(String folderId) async {
    final folder = getFolder(folderId);
    if (folder == null || folder.items.length < 2) {
      return;
    }
    final origin = {
      for (var i = 0; i < folder.items.length; i++) folder.items[i].key: i,
    };
    final sorted = folder.items.toList()
      ..sort((a, b) {
        final aKey = _collectionKey(a);
        final bKey = _collectionKey(b);
        if (aKey == null || bKey == null) {
          if (aKey != null || bKey != null) {
            return aKey == null ? 1 : -1;
          }
        } else {
          for (var i = 0; i < aKey.length; i++) {
            final byKey = aKey[i].compareTo(bKey[i]);
            if (byKey != 0) {
              return byKey;
            }
          }
        }
        return origin[a.key]!.compareTo(origin[b.key]!);
      });
    await reorderItems(folderId, sorted);
  }

  /// 条目的合集排序键：不属于任何合集的返回空。
  List<int>? _collectionKey(DownloadFolderItem item) {
    final entry = _representativeEntry(item);
    final seasonInfo = entry?.seasonInfo;
    if (seasonInfo == null) {
      return null;
    }
    return [seasonInfo.id, seasonInfo.index, entry!.sortKey];
  }

  /// 代表条目：聚合条目取它排在最前的那条成员，独立条目就是它自己。
  BiliDownloadEntryInfo? _representativeEntry(DownloadFolderItem item) =>
      resolveItemEntries(item).firstOrNull;

  /// 按缓存时间重排顶层条目，新缓存的在前；聚合条目按它最新的一条成员算。
  Future<void> resetFolderOrder(String folderId) async {
    final folder = getFolder(folderId);
    if (folder == null || folder.items.length < 2) {
      return;
    }
    final origin = {
      for (var i = 0; i < folder.items.length; i++) folder.items[i].key: i,
    };
    final stamps = {
      for (final item in folder.items) item.key: _latestStamp(item),
    };
    final sorted = folder.items.toList()
      ..sort((a, b) {
        final byStamp = stamps[b.key]!.compareTo(stamps[a.key]!);
        return byStamp != 0 ? byStamp : origin[a.key]!.compareTo(origin[b.key]!);
      });
    await reorderItems(folderId, sorted);
  }

  int _latestStamp(DownloadFolderItem item) {
    var latest = 0;
    for (final entry in resolveItemEntries(item)) {
      if (entry.timeUpdateStamp > latest) {
        latest = entry.timeUpdateStamp;
      }
    }
    return latest;
  }

  /// 修剪被删掉的独立条目。
  ///
  /// 合集 / 视频页条目留着：成员删了可以再下回来，那张卡片会自己恢复，不需要
  /// 用户重新加一次。
  Future<void> syncWithDownloads({bool notify = true}) async {
    final validCids = _validCids();
    var changed = false;
    for (final folder in _records) {
      final before = folder.items.length;
      folder.items.removeWhere(
        (item) =>
            item.kind == DownloadFolderItemKind.entry &&
            !validCids.contains(item.cid),
      );
      if (folder.items.length != before) {
        changed = true;
      }
    }
    if (changed) {
      await _save();
    } else if (notify) {
      flagNotifier.refresh();
    }
  }
}

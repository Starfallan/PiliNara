import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show MultiSelectData;

/// 文件夹条目的类型：单条缓存、一个视频（分P 视频 / PGC 一季）、一个合集。
enum DownloadFolderItemKind {
  entry,
  page,
  season,
}

/// 文件夹里的一个顶层条目。
///
/// `page` / `season` 只记容器标识，成员在读取时按当前缓存实时解析：这张卡片
/// 就是自动分组里那张卡片的替身，合集后来新缓存的集数会自己出现在里面，分P
/// 新增的 P 也一样。`entry` 相反，永远指向固定的那一条缓存。
///
/// 文件夹只有这一层：条目只能是这三类，结构上就不存在文件夹套文件夹。
class DownloadFolderItem with MultiSelectData {
  final DownloadFolderItemKind kind;

  /// `page` 记 pageId；`season` 记 DownloadSeasonInfo.playlistKey。
  final String? id;

  /// `entry` 记 cid。
  final int? cid;

  DownloadFolderItem._({required this.kind, this.id, this.cid});

  DownloadFolderItem.entry(int cid)
    : this._(kind: DownloadFolderItemKind.entry, cid: cid);

  DownloadFolderItem.page(String pageId)
    : this._(kind: DownloadFolderItemKind.page, id: pageId);

  DownloadFolderItem.season(String seasonKey)
    : this._(kind: DownloadFolderItemKind.season, id: seasonKey);

  /// 在分组内部勾选得到的一组独立条目。
  static List<DownloadFolderItem> ofEntries(
    Iterable<BiliDownloadEntryInfo> entries,
  ) => [for (final entry in entries) DownloadFolderItem.entry(entry.cid)];

  /// 身份键：同一文件夹内靠它去重，也靠它判断某条是不是已经被移出。
  String get key => switch (kind) {
    DownloadFolderItemKind.entry => 'entry:$cid',
    DownloadFolderItemKind.page => 'page:$id',
    DownloadFolderItemKind.season => 'season:$id',
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    if (cid != null) 'cid': cid,
    if (id != null) 'id': id,
  };

  static DownloadFolderItem? fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final id = json['id'];
    final cid = json['cid'];
    if (kind == 'entry' && cid is int) {
      return DownloadFolderItem.entry(cid);
    }
    if (id is! String || id.isEmpty) {
      return null;
    }
    return switch (kind) {
      'page' => DownloadFolderItem.page(id),
      'season' => DownloadFolderItem.season(id),
      _ => null,
    };
  }
}

/// 手动文件夹：用户自己取名的缓存集合，成员是有序的顶层条目。
///
/// 只表达「用户把它们放在一起」这一层意图与顶层顺序；合集 / 视频页 / 分P 的
/// 内部结构由条目自身推导，不进这里，所以合集新缓存的集数会自己跟进来，删条目
/// 也不会留下需要清理的关联。
class DownloadFolder {
  final String id;
  String title;
  final int createdAt;
  final List<DownloadFolderItem> items;

  DownloadFolder({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.items,
  });

  factory DownloadFolder.fromJson(Map<String, dynamic> json) => DownloadFolder(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    createdAt: json['createdAt'] as int? ?? 0,
    items: (json['items'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => DownloadFolderItem.fromJson(item.cast<String, dynamic>()))
        .whereType<DownloadFolderItem>()
        .toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'createdAt': createdAt,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

/// 粒度按「勾选发生在哪一层」决定：在缓存首页选中整张分组卡片，就存成对应的
/// 聚合条目；在分组内部勾选具体条目，一律存成独立条目，哪怕整组都被选上了。
extension DownloadSeasonFolderItem on DownloadSeasonInfo {
  DownloadFolderItem toFolderItem() {
    if (seasonInfo != null && pages.length > 1) {
      return DownloadFolderItem.season(playlistKey);
    }
    final page = pages.first;
    return page.entries.length > 1
        ? DownloadFolderItem.page(page.pageId)
        : DownloadFolderItem.entry(page.entries.first.cid);
  }
}

/// 视频页卡片的粒度同上：多P / 整季存成视频页条目，只有一个条目时存成独立条目。
extension DownloadPageFolderItem on DownloadPageInfo {
  DownloadFolderItem toFolderItem() => entries.length > 1
      ? DownloadFolderItem.page(pageId)
      : DownloadFolderItem.entry(entries.first.cid);
}

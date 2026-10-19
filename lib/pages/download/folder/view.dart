import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/flutter/popup_menu.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/models_new/download/download_playback.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show BaseMultiSelectMixin;
import 'package:PiliPlus/pages/download/detail/widgets/item.dart';
import 'package:PiliPlus/pages/download/download/widgets/page.dart';
import 'package:PiliPlus/pages/download/download/widgets/season.dart';
import 'package:PiliPlus/pages/download/download_action_mixin.dart';
import 'package:PiliPlus/pages/download/folder_sort/view.dart';
import 'package:PiliPlus/pages/download/utils/cache_delete_confirm.dart';
import 'package:PiliPlus/pages/download/utils/cache_export.dart';
import 'package:PiliPlus/pages/download/utils/card_menu.dart';
import 'package:PiliPlus/pages/download/utils/open_download_entry.dart';
import 'package:PiliPlus/pages/download/widgets/folder_dialog.dart';
import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:PiliPlus/services/download/download_library_service.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

enum _FolderSortAction {
  manual,
  collection,
  cacheTime,
}

/// 手动文件夹的详情：按用户排出的顶层顺序列出成员。
///
/// 合集卡与视频页卡是自动分组里那张卡片的替身，成员按当前缓存实时解析，所以
/// 点进合集卡只加载这一个合集，符合「我只想看这个系列」的直觉；要连播整个
/// 文件夹用「播放全部」，它把成员递归摊平成一维列表后交给播放器，播放器仍然
/// 只处理平铺列表。
class DownloadFolderPage extends StatefulWidget {
  const DownloadFolderPage({
    super.key,
    required this.folderId,
  });

  final String folderId;

  @override
  State<DownloadFolderPage> createState() => _DownloadFolderPageState();
}

class _DownloadFolderPageState extends State<DownloadFolderPage>
    with
        BaseMultiSelectMixin<DownloadFolderItem>,
        GridMixin,
        BaseDownloadActionMixin<DownloadFolderPage, DownloadFolderItem> {
  final _folderService = Get.find<DownloadFolderService>();
  final _libraryService = Get.find<DownloadLibraryService>();
  final _resolved = RxList<ResolvedFolderItem>();
  final _progress = ChangeNotifier();

  bool _isOpening = false;

  @override
  List<DownloadFolderItem> get list => [
    for (final resolved in _resolved) resolved.item,
  ];

  @override
  RxList<ResolvedFolderItem> get state => _resolved;

  @override
  final downloadService = Get.find<DownloadService>();

  @override
  BaseMultiSelectMixin<DownloadFolderItem> get multiSelectCtr => this;

  @override
  void initState() {
    super.initState();
    _loadList();
    _folderService.flagNotifier.add(_loadList);
  }

  @override
  void dispose() {
    _progress.dispose();
    _folderService.flagNotifier.remove(_loadList);
    super.dispose();
  }

  Future<void> _loadList() async {
    await _folderService.waitForInitialization;
    if (!mounted) {
      return;
    }
    final hadItems = _resolved.isNotEmpty;
    if (_folderService.getFolder(widget.folderId) == null) {
      _resolved.clear();
      // 文件夹被删掉时退出这一层，避免停在空列表上。
      if (hadItems && mounted) {
        Get.back();
      }
      return;
    }
    final checkedBefore = checkedCount;
    _resolved.value = _folderService.resolveItems(widget.folderId);
    rxCount.value = allChecked.length;
    // 刷新只校正计数：多选态下一条都还没勾时，不该被后台的缓存变化顶掉。
    if (rxCount.value == 0 && checkedBefore > 0) {
      enableMultiSelect.value = false;
    }
  }

  Future<void> _addSelectedToFolder() async {
    final items = allChecked.toList();
    if (items.isEmpty) {
      return;
    }
    final folderIds = await showDownloadFolderPickerDialog(context: context);
    if (folderIds == null || folderIds.isEmpty) {
      return;
    }
    final added = await _folderService.addItemsToFolders(items, folderIds);
    handleSelect();
    SmartDialog.showToast(added == 0 ? '已经在文件夹里了' : '已添加到文件夹');
  }

  @override
  void onRemove() {
    final items = allChecked.toList();
    if (items.isEmpty) {
      return;
    }
    confirmRemoveFromFolders(
      context: context,
      folderId: widget.folderId,
      items: items,
    ).then((removed) {
      if (removed && mounted) {
        handleSelect();
      }
    });
  }

  Future<void> _exportSelected() async {
    final entries = [
      for (final item in allChecked)
        ..._folderService.resolveItemEntries(item),
    ];
    handleSelect();
    if (entries.isEmpty) {
      SmartDialog.showToast('选中的内容里没有可导出的缓存');
      return;
    }
    await exportDownloadEntries(entries);
  }

  @override
  Future<void> onUpdate(
    Future<bool> Function(BiliDownloadEntryInfo e) toElement,
  ) async {
    if (checkUpdateCount(checkedCount)) {
      return;
    }
    final entries = <int, BiliDownloadEntryInfo>{
      for (final item in allChecked)
        for (final entry in _folderService.resolveItemEntries(item))
          entry.cid: entry,
    };
    if (entries.isEmpty) {
      return;
    }

    bool dismiss = false;
    SmartDialog.showLoading(
      onDismiss: () {
        dismiss = true;
        handleSelect();
      },
    );

    bool isSuccess = true;
    for (final chunk in entries.values.mapChunked(
      kUpdateConcurrency,
      toElement,
    )) {
      final res = await Future.wait(chunk);
      if (res.any((e) => !e)) isSuccess = false;
      if (dismiss) break;
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  /// 播放全部：把文件夹下所有单视频、合集里的子视频、分P 里的子视频现场递归
  /// 摊平成一维列表交给播放器。
  ///
  /// 播放列表本身由 [DownloadLibraryService.resolvePlaylist] 按同一顺序给出，
  /// 播放器不用认识任何嵌套；这里只是从摊平后的第一条起播。
  Future<void> _playAll() async {
    if (_isOpening) {
      return;
    }
    final entries = _folderService
        .resolveFolderEntries(widget.folderId)
        .where((entry) => entry.isCompleted)
        .toList();
    if (entries.isEmpty) {
      SmartDialog.showToast('文件夹里还没有能播放的缓存');
      return;
    }
    setState(() {
      _isOpening = true;
    });
    try {
      await openDownloadEntry(
        entry: entries.first,
        playContext: DownloadVideoPlayContext.folder(widget.folderId),
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) {
        return;
      }
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      _progress.notifyListeners();
      await _libraryService.refreshContinueTarget();
    } finally {
      if (mounted) {
        setState(() {
          _isOpening = false;
        });
      }
    }
  }

  Future<void> _openSortPage() async {
    if (_resolved.isEmpty) {
      return;
    }
    await Get.to(
      DownloadFolderSortPage(
        folderId: widget.folderId,
        title: '排序: ${_folderService.getFolder(widget.folderId)?.title ?? ''}',
      ),
    );
  }

  Future<void> _applyCollectionOrder() async {
    await _folderService.applyCollectionOrder(widget.folderId);
    SmartDialog.showToast('已按合集顺序排列');
  }

  Future<void> _resetOrder() async {
    await _folderService.resetFolderOrder(widget.folderId);
    SmartDialog.showToast('已按缓存时间排列');
  }

  void _onSortSelected(_FolderSortAction action) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      switch (action) {
        case _FolderSortAction.manual:
          await _openSortPage();
        case _FolderSortAction.collection:
          await _applyCollectionOrder();
        case _FolderSortAction.cacheTime:
          await _resetOrder();
      }
    });
  }

  Future<void> _renameFolder() async {
    final currentTitle = _folderService.getFolder(widget.folderId)?.title ?? '';
    final name = await showDownloadFolderNameDialog(
      context: context,
      title: '重命名文件夹',
      initialValue: currentTitle,
    );
    if (name == null || name == currentTitle) {
      return;
    }
    await _folderService.renameFolder(widget.folderId, name);
  }

  Future<void> _deleteFolder() async {
    final folder = _folderService.getFolder(widget.folderId);
    if (folder == null) {
      return;
    }
    final deleted = await confirmDeleteFolders(
      context: context,
      folders: [folder],
    );
    if (deleted && mounted) {
      Get.back();
    }
  }

  Widget _buildSortBtn() {
    return Builder(
      builder: (context) => IconButton(
        tooltip: '排序',
        icon: const Icon(Icons.sort),
        onPressed: () {
          showStaticPositionMenu<_FolderSortAction>(
            context: context,
            items: const [
              CustomPopupMenuItem(
                value: _FolderSortAction.manual,
                child: Text('手动排序'),
              ),
              CustomPopupMenuItem(
                value: _FolderSortAction.collection,
                child: Text('按合集顺序'),
              ),
              CustomPopupMenuItem(
                value: _FolderSortAction.cacheTime,
                child: Text('按缓存时间'),
              ),
            ],
          ).then((value) {
            if (value != null) {
              _onSortSelected(value);
            }
          });
        },
      ),
    );
  }

  Widget _buildFolderMenu() {
    return Builder(
      builder: (context) => IconButton(
        tooltip: '文件夹',
        icon: const Icon(Icons.more_vert),
        onPressed: () {
          showStaticPositionMenu<int>(
            context: context,
            items: [
              const CustomPopupMenuItem(value: 0, child: Text('重命名')),
              CustomPopupMenuItem(
                value: 1,
                child: Text(
                  '删除文件夹',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ).then((value) {
            if (value == 0) {
              _renameFolder();
            } else if (value == 1) {
              _deleteFolder();
            }
          });
        },
      ),
    );
  }

  Widget _buildPlayFab() {
    final padding = MediaQuery.viewPaddingOf(context);
    return Padding(
      padding: EdgeInsets.only(
        right: padding.right + 16,
        bottom: padding.bottom + 16,
      ),
      child: FloatingActionButton.extended(
        onPressed: _playAll,
        icon: const Icon(Icons.play_arrow),
        label: const Text('播放全部'),
      ),
    );
  }

  /// 与缓存首页同一套渲染规则：多视频合集单独成卡，多P / 整季的视频页成一张
  /// 卡，只有一个条目时平铺成单视频。所以同一个合集在文件夹里和首页长得一样。
  Widget _buildItem(
    ResolvedFolderItem resolved,
    bool multiSelect,
  ) {
    final item = resolved.item;
    final season = resolved.season;
    final seasonInfo = season?.seasonInfo;

    if (season != null && seasonInfo != null && season.pages.length > 1) {
      return SeasonInfoItem(
        controller: this,
        downloadService: downloadService,
        season: season,
        seasonInfo: seasonInfo,
        selectable: item,
        enableMultiSelect: multiSelect,
        progress: _progress,
        updateSeasonDm: updateSeasonDm,
      );
    }

    final page = resolved.page ?? season?.pages.firstOrNull;
    if (page != null && page.entries.length > 1) {
      return PageInfoItem(
        controller: this,
        downloadService: downloadService,
        selectable: item,
        pageInfo: page,
        seasonKey: season?.playlistKey ?? '',
        enableMultiSelect: multiSelect,
        progress: _progress,
        updatePageDm: updatePageDm,
      );
    }

    final entry = resolved.entry ?? resolved.entries.first;
    return DetailItem(
      entry: entry,
      progress: _progress,
      downloadService: downloadService,
      showTitle: true,
      controller: this,
      checked: item.checked,
      onSelect: (_) => onSelect(item),
      playContext: DownloadVideoPlayContext.folder(widget.folderId),
      onDelete: () => deleteLocalEntries(
        downloadService: downloadService,
        entries: [entry],
      ),
      customOnLongPress: () {
        enableMultiSelect.value = true;
        onSelect(item);
      },
      extraMoreItemsBuilder: (menuContext) => [
        CustomPopupMenuItem<void>(
          height: 38,
          child: const Text('移出文件夹', style: TextStyle(fontSize: 13)),
          onTap: () => confirmRemoveFromFolders(
            context: menuContext,
            folderId: widget.folderId,
            items: [item],
          ),
        ),
        ...buildAddToFolderMenuItems(context: menuContext, items: [item]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enableMultiSelect = this.enableMultiSelect.value;
      final folder = _folderService.getFolder(widget.folderId);
      final playable = _folderService
          .resolveFolderEntries(widget.folderId)
          .any((entry) => entry.isCompleted);
      return popScope(
        canPop: !enableMultiSelect,
        onPopInvokedWithResult: (didPop, result) {
          if (enableMultiSelect) {
            handleSelect();
          }
        },
        child: SimpleScaffold(
          appBar: MultiSelectAppBarWidget(
            ctr: this,
            visible: enableMultiSelect,
            actions: [
              updateBtn(),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: checkedCount == 0 ? null : _addSelectedToFolder,
                child: const Text('添加到'),
              ),
              if (Platform.isAndroid)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: checkedCount == 0 ? null : _exportSelected,
                  child: const Text('导出'),
                ),
            ],
            child: AppBar(
              title: Text(folder?.title ?? '文件夹'),
              actions: [
                _buildSortBtn(),
                _buildFolderMenu(),
                IconButton(
                  tooltip: '多选',
                  onPressed: () {
                    if (enableMultiSelect) {
                      handleSelect();
                    } else {
                      this.enableMultiSelect.value = true;
                    }
                  },
                  icon: const Icon(Icons.edit_note),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          fab: playable && !enableMultiSelect ? _buildPlayFab() : null,
          body: CustomScrollView(
            slivers: [
              ViewSliverSafeArea(
                sliver: Obx(() {
                  if (_resolved.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text('文件夹里还没有视频'),
                        ),
                      ),
                    );
                  }
                  return SliverGrid.builder(
                    gridDelegate: gridDelegate,
                    itemCount: _resolved.length,
                    itemBuilder: (context, index) =>
                        _buildItem(_resolved[index], enableMultiSelect),
                  );
                }),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.viewPaddingOf(context).bottom + 100,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

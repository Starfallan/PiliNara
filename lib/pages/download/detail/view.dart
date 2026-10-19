import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/models_new/download/download_playback.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show BaseMultiSelectMixin;
import 'package:PiliPlus/pages/download/detail/widgets/item.dart';
import 'package:PiliPlus/pages/download/download_action_mixin.dart';
import 'package:PiliPlus/pages/download/utils/cache_delete_confirm.dart';
import 'package:PiliPlus/pages/download/utils/cache_export.dart';
import 'package:PiliPlus/pages/download/utils/card_menu.dart';
import 'package:PiliPlus/pages/download/widgets/folder_dialog.dart';
import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:PiliPlus/services/download/download_library_service.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

/// 视频页内的条目列表：视频/分P 页 → 条目（分P 或番剧分集）。
class DownloadDetailPage extends StatefulWidget {
  const DownloadDetailPage({
    super.key,
    required this.seasonKey,
    required this.pageId,
    required this.title,
    required this.progress,
  });

  final String seasonKey;
  final String pageId;
  final String title;
  final ChangeNotifier progress;

  @override
  State<DownloadDetailPage> createState() => _DownloadDetailPageState();
}

class _DownloadDetailPageState extends State<DownloadDetailPage>
    with
        BaseMultiSelectMixin<BiliDownloadEntryInfo>,
        GridMixin,
        BaseDownloadActionMixin<DownloadDetailPage, BiliDownloadEntryInfo>,
        CommonDownloadActionMixin<DownloadDetailPage> {
  final _downloadItems = RxList<BiliDownloadEntryInfo>();
  final _libraryService = Get.find<DownloadLibraryService>();

  @override
  RxList<BiliDownloadEntryInfo> get list => _downloadItems;
  @override
  RxList<BiliDownloadEntryInfo> get state => _downloadItems;

  @override
  final downloadService = Get.find<DownloadService>();

  @override
  BaseMultiSelectMixin<BiliDownloadEntryInfo> get multiSelectCtr => this;

  @override
  void initState() {
    super.initState();
    _loadList();
    _libraryService.flagNotifier.add(_loadList);
  }

  @override
  void dispose() {
    _libraryService.flagNotifier.remove(_loadList);
    super.dispose();
  }

  Future<void> _loadList() async {
    await _libraryService.waitForInitialization;
    if (!mounted) {
      return;
    }
    final hadItems = _downloadItems.isNotEmpty;
    final page = _libraryService
        .seasonByKey(widget.seasonKey)
        ?.pages
        .firstWhereOrNull((e) => e.pageId == widget.pageId);
    final entries = page?.entries;
    if (entries == null || entries.isEmpty) {
      _downloadItems.clear();
      // 这一页的缓存被删光时退出，避免停在空列表上。
      if (hadItems && mounted) {
        Get.back();
      }
      return;
    }
    _downloadItems.value = entries.toList()..sort(downloadEntrySort);
  }

  Future<void> _exportSelected() async {
    final entries = allChecked.toList();
    handleSelect();
    await exportDownloadEntries(entries);
  }

  /// 在视频页内部勾选得到的是独立条目，哪怕整页都选上了。
  Future<void> _addSelectedToFolder() async {
    final items = DownloadFolderItem.ofEntries(allChecked);
    if (items.isEmpty) {
      return;
    }
    final folderIds = await showDownloadFolderPickerDialog(context: context);
    if (folderIds == null || folderIds.isEmpty) {
      return;
    }
    final added = await Get.find<DownloadFolderService>().addItemsToFolders(
      items,
      folderIds,
    );
    handleSelect();
    SmartDialog.showToast(added == 0 ? '已经在文件夹里了' : '已添加到文件夹');
  }

  @override
  void onRemove() {
    confirmDeleteEntries(
      context: Get.context!,
      downloadService: downloadService,
      entries: allChecked,
    ).then((deleted) {
      if (deleted) {
        rxCount.value = 0;
        enableMultiSelect.value = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enableMultiSelect = this.enableMultiSelect.value;
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
              title: Text(widget.title),
              actions: [
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
          body: CustomScrollView(
            slivers: [
              ViewSliverSafeArea(
                sliver: Obx(() {
                  if (_downloadItems.isNotEmpty) {
                    return SliverGrid.builder(
                      gridDelegate: gridDelegate,
                      itemBuilder: (context, index) {
                        final entry = _downloadItems[index];
                        return DetailItem(
                          entry: entry,
                          progress: widget.progress,
                          downloadService: downloadService,
                          showTitle: false,
                          controller: this,
                          playContext: DownloadVideoPlayContext.season(
                            widget.seasonKey,
                          ),
                          onDelete: () => deleteLocalEntries(
                            downloadService: downloadService,
                            entries: [entry],
                          ),
                          extraMoreItemsBuilder: (menuContext) =>
                              buildAddEntriesToFolderMenuItems(
                                context: menuContext,
                                entries: [entry],
                              ),
                        );
                      },
                      itemCount: _downloadItems.length,
                    );
                  }
                  return const HttpError();
                }),
              ),
            ],
          ),
        ),
      );
    });
  }
}

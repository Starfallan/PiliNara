import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/models_new/download/download_playback.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/download/detail/widgets/item.dart';
import 'package:PiliPlus/pages/download/download/widgets/page.dart';
import 'package:PiliPlus/pages/download/download_action_mixin.dart';
import 'package:PiliPlus/pages/download/utils/cache_delete_confirm.dart';
import 'package:PiliPlus/pages/download/utils/cache_export.dart';
import 'package:PiliPlus/pages/download/utils/card_menu.dart';
import 'package:PiliPlus/pages/download/widgets/folder_dialog.dart';
import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:PiliPlus/services/download/download_library_service.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

/// 合集内的视频列表：合集 → 视频/分P 页 →（点进去才是）条目。
class DownloadPagePage extends StatefulWidget {
  const DownloadPagePage({
    super.key,
    required this.seasonKey,
    required this.progress,
  });

  /// 所属合集的 [DownloadSeasonInfo.playlistKey]。
  final String seasonKey;
  final ChangeNotifier progress;

  @override
  State<DownloadPagePage> createState() => _DownloadPagePageState();
}

class _DownloadPagePageState extends State<DownloadPagePage>
    with
        BaseMultiSelectMixin<DownloadPageInfo>,
        GridMixin,
        BaseDownloadActionMixin<DownloadPagePage, DownloadPageInfo> {
  final _pages = RxList<DownloadPageInfo>();
  final _libraryService = Get.find<DownloadLibraryService>();

  @override
  RxList<DownloadPageInfo> get list => _pages;
  @override
  RxList<DownloadPageInfo> get state => _pages;

  @override
  final downloadService = Get.find<DownloadService>();

  @override
  BaseMultiSelectMixin<DownloadPageInfo> get multiSelectCtr => this;

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

  static int _sort(DownloadPageInfo a, DownloadPageInfo b) {
    if (a.sortKey == b.sortKey) {
      return b.entries.first.avid.compareTo(a.entries.first.avid);
    }
    return a.sortKey.compareTo(b.sortKey);
  }

  Future<void> _loadList() async {
    await _libraryService.waitForInitialization;
    if (!mounted) {
      return;
    }
    final hadPages = _pages.isNotEmpty;
    final pages = _libraryService.seasonByKey(widget.seasonKey)?.pages;
    if (pages == null || pages.isEmpty) {
      _pages.clear();
      // 合集被整块删掉时退出这一层，避免停在空列表上。
      if (hadPages && mounted) {
        Get.back();
      }
      return;
    }
    _pages.value = pages.toList()..sort(_sort);
  }

  @override
  Future<void> onUpdate(
    Future<bool> Function(BiliDownloadEntryInfo e) toElement,
  ) async {
    if (checkUpdateCount(checkedCount)) return;

    bool dismiss = false;
    SmartDialog.showLoading(
      onDismiss: () {
        dismiss = true;
        handleSelect();
      },
    );

    bool isSuccess = true;
    for (final chunk in allChecked.mapChunked(
      kUpdateConcurrency,
      (page) async {
        bool isSuccess = true;
        for (final chunk in page.entries.mapChunked(
          kUpdateConcurrency,
          toElement,
        )) {
          final res = await Future.wait(chunk);
          if (res.any((e) => !e)) isSuccess = false;
          if (dismiss) break;
        }
        return isSuccess;
      },
    )) {
      final res = await Future.wait(chunk);
      if (res.any((e) => !e)) isSuccess = false;
      if (dismiss) break;
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  Future<void> _exportSelected() async {
    final entries = [
      for (final page in allChecked) ...page.entries,
    ];
    handleSelect();
    await exportDownloadEntries(entries);
  }

  /// 把勾选的视频页加进文件夹：一个视频页就是一个条目。只勾了其中几集的情况
  /// 不在这里——那是在条目列表里选的，粒度是单条。
  Future<void> _addSelectedToFolder() async {
    final items = allChecked.map((page) => page.toFolderItem()).toList();
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
    confirmDeletePages(
      context: Get.context!,
      downloadService: downloadService,
      pages: allChecked,
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
      final title = _libraryService
          .seasonByKey(widget.seasonKey)
          ?.seasonInfo
          ?.title;
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
              title: Text(title ?? '合集'),
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
                  if (_pages.isEmpty) {
                    return const HttpError();
                  }
                  return SliverGrid.builder(
                    gridDelegate: gridDelegate,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      if (page.entries.length == 1) {
                        final entry = page.entries.first;
                        return DetailItem(
                          entry: entry,
                          progress: widget.progress,
                          downloadService: downloadService,
                          showTitle: true,
                          controller: this,
                          checked: page.checked,
                          onSelect: (_) => onSelect(page),
                          playContext: DownloadVideoPlayContext.season(
                            widget.seasonKey,
                          ),
                          extraMoreItemsBuilder: (menuContext) =>
                              buildAddEntriesToFolderMenuItems(
                                context: menuContext,
                                entries: [entry],
                              ),
                        );
                      }
                      return PageInfoItem(
                        controller: this,
                        downloadService: downloadService,
                        selectable: page,
                        pageInfo: page,
                        seasonKey: widget.seasonKey,
                        enableMultiSelect: enableMultiSelect,
                        progress: widget.progress,
                        updatePageDm: updatePageDm,
                      );
                    },
                    itemCount: _pages.length,
                  );
                }),
              ),
            ],
          ),
        ),
      );
    });
  }
}

import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/flutter/popup_menu.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/models_new/download/download_playback.dart';
import 'package:PiliPlus/pages/common/fab_mixin.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/download/detail/widgets/item.dart';
import 'package:PiliPlus/pages/download/download/controller.dart';
import 'package:PiliPlus/pages/download/download/widgets/page.dart';
import 'package:PiliPlus/pages/download/download/widgets/season.dart';
import 'package:PiliPlus/pages/download/download_action_mixin.dart';
import 'package:PiliPlus/pages/download/folder/view.dart';
import 'package:PiliPlus/pages/download/folder_manage/view.dart';
import 'package:PiliPlus/pages/download/search/view.dart';
import 'package:PiliPlus/pages/download/utils/cache_delete_confirm.dart';
import 'package:PiliPlus/pages/download/utils/cache_export.dart';
import 'package:PiliPlus/pages/download/utils/card_menu.dart';
import 'package:PiliPlus/pages/download/utils/open_download_entry.dart';
import 'package:PiliPlus/pages/download/widgets/folder_card.dart';
import 'package:PiliPlus/pages/download/widgets/folder_dialog.dart';
import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with
        TickerProviderStateMixin,
        GridMixin,
        BaseFabMixin<DownloadPage>,
        FabMixin<DownloadPage>,
        BaseDownloadActionMixin<DownloadPage, DownloadSeasonInfo> {
  final _progress = ChangeNotifier();
  final _folderService = Get.find<DownloadFolderService>();
  final _controller = Get.put(DownloadController());

  bool _isOpeningContinue = false;

  @override
  final downloadService = Get.find<DownloadService>();

  @override
  BaseMultiSelectMixin<DownloadSeasonInfo> get multiSelectCtr => _controller;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Future<void> onUpdate(
    Future<bool> Function(BiliDownloadEntryInfo e) toElement,
  ) async {
    if (checkUpdateCount(_controller.checkedCount)) return;

    bool dismiss = false;
    SmartDialog.showLoading(
      onDismiss: () {
        dismiss = true;
        _controller.handleSelect();
      },
    );

    bool isSuccess = true;
    for (final chunk in _controller.allChecked.mapChunked(
      kUpdateConcurrency,
      (season) async {
        bool isSuccess = true;
        for (final chunk in season.pages.mapChunked(
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
        return isSuccess;
      },
    )) {
      final res = await Future.wait(chunk);
      if (res.any((e) => !e)) isSuccess = false;
      if (dismiss) break;
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  Future<void> _createFolder() async {
    final title = await showDownloadFolderNameDialog(
      context: context,
      title: '新建文件夹',
      initialValue: _folderService.buildDefaultFolderTitle(),
    );
    if (title == null) {
      return;
    }
    await _folderService.createFolder(title);
  }

  Future<void> _renameFolder(DownloadFolder folder) async {
    final title = await showDownloadFolderNameDialog(
      context: context,
      title: '重命名文件夹',
      initialValue: folder.title,
    );
    if (title == null || title == folder.title) {
      return;
    }
    await _folderService.renameFolder(folder.id, title);
  }

  Future<void> _openFolderManagePage() async {
    await Get.to(const DownloadFolderManagePage());
  }

  Future<void> _addSelectedToFolders() async {
    final folderIds = await showDownloadFolderPickerDialog(context: context);
    if (folderIds == null || folderIds.isEmpty) {
      return;
    }
    final added = await _folderService.addItemsToFolders(
      _controller.allChecked.map((season) => season.toFolderItem()),
      folderIds,
    );
    _controller.handleSelect();
    SmartDialog.showToast(added == 0 ? '已经在文件夹里了' : '已添加到文件夹');
  }

  /// 文件夹卡片的菜单：重命名 / 导出整组 / 删除。
  ///
  /// 删除只断开关联，缓存文件与自动分组都不受影响。
  Widget _buildFolderMenu(DownloadFolder folder) {
    return Builder(
      builder: (context) => IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert_outlined,
          color: Theme.of(context).colorScheme.outline,
          size: 18,
        ),
        onPressed: () async {
          final value = await showStaticPositionMenu<int>(
            context: context,
            items: [
              const CustomPopupMenuItem(value: 0, child: Text('重命名')),
              if (Platform.isAndroid)
                const CustomPopupMenuItem(value: 1, child: Text('导出')),
              CustomPopupMenuItem(
                value: 2,
                child: Text(
                  '删除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          );
          switch (value) {
            case 0:
              await _renameFolder(folder);
            case 1:
              await exportDownloadEntries(
                _folderService.resolveFolderEntries(folder.id),
              );
            case 2:
              // 弹确认框要用 context，这里必须先确认它还有效
              if (!context.mounted) {
                return;
              }
              await confirmDeleteFolders(context: context, folders: [folder]);
          }
        },
      ),
    );
  }

  /// 文件夹区：与自动分组同处一个列表，不另开页签。
  Widget _buildFolderSection() {
    return Obx(() {
      final folders = _controller.folders;
      if (folders.isEmpty) {
        return const SliverToBoxAdapter();
      }
      return SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(left: 12, bottom: 7, top: 7),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Text('文件夹'),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _openFolderManagePage,
                    child: const Text('管理'),
                  ),
                ],
              ),
            ),
          ),
          SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              final entries = _folderService.resolveFolderEntries(folder.id);
              return DownloadFolderCard(
                title: folder.title,
                count: entries.length,
                entry: entries.firstOrNull,
                onTap: () async {
                  await Get.to(DownloadFolderPage(folderId: folder.id));
                  if (mounted) {
                    await _controller.libraryService.refreshContinueTarget();
                  }
                },
                trailing: _buildFolderMenu(folder),
              );
            },
          ),
        ],
      );
    });
  }

  Future<void> _exportChecked() async {
    final entries = [
      for (final season in _controller.allChecked)
        ..._controller.libraryService.entriesOfSeason(season),
    ];
    _controller.handleSelect();
    if (entries.isEmpty) {
      SmartDialog.showToast('选中的合集里没有可导出的缓存');
      return;
    }
    await exportDownloadEntries(entries);
  }

  Future<void> _openContinueTarget(DownloadContinueTarget target) async {
    if (_isOpeningContinue) {
      return;
    }
    setState(() {
      _isOpeningContinue = true;
    });
    try {
      await openDownloadEntry(
        entry: target.entry,
        playContext: target.playContext,
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) {
        return;
      }
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      _progress.notifyListeners();
      await _controller.libraryService.refreshContinueTarget();
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningContinue = false;
        });
      }
    }
  }

  Widget _buildContinueFab() {
    return Obx(() {
      final target = _controller.libraryService.continueTarget.value;
      final shouldShow = target != null && !_controller.enableMultiSelect.value;
      if (!shouldShow) {
        return const SizedBox.shrink();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showFab();
        }
      });
      final padding = MediaQuery.viewPaddingOf(context);
      return Positioned(
        right: padding.right + kFloatingActionButtonMargin,
        bottom: 0,
        child: SlideTransition(
          position: fabAnimation,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: padding.bottom + kFloatingActionButtonMargin,
            ),
            child: FloatingActionButton.extended(
              onPressed: _isOpeningContinue
                  ? null
                  : () => _openContinueTarget(target),
              label: const Text('继续播放'),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Obx(() {
      final enableMultiSelect = _controller.enableMultiSelect.value;
      return popScope(
        canPop: !enableMultiSelect,
        onPopInvokedWithResult: (didPop, result) {
          if (enableMultiSelect) {
            _controller.handleSelect();
          }
        },
        child: SimpleScaffold(
          appBar: MultiSelectAppBarWidget(
            ctr: _controller,
            visible: enableMultiSelect,
            actions: [
              // 更新弹幕 / 更新片段来自 mixin，作用于选中的整个合集
              updateBtn(),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: _controller.checkedCount == 0
                    ? null
                    : _addSelectedToFolders,
                child: const Text('添加到'),
              ),
              if (Platform.isAndroid)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _controller.checkedCount == 0
                      ? null
                      : _exportChecked,
                  child: const Text('导出'),
                ),
            ],
            child: AppBar(
              title: const Text('离线缓存'),
              actions: [
                IconButton(
                  tooltip: '搜索',
                  onPressed: () async {
                    await downloadService.waitForInitialization;
                    if (!mounted) return;
                    await Get.to(DownloadSearchPage(progress: _progress));
                    if (mounted) {
                      await _controller.libraryService.refreshContinueTarget();
                    }
                  },
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: '新建文件夹',
                  onPressed: _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
                IconButton(
                  tooltip: '多选',
                  onPressed: () {
                    if (enableMultiSelect) {
                      _controller.handleSelect();
                    } else {
                      _controller.enableMultiSelect.value = true;
                    }
                  },
                  icon: const Icon(Icons.edit_note),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              fabAnimWrapper(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: padding.left,
                    right: padding.right,
                  ),
                  child: CustomScrollView(
                    slivers: [
                      Obx(() {
                        final entry =
                            downloadService.waitDownloadQueue.firstWhereOrNull(
                              (e) => e.cid == downloadService.curCid,
                            ) ??
                            downloadService.waitDownloadQueue.firstOrNull;
                        if (entry == null) {
                          return const SliverToBoxAdapter();
                        }
                        return SliverMainAxisGroup(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                bottom: 7,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  '正在缓存 (${downloadService.waitDownloadQueue.length})',
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 110,
                                child: DetailItem(
                                  entry: entry,
                                  progress: _progress,
                                  downloadService: downloadService,
                                  showTitle: true,
                                  isCurr: true,
                                  controller: _controller,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      _buildFolderSection(),
                      Obx(() {
                        if (_controller.seasons.isEmpty) {
                          if (downloadService.waitDownloadQueue.isNotEmpty) {
                            return const SliverToBoxAdapter();
                          }
                          return const HttpError();
                        }
                        return SliverMainAxisGroup(
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.only(
                                left: 12,
                                bottom: 7,
                                top: downloadService.waitDownloadQueue.isEmpty
                                    ? 0
                                    : 7,
                              ),
                              sliver: const SliverToBoxAdapter(
                                child: Text('已缓存视频'),
                              ),
                            ),
                            SliverGrid.builder(
                              gridDelegate: gridDelegate,
                              itemBuilder: (context, index) {
                                final season = _controller.seasons[index];
                                final seasonInfo = season.seasonInfo;
                                final pages = season.pages;

                                // 多视频合集单独成卡，点进去才是合集内的视频列表
                                if (seasonInfo != null && pages.length > 1) {
                                  return SeasonInfoItem(
                                    controller: _controller,
                                    downloadService: downloadService,
                                    season: season,
                                    seasonInfo: seasonInfo,
                                    selectable: season,
                                    enableMultiSelect: enableMultiSelect,
                                    progress: _progress,
                                    updateSeasonDm: updateSeasonDm,
                                  );
                                }

                                final page = pages.first;
                                if (page.entries.length == 1) {
                                  final entry = page.entries.first;
                                  return DetailItem(
                                    entry: entry,
                                    progress: _progress,
                                    downloadService: downloadService,
                                    showTitle: true,
                                    onDelete: () => deleteLocalEntries(
                                      downloadService: downloadService,
                                      entries: [entry],
                                    ),
                                    controller: _controller,
                                    checked: season.checked,
                                    onSelect: (_) =>
                                        _controller.onSelect(season),
                                    playContext:
                                        const DownloadVideoPlayContext.all(),
                                    extraMoreItemsBuilder: (menuContext) =>
                                        buildAddEntriesToFolderMenuItems(
                                          context: menuContext,
                                          entries: [entry],
                                        ),
                                    onPlayReturned: _controller
                                        .libraryService
                                        .refreshContinueTarget,
                                    customOnLongPress: () => _controller
                                      ..enableMultiSelect.value = true
                                      ..onSelect(season),
                                  );
                                }

                                return PageInfoItem(
                                  controller: _controller,
                                  downloadService: downloadService,
                                  selectable: season,
                                  pageInfo: page,
                                  seasonKey: season.playlistKey,
                                  enableMultiSelect: enableMultiSelect,
                                  progress: _progress,
                                  updatePageDm: updatePageDm,
                                );
                              },
                              itemCount: _controller.seasons.length,
                            ),
                          ],
                        );
                      }),
                      SliverToBoxAdapter(
                        child: SizedBox(height: padding.bottom + 100),
                      ),
                    ],
                  ),
                ),
              ),
              _buildContinueFab(),
            ],
          ),
        ),
      );
    });
  }
}

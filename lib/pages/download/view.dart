import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_collection.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/download/controller.dart';
import 'package:PiliPlus/pages/download/detail/widgets/item.dart';
import 'package:PiliPlus/pages/download/folder/view.dart';
import 'package:PiliPlus/pages/download/folder_manage/view.dart';
import 'package:PiliPlus/pages/download/search/view.dart';
import 'package:PiliPlus/pages/download/sort/view.dart';
import 'package:PiliPlus/pages/download/widgets/folder_card.dart';
import 'package:PiliPlus/pages/download/widgets/folder_dialog.dart';
import 'package:PiliPlus/services/download/download_collection_service.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart' show IterableExt;
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

enum _DownloadTab {
  videos('全部视频'),
  folders('文件夹');

  final String label;
  const _DownloadTab(this.label);
}

enum _DownloadSortAction {
  manual,
  reset,
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with SingleTickerProviderStateMixin {
  final _downloadService = Get.find<DownloadService>();
  final _collectionService = Get.find<DownloadCollectionService>();
  final _controller = Get.put(DownloadPageController());
  late final _folderSelectController = Get.put(
    DownloadFolderSelectController(_controller),
  );
  final _progress = ChangeNotifier();

  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _DownloadTab.values.length, vsync: this)
      ..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    if (_tabIndex != _tabController.index && mounted) {
      setState(() {
        _tabIndex = _tabController.index;
      });
    }
    if (_tabController.index != 0 && _controller.enableMultiSelect.value) {
      _controller.handleSelect();
    }
    if (_tabController.index != 1 &&
        _folderSelectController.enableMultiSelect.value) {
      _folderSelectController.handleSelect();
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _createFolder() async {
    final title = await showDownloadFolderNameDialog(
      context: context,
      title: '新建文件夹',
      initialValue: _collectionService.buildDefaultFolderTitle(),
    );
    if (title == null) {
      return;
    }
    await _collectionService.createFolder(title);
    SmartDialog.showToast('创建成功');
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
    await _collectionService.renameFolder(folder.id, title);
    SmartDialog.showToast('重命名成功');
  }

  Future<void> _deleteFolder(DownloadFolder folder) async {
    showConfirmDialog(
      context: context,
      title: const Text('确定删除该文件夹？'),
      content: const Text('只会删除文件夹关联，不会删除本地缓存文件。'),
      onConfirm: () async {
        await _collectionService.deleteFolder(folder.id);
      },
    );
  }

  Future<void> _addSelectedToFolders() async {
    final folderIds = await showDownloadFolderPickerDialog(
      context: context,
      collectionService: _collectionService,
      title: '添加到文件夹',
    );
    if (folderIds == null || folderIds.isEmpty) {
      return;
    }
    await _collectionService.addVideosToFolders(
      _controller.allChecked.map((item) => item.cid),
      folderIds,
    );
    _controller.handleSelect();
    SmartDialog.showToast('已添加到文件夹');
  }

  Future<void> _openAllSortPage() async {
    if (_controller.allVideos.isEmpty) {
      return;
    }
    await Get.to(
      DownloadVideoSortPage(
        title: '排序: 全部视频',
        entries: _controller.allVideos,
        onSave: _collectionService.saveAllVideoOrder,
      ),
    );
  }

  Future<void> _resetAllSort() async {
    await _collectionService.resetAllVideoOrder();
    SmartDialog.showToast('已按缓存时间显示');
  }

  void _onAllSortSelected(_DownloadSortAction action) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      if (action == _DownloadSortAction.manual) {
        await _openAllSortPage();
      } else {
        await _resetAllSort();
      }
    });
  }

  Future<void> _openFolderManagePage() async {
    await Get.to(
      DownloadFolderManagePage(collectionService: _collectionService),
    );
  }

  List<PopupMenuEntry<void>> _buildFolderQuickMenuItems(
    BuildContext context,
    BiliDownloadEntryInfo entry,
  ) {
    final folders = _controller.folders;
    if (folders.isEmpty) {
      return [
        PopupMenuItem(
          height: 38,
          child: const Text('添加到文件夹', style: TextStyle(fontSize: 13)),
          onTap: () async {
            final selectedIds = await showDownloadFolderPickerDialog(
              context: context,
              collectionService: _collectionService,
              title: '添加到文件夹',
            );
            if (selectedIds == null || selectedIds.isEmpty) {
              return;
            }
            await _collectionService.addVideosToFolders(
              [entry.cid],
              selectedIds,
            );
            SmartDialog.showToast('已添加到文件夹');
          },
        ),
      ];
    }
    return [
      const PopupMenuDivider(height: 8),
      ...folders.map(
        (folder) => PopupMenuItem(
          height: 38,
          child: Text(
            '添加到「${folder.title}」',
            style: const TextStyle(fontSize: 13),
          ),
          onTap: () async {
            await _collectionService.addVideosToFolders(
              [entry.cid],
              [folder.id],
            );
            SmartDialog.showToast('已添加到「${folder.title}」');
          },
        ),
      ),
      PopupMenuItem(
        height: 38,
        child: const Text('添加到其他文件夹', style: TextStyle(fontSize: 13)),
        onTap: () async {
          final selectedIds = await showDownloadFolderPickerDialog(
            context: context,
            collectionService: _collectionService,
            title: '添加到文件夹',
          );
          if (selectedIds == null || selectedIds.isEmpty) {
            return;
          }
          await _collectionService.addVideosToFolders(
            [entry.cid],
            selectedIds,
          );
          SmartDialog.showToast('已添加到文件夹');
        },
      ),
    ];
  }

  Widget _buildFolderMoreBtn(DownloadFolder folder) {
    return PopupMenuButton<void>(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_vert_outlined,
        color: Theme.of(context).colorScheme.outline,
        size: 18,
      ),
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          height: 38,
          child: const Text('重命名', style: TextStyle(fontSize: 13)),
          onTap: () => _renameFolder(folder),
        ),
        PopupMenuItem(
          height: 38,
          child: Text(
            '删除',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(menuContext).colorScheme.error,
            ),
          ),
          onTap: () => _deleteFolder(folder),
        ),
      ],
    );
  }

  Widget _buildAllSortBtn() {
    return Builder(
      builder: (context) => PopupMenuButton<_DownloadSortAction>(
        tooltip: '排序',
        onSelected: _onAllSortSelected,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _DownloadSortAction.manual,
            child: Text('手动排序'),
          ),
          PopupMenuItem(
            value: _DownloadSortAction.reset,
            child: Text('按缓存时间'),
          ),
        ],
        icon: const Icon(Icons.sort),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentTab = _DownloadTab.values[_tabIndex];
      final isVideoTab = currentTab == _DownloadTab.videos;
      final MultiSelectBase activeMultiSelectCtr = isVideoTab
          ? _controller
          : _folderSelectController;
      final enableMultiSelect = isVideoTab
          ? _controller.enableMultiSelect.value
          : _folderSelectController.enableMultiSelect.value;
      return popScope(
        canPop: !enableMultiSelect,
        onPopInvokedWithResult: (didPop, result) {
          if (enableMultiSelect) {
            activeMultiSelectCtr.handleSelect();
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: MultiSelectAppBarWidget(
            ctr: activeMultiSelectCtr,
            visible: enableMultiSelect,
            actions: isVideoTab
                ? [
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        final allChecked = _controller.allChecked.toSet();
                        _controller.handleSelect();
                        final res = await Future.wait(
                          allChecked.map(
                            (entry) => _downloadService.downloadDanmaku(
                              entry: entry,
                              isUpdate: true,
                            ),
                          ),
                        );
                        SmartDialog.showToast(
                          res.every((item) => item) ? '更新成功' : '更新失败',
                        );
                      },
                      child: Text(
                        '更新',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _controller.checkedCount == 0
                          ? null
                          : _addSelectedToFolders,
                      child: const Text('添加到'),
                    ),
                  ]
                : null,
            child: AppBar(
              title: const Text('离线缓存'),
              actions: [
                if (isVideoTab) ...[
                  IconButton(
                    tooltip: '搜索',
                    onPressed: () async {
                      await _downloadService.waitForInitialization;
                      if (!mounted) {
                        return;
                      }
                      Get.to(DownloadSearchPage(progress: _progress));
                    },
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: '多选',
                    onPressed: () {
                      if (_controller.enableMultiSelect.value) {
                        _controller.handleSelect();
                      } else {
                        _controller.enableMultiSelect.value = true;
                      }
                    },
                    icon: const Icon(Icons.edit_note),
                  ),
                  _buildAllSortBtn(),
                ] else ...[
                  IconButton(
                    tooltip: '新建文件夹',
                    onPressed: _createFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                  IconButton(
                    tooltip: '多选',
                    onPressed: () {
                      if (_folderSelectController.enableMultiSelect.value) {
                        _folderSelectController.handleSelect();
                      } else {
                        _folderSelectController.enableMultiSelect.value = true;
                      }
                    },
                    icon: const Icon(Icons.edit_note),
                  ),
                  IconButton(
                    tooltip: '排序',
                    onPressed: _openFolderManagePage,
                    icon: const Icon(Icons.sort),
                  ),
                ],
                const SizedBox(width: 6),
              ],
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Obx(
                      () => Text('全部视频(${_controller.allVideos.length})'),
                    ),
                  ),
                  Tab(
                    child: Obx(
                      () => Text('文件夹(${_controller.folders.length})'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildAllVideosTab(),
              _buildFoldersTab(),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAllVideosTab() {
    final padding = MediaQuery.viewPaddingOf(context);
    return Padding(
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      child: CustomScrollView(
        slivers: [
          Obx(() {
            final entry =
                _downloadService.waitDownloadQueue.firstWhereOrNull(
                  (item) => item.cid == _downloadService.curCid,
                ) ??
                _downloadService.waitDownloadQueue.firstOrNull;
            if (entry == null) {
              return const SliverToBoxAdapter();
            }
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 7),
                      child: Text(
                        '正在缓存 (${_downloadService.waitDownloadQueue.length})',
                      ),
                    ),
                    SizedBox(
                      height: 100,
                      child: DetailItem(
                        entry: entry,
                        progress: _progress,
                        downloadService: _downloadService,
                        showTitle: true,
                        isCurr: true,
                        controller: _controller,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Obx(() {
            if (_controller.allVideos.isEmpty) {
              if (_downloadService.waitDownloadQueue.isNotEmpty) {
                return const SliverToBoxAdapter();
              }
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: HttpError(),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.only(
                top: _downloadService.waitDownloadQueue.isNotEmpty ? 0 : 7,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  mainAxisSpacing: 2,
                  mainAxisExtent: 100,
                  maxCrossAxisExtent: Grid.smallCardWidth * 2,
                ),
                itemCount: _controller.allVideos.length,
                itemBuilder: (context, index) {
                  final entry = _controller.allVideos[index];
                  return DetailItem(
                    entry: entry,
                    progress: _progress,
                    downloadService: _downloadService,
                    showTitle: true,
                    onDelete: () async {
                      await _downloadService.deleteDownload(
                        entry: entry,
                        removeList: true,
                      );
                      GStorage.watchProgress.delete(entry.cid.toString());
                    },
                    controller: _controller,
                    playContext: const DownloadVideoPlayContext.all(),
                    customOnLongPress: () => _controller
                      ..enableMultiSelect.value = true
                      ..onSelect(entry),
                    extraMoreItemsBuilder: (menuContext) =>
                        _buildFolderQuickMenuItems(menuContext, entry),
                  );
                },
              ),
            );
          }),
          SliverToBoxAdapter(
            child: SizedBox(height: padding.bottom + 100),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldersTab() {
    final padding = MediaQuery.viewPaddingOf(context);
    return Padding(
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      child: CustomScrollView(
        slivers: [
          Obx(() {
            if (_controller.folders.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('还没有文件夹'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _createFolder,
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('新建文件夹'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.only(top: 7, bottom: padding.bottom + 100),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  mainAxisSpacing: 2,
                  mainAxisExtent: 100,
                  maxCrossAxisExtent: Grid.smallCardWidth * 2,
                ),
                itemCount: _controller.folders.length,
                itemBuilder: (context, index) {
                  final folder = _controller.folders[index];
                  final entries = _controller.resolveFolderEntries(folder.id);
                  return DownloadFolderCard(
                    title: folder.title,
                    count: entries.length,
                    entry: entries.firstOrNull,
                    checked: folder.checked,
                    onTap: _folderSelectController.enableMultiSelect.value
                        ? () => _folderSelectController.onSelect(folder)
                        : () => Get.to(
                            DownloadFolderPage(folderId: folder.id),
                          ),
                    onLongPress: () => _folderSelectController
                      ..enableMultiSelect.value = true
                      ..onSelect(folder),
                    trailing: _folderSelectController.enableMultiSelect.value
                        ? null
                        : _buildFolderMoreBtn(folder),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

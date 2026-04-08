import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/models_new/download/download_collection.dart';
import 'package:PiliPlus/pages/download/detail/widgets/item.dart';
import 'package:PiliPlus/pages/download/folder/controller.dart';
import 'package:PiliPlus/pages/download/sort/view.dart';
import 'package:PiliPlus/pages/download/widgets/folder_dialog.dart';
import 'package:PiliPlus/services/download/download_collection_service.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/material.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

enum _FolderSortAction {
  manual,
  reset,
}

class DownloadFolderPage extends StatefulWidget {
  const DownloadFolderPage({
    super.key,
    required this.folderId,
  });

  final String folderId;

  @override
  State<DownloadFolderPage> createState() => _DownloadFolderPageState();
}

class _DownloadFolderPageState extends State<DownloadFolderPage> {
  late final DownloadFolderDetailController _controller = Get.put(
    DownloadFolderDetailController(widget.folderId),
    tag: widget.folderId,
  );
  final _downloadService = Get.find<DownloadService>();
  final _collectionService = Get.find<DownloadCollectionService>();
  final _progress = ChangeNotifier();

  @override
  void dispose() {
    _progress.dispose();
    if (Get.isRegistered<DownloadFolderDetailController>(tag: widget.folderId)) {
      Get.delete<DownloadFolderDetailController>(tag: widget.folderId);
    }
    super.dispose();
  }

  Future<void> _addSelectedToFolder() async {
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
    SmartDialog.showToast('已更新文件夹');
  }

  Future<void> _openSortPage() async {
    if (_controller.entries.isEmpty) {
      return;
    }
    await Get.to(
      DownloadVideoSortPage(
        title: '排序: ${_controller.title.value}',
        entries: _controller.entries,
        onSave: (cids) =>
            _collectionService.reorderFolderVideos(widget.folderId, cids),
      ),
    );
  }

  Future<void> _resetOrder() async {
    final entries = List.of(_controller.entries)
      ..sort((a, b) => b.timeUpdateStamp.compareTo(a.timeUpdateStamp));
    await _collectionService.reorderFolderVideos(
      widget.folderId,
      entries.map((item) => item.cid).toList(),
    );
    SmartDialog.showToast('已按缓存时间重置');
  }

  void _onSortSelected(_FolderSortAction action) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      if (action == _FolderSortAction.manual) {
        await _openSortPage();
      } else {
        await _resetOrder();
      }
    });
  }

  Future<void> _renameFolder() async {
    final currentTitle = _controller.title.value;
    final name = await showDownloadFolderNameDialog(
      context: context,
      title: '重命名文件夹',
      initialValue: currentTitle,
    );
    if (name == null || name == currentTitle) {
      return;
    }
    await _collectionService.renameFolder(widget.folderId, name);
  }

  Future<void> _deleteFolder() async {
    showConfirmDialog(
      context: context,
      title: const Text('确定删除该文件夹？'),
      content: const Text('只会删除文件夹关联，不会删除本地缓存文件。'),
      onConfirm: () async {
        await _collectionService.deleteFolder(widget.folderId);
        if (mounted) {
          Get.back();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enableMultiSelect = _controller.enableMultiSelect.value;
      return popScope(
        canPop: !enableMultiSelect,
        onPopInvokedWithResult: (didPop, result) {
          if (enableMultiSelect) {
            _controller.handleSelect();
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: MultiSelectAppBarWidget(
            ctr: _controller,
            actions: [
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed:
                    _controller.checkedCount == 0 ? null : _addSelectedToFolder,
                child: const Text('添加到'),
              ),
            ],
            child: AppBar(
              title: Obx(() => Text(_controller.title.value)),
              actions: [
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
                PopupMenuButton<_FolderSortAction>(
                  tooltip: '排序',
                  onSelected: _onSortSelected,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _FolderSortAction.manual,
                      child: Text('手动排序'),
                    ),
                    PopupMenuItem(
                      value: _FolderSortAction.reset,
                      child: Text('按缓存时间'),
                    ),
                  ],
                  icon: const Icon(Icons.sort),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: _renameFolder,
                      child: const Text('重命名'),
                    ),
                    PopupMenuItem(
                      onTap: _deleteFolder,
                      child: Text(
                        '删除文件夹',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          body: CustomScrollView(
            slivers: [
              ViewSliverSafeArea(
                sliver: Obx(() {
                  if (_controller.entries.isEmpty) {
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
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      mainAxisSpacing: 2,
                      mainAxisExtent: 100,
                      maxCrossAxisExtent: Grid.smallCardWidth * 2,
                    ),
                    itemCount: _controller.entries.length,
                    itemBuilder: (context, index) {
                      final entry = _controller.entries[index];
                      return DetailItem(
                        entry: entry,
                        progress: _progress,
                        downloadService: _downloadService,
                        showTitle: true,
                        onDelete: () => _collectionService.removeVideosFromFolder(
                          widget.folderId,
                          [entry.cid],
                        ),
                        deleteLabel: '移出文件夹',
                        deleteConfirmText: '确定从当前文件夹移除？',
                        controller: _controller,
                        playContext: DownloadVideoPlayContext.folder(
                          widget.folderId,
                        ),
                      );
                    },
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

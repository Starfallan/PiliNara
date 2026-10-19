import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/pages/download/utils/cache_delete_confirm.dart';
import 'package:PiliPlus/pages/download/widgets/folder_card.dart';
import 'package:PiliPlus/pages/download/widgets/folder_dialog.dart';
import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 文件夹顺序管理：拖动决定文件夹在缓存页里的先后。
class DownloadFolderManagePage extends StatefulWidget {
  const DownloadFolderManagePage({super.key});

  @override
  State<DownloadFolderManagePage> createState() =>
      _DownloadFolderManagePageState();
}

class _DownloadFolderManagePageState extends State<DownloadFolderManagePage> {
  final _folderService = Get.find<DownloadFolderService>();
  late final List<DownloadFolder> _folders = List<DownloadFolder>.from(
    _folderService.folders,
  );

  List<BiliDownloadEntryInfo> _entriesOf(String folderId) =>
      _folderService.resolveFolderEntries(folderId);

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _folders.removeAt(oldIndex);
    _folders.insert(newIndex, item);
    setState(() {});
  }

  Future<void> _renameFolder(DownloadFolder folder) async {
    final name = await showDownloadFolderNameDialog(
      context: context,
      title: '重命名文件夹',
      initialValue: folder.title,
    );
    if (name == null || name == folder.title) {
      return;
    }
    await _folderService.renameFolder(folder.id, name);
    folder.title = name;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteFolder(DownloadFolder folder) async {
    final deleted = await confirmDeleteFolders(
      context: context,
      folders: [folder],
    );
    if (deleted) {
      _folders.removeWhere((item) => item.id == folder.id);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排序文件夹'),
        actions: [
          TextButton(
            onPressed: () async {
              await _folderService.reorderFolders(
                _folders.map((item) => item.id).toList(),
              );
              if (mounted) {
                SmartDialog.showToast('排序完成');
                Get.back();
              }
            },
            child: const Text('完成'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: _folders.length,
        onReorder: _onReorder,
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            MediaQuery.viewPaddingOf(context).copyWith(top: 0) +
            const EdgeInsets.only(bottom: 100),
        itemBuilder: (context, index) {
          final folder = _folders[index];
          final entries = _entriesOf(folder.id);
          return SizedBox(
            key: Key(folder.id),
            height: 100,
            child: DownloadFolderCard(
              title: folder.title,
              count: entries.length,
              entry: entries.firstOrNull,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '重命名',
                    onPressed: () => _renameFolder(folder),
                    icon: const Icon(Icons.drive_file_rename_outline),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () => _deleteFolder(folder),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

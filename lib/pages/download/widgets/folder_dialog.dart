import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 新建 / 重命名文件夹的名称输入。
Future<String?> showDownloadFolderNameDialog({
  required BuildContext context,
  required String title,
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 1,
        maxLength: 30,
        decoration: const InputDecoration(
          hintText: '请输入文件夹名称',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty) {
              return;
            }
            Navigator.of(dialogContext).pop(text);
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

/// 选择要把视频加进哪些文件夹，可在对话框里直接新建一个。
Future<List<String>?> showDownloadFolderPickerDialog({
  required BuildContext context,
  String title = '添加到文件夹',
}) async {
  final folderService = Get.find<DownloadFolderService>();
  await folderService.waitForInitialization;
  if (!context.mounted) {
    return null;
  }
  final selectedIds = <String>{};
  return showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            width: double.maxFinite,
            child: Obx(() {
              final folders = folderService.folders;
              if (folders.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('还没有文件夹，先新建一个吧。'),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: folders
                      .map(
                        (folder) => CheckboxListTile(
                          dense: true,
                          value: selectedIds.contains(folder.id),
                          title: Text(folder.title),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (value) {
                            if (value == true) {
                              selectedIds.add(folder.id);
                            } else {
                              selectedIds.remove(folder.id);
                            }
                            setState(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = await showDownloadFolderNameDialog(
                context: dialogContext,
                title: '新建文件夹',
                initialValue: folderService.buildDefaultFolderTitle(),
              );
              if (name == null) {
                return;
              }
              final folder = await folderService.createFolder(name);
              selectedIds.add(folder.id);
              setState(() {});
            },
            child: const Text('新建文件夹'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(selectedIds.toList()),
            child: const Text('完成'),
          ),
        ],
      ),
    ),
  );
}

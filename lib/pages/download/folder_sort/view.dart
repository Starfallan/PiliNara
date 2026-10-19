import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/pages/download/widgets/folder_card.dart';
import 'package:PiliPlus/services/download/download_folder_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 文件夹顶层顺序管理：拖动决定哪些卡片 / 视频排在前面。
///
/// 只排顶层——合集卡与视频页卡内部的顺序由它们自己的归属决定，读时不重排，
/// 免得静默覆盖用户的手动排序。
class DownloadFolderSortPage extends StatefulWidget {
  const DownloadFolderSortPage({
    super.key,
    required this.folderId,
    required this.title,
  });

  final String folderId;
  final String title;

  @override
  State<DownloadFolderSortPage> createState() =>
      _DownloadFolderSortPageState();
}

class _DownloadFolderSortPageState extends State<DownloadFolderSortPage> {
  final _folderService = Get.find<DownloadFolderService>();
  late final List<ResolvedFolderItem> _items = _folderService.resolveItems(
    widget.folderId,
  );

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    setState(() {});
  }

  String _titleOf(ResolvedFolderItem resolved) =>
      resolved.entry?.showTitle ??
      resolved.page?.title ??
      resolved.season?.seasonInfo?.title ??
      '';

  String _subtitleOf(ResolvedFolderItem resolved) => switch (resolved.item.kind) {
    DownloadFolderItemKind.season => '合集',
    DownloadFolderItemKind.page => '视频页',
    DownloadFolderItemKind.entry => '单个视频',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () async {
              await _folderService.reorderItems(
                widget.folderId,
                [for (final resolved in _items) resolved.item],
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
        itemCount: _items.length,
        onReorder: _onReorder,
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            MediaQuery.viewPaddingOf(context).copyWith(top: 0) +
            const EdgeInsets.only(bottom: 100),
        itemBuilder: (context, index) {
          final resolved = _items[index];
          return SizedBox(
            key: ValueKey(resolved.item.key),
            height: 100,
            child: DownloadFolderCard(
              title: _titleOf(resolved),
              count: resolved.entries.length,
              entry: resolved.entries.firstOrNull,
              subtitle: _subtitleOf(resolved),
            ),
          );
        },
      ),
    );
  }
}

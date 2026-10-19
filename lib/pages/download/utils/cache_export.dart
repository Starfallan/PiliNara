import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

const _exportDialogTag = 'download-export';

/// 导出单个条目，带进度弹窗。
Future<void> exportDownloadEntry(BiliDownloadEntryInfo entry) async {
  if (!await ImageUtils.checkPermissionDependOnSdkInt()) {
    return;
  }
  _showExportDialog(entry);
  try {
    final dest = await DownloadService.exportEntry(entry, (progress) {
      _ExportDialog.progressNotifier.value = progress;
    });
    SmartDialog.showToast('已导出到 $dest');
  } catch (e) {
    SmartDialog.showToast('导出失败: $e');
  } finally {
    SmartDialog.dismiss(tag: _exportDialogTag);
  }
}

/// 批量导出，逐条显示进度；单个失败继续后续任务。
Future<void> exportDownloadEntries(
  Iterable<BiliDownloadEntryInfo> entries,
) async {
  if (!await ImageUtils.checkPermissionDependOnSdkInt()) {
    return;
  }
  final items = entries.toList(growable: false);
  if (items.isEmpty) {
    return;
  }
  final total = items.length;
  for (var i = 0; i < total; i++) {
    final entry = items[i];
    _showExportDialog(entry, current: i + 1, total: total);
    try {
      await DownloadService.exportEntry(entry, (progress) {
        _ExportDialog.progressNotifier.value = progress;
      });
    } catch (_) {
      // 保持现有批量导出行为，单个失败时继续后续任务。
    } finally {
      SmartDialog.dismiss(tag: _exportDialogTag);
    }
  }
  SmartDialog.showToast('导出完成 ($total)');
}

void _showExportDialog(
  BiliDownloadEntryInfo entry, {
  int? current,
  int? total,
}) {
  _ExportDialog.progressNotifier.value = 0;
  SmartDialog.show(
    tag: _exportDialogTag,
    clickMaskDismiss: false,
    builder: (_) => _ExportDialog(
      title: entry.showTitle,
      current: current,
      total: total,
    ),
    maskColor: Colors.black.withValues(alpha: 0.35),
  );
}

class _ExportDialog extends StatelessWidget {
  static final progressNotifier = ValueNotifier<double>(0);

  const _ExportDialog({
    required this.title,
    this.current,
    this.total,
  });

  final String title;
  final int? current;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total == null ? '正在导出' : '正在导出 ($current/$total)',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, _) {
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        year2023: true,
                        value: progress,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        color: theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

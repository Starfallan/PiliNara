import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/select_mask.dart';
import 'package:PiliPlus/models_new/download/download_folder.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/download/detail/view.dart';
import 'package:PiliPlus/pages/download/utils/cache_delete_confirm.dart';
import 'package:PiliPlus/pages/download/utils/card_menu.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:material_ui/material_ui.dart';

/// 一个「视频页」的卡片：分P 视频、PGC 一季、或合集里的单个视频。
///
/// 多选对象由 [selectable] 给出：在分组列表里就是这张卡片对应的
/// [DownloadPageInfo]，在手动文件夹里则是那张卡片的替身条目。
class PageInfoItem<T extends MultiSelectData> extends StatelessWidget {
  const PageInfoItem({
    super.key,
    required this.controller,
    required this.downloadService,
    required this.selectable,
    required this.pageInfo,
    required this.seasonKey,
    required this.enableMultiSelect,
    required this.progress,
    required this.updatePageDm,
  });

  final BaseMultiSelectMixin<T> controller;
  final DownloadService downloadService;
  final T selectable;
  final DownloadPageInfo pageInfo;

  /// 所属合集的 [DownloadSeasonInfo.playlistKey]，用于播放范围与页内跳转。
  final String seasonKey;
  final bool enableMultiSelect;
  final ChangeNotifier progress;
  final ValueChanged<DownloadPageInfo> updatePageDm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);

    void onLongPress() {
      if (enableMultiSelect) {
        return;
      }
      final menuContext = context;
      showDialog(
        context: context,
        builder: (context) => SimpleDialog(
          clipBehavior: Clip.hardEdge,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            DialogOption(
              onPressed: () {
                Get.back();
                confirmDeletePages(
                  context: menuContext,
                  downloadService: downloadService,
                  pages: [pageInfo],
                  title: '确定删除该视频？',
                );
              },
              child: const Text('删除', style: TextStyle(fontSize: 14)),
            ),
            DialogOption(
              onPressed: () {
                Get.back();
                updatePageDm(pageInfo);
              },
              child: const Text('更新弹幕', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          if (controller.enableMultiSelect.value) {
            controller.onSelect(selectable);
            return;
          }
          Get.to(
            DownloadDetailPage(
              seasonKey: seasonKey,
              pageId: pageInfo.pageId,
              title: pageInfo.title,
              progress: progress,
            ),
          );
        },
        onLongPress: onLongPress,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Style.safeSpace,
            vertical: 5,
          ),
          child: Row(
            spacing: 10,
            children: [
              Stack(
                clipBehavior: .none,
                children: [
                  AspectRatio(
                    aspectRatio: Style.aspectRatio,
                    child: LayoutBuilder(
                      builder: (context, constraints) => NetworkImgLayer(
                        src: pageInfo.cover,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      ),
                    ),
                  ),
                  PBadge(
                    text: '${pageInfo.entries.length}个视频',
                    right: 6.0,
                    bottom: 6.0,
                    isBold: false,
                    type: .gray,
                  ),
                  if (pageInfo.seasonType case final pgcType?)
                    if (BiliUtils.pgcType2Label(pgcType) case final label?)
                      PBadge(
                        text: label,
                        right: 6.0,
                        top: 6.0,
                      ),
                  Positioned.fill(
                    child: selectMask(colorScheme, selectable.checked),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        pageInfo.title,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          height: 1.42,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: .end,
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Text(
                          '${pageInfo.entries.fold(0, (p, n) => p + n.totalBytes).formatSize}  ${pageInfo.entries.first.ownerName ?? ""}',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: colorScheme.outline,
                          ),
                        ),
                        pageInfo.entries.first.moreBtn(
                          colorScheme,
                          extraItemsBuilder: (menuContext) =>
                              buildGroupCardMenuItems(
                                context: menuContext,
                                entries: pageInfo.entries,
                                item: pageInfo.toFolderItem(),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

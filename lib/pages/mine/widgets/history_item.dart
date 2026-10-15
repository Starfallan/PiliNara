import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/history/widgets/item.dart' show onPushHistory;
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:material_ui/material_ui.dart';

/// 观看记录快捷卡片（我的页横向列表）
class MineHistoryItem extends StatelessWidget {
  const MineHistoryItem({
    super.key,
    required this.item,
    required this.onPop,
  });

  final HistoryItemModel item;
  final VoidCallback onPop;

  // 宽高比与 HistoryItem 大图区一致（16:10）
  static const double _cardWidth = 180.0;
  static const double _cardHeight = 110.0;

  bool get _isArticle => item.history.business?.contains('article') == true;

  bool get _isLive => item.history.business == 'live';

  bool get _isPgc => item.history.business == 'pgc';

  bool get _isCheese => item.history.business == 'cheese';

  bool get _isVideo => !_isArticle && !_isLive && !_isPgc && !_isCheese;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDuration = item.hasDuration;
    final coverSrc = item.cover?.isNotEmpty == true
        ? item.cover
        : item.covers?.firstOrNull ?? '';

    return GestureDetector(
      onTap: () => onPushHistory(item).whenComplete(onPop),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.onInverseSurface.withValues(
                    alpha: 0.4,
                  ),
                  offset: const Offset(6, -8),
                  blurRadius: 0.0,
                  spreadRadius: 0.0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: SizedBox(
                width: _cardWidth,
                height: _cardHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    NetworkImgLayer(
                      src: coverSrc,
                      width: _cardWidth,
                      height: _cardHeight,
                    ),
                    // 右上角：直播状态 / 专栏 / 已收藏 / 角标
                    if (_isLive)
                      PBadge(
                        text: item.liveStatus == 1 ? '直播中' : '未开播',
                        top: 6.0,
                        right: 6.0,
                        type: item.liveStatus == 1
                            ? PBadgeType.primary
                            : PBadgeType.gray,
                      )
                    else if (_isArticle)
                      const PBadge(
                        text: '专栏',
                        top: 6.0,
                        right: 6.0,
                        type: PBadgeType.secondary,
                      )
                    else if (item.isFav == 1)
                      const PBadge(
                        text: '已收藏',
                        top: 6.0,
                        right: 6.0,
                        type: PBadgeType.gray,
                      )
                    else if (item.badge?.isNotEmpty == true)
                      PBadge(
                        text: item.badge,
                        top: 6.0,
                        right: 6.0,
                        type: PBadgeType.primary,
                      ),
                    // 右下角：视频进度（只显示角标文字，无进度条）
                    if (_isVideo && hasDuration)
                      PBadge(
                        text: item.progress == -1
                            ? '已看完'
                            : '${DurationUtils.formatDuration(item.progress)}/${DurationUtils.formatDuration(item.duration)}',
                        right: 6.0,
                        bottom: 6.0,
                        type: PBadgeType.gray,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: _cardWidth,
            child: Text(
              ' ${item.title ?? ''}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: _cardWidth,
            child: Text(
              ' ${item.authorName ?? item.showTitle ?? ''}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.labelSmall!.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

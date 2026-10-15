import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/pages/subscription/widgets/item.dart' show onPushSub;
import 'package:PiliPlus/utils/utils.dart';
import 'package:material_ui/material_ui.dart';

class MineSubItem extends StatelessWidget {
  const MineSubItem({
    super.key,
    required this.item,
    required this.onPop,
  });

  final SubItemModel item;
  final VoidCallback onPop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroTag = Utils.makeHeroTag(item.id);
    final label = item.type2Label;
    return GestureDetector(
      onTap: () => onPushSub(label, heroTag, item)?.whenComplete(onPop),
      behavior: .opaque,
      child: Column(
        crossAxisAlignment: .start,
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
                width: 180,
                height: 110,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Hero(
                      tag: heroTag,
                      child: NetworkImgLayer(
                        src: item.cover,
                        width: 180,
                        height: 110,
                      ),
                    ),
                    PBadge(right: 6, top: 6, text: label),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ' ${item.title}',
            maxLines: 2,
            overflow: .ellipsis,
            style: const TextStyle(height: 1.42, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

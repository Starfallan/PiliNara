import 'package:PiliPlus/common/widgets/gesture/tap_gesture_recognizer.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

Widget dynInteraction({
  required ThemeData theme,
  required List<ModuleInteractionItem> items,
  required DynamicItemModel dynItem,
}) {
  try {
    Widget child;
    if (items.length > 1) {
      child = Column(
        spacing: 3,
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: items.map((e) => _item(theme, e)).toList(),
      );
    } else {
      child = _item(theme, items.single);
    }

    final hotItem = items.firstWhereOrNull((e) => e.type == 1);
    VoidCallback? onTap;
    if (hotItem != null) {
      final rid = hotItem.desc?.richTextNodes
          ?.firstWhereOrNull(
            (e) => e.type == 'RICH_TEXT_NODE_TYPE_AT',
          )
          ?.rid;
      final rpid = rid != null ? int.tryParse(rid) : null;
      if (rpid != null) {
        onTap = () => PageUtils.pushDynDetail(dynItem, targetRpid: rpid);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const .only(left: 8),
        margin: const .only(left: 12, right: 12, top: 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 1.5,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: child,
      ),
    );
  } catch (e) {
    if (kDebugMode) {
      return Text(
        'interaction error: $e',
        style: TextStyle(color: theme.colorScheme.error),
      );
    }
    return const SizedBox.shrink();
  }
}

Widget _item(
  ThemeData theme,
  ModuleInteractionItem item,
) {
  final isHotComment = item.type == 1;
  return Text.rich(
    style: const TextStyle(fontSize: 13, height: 1.3),
    strutStyle: const StrutStyle(fontSize: 13, height: 1.3, leading: 0),
    TextSpan(
      children: [
        WidgetSpan(
          alignment: .middle,
          child: Padding(
            padding: const .only(right: 6),
            child: Icon(
              size: 13,
              color: theme.colorScheme.outline,
              switch (item.type) {
                1 => FontAwesomeIcons.comment,
                _ => FontAwesomeIcons.thumbsUp,
              },
            ),
          ),
        ),
        ...item.desc!.richTextNodes!.map(
          (e) {
            final isAt = e.type == 'RICH_TEXT_NODE_TYPE_AT';
            // For hot comments (type=1), the whole item is tappable via GestureDetector;
            // AT node rid is the comment rpid, not user mid — don't navigate to profile.
            return TextSpan(
              text: e.origText,
              style: isAt && !isHotComment
                  ? null
                  : TextStyle(color: theme.colorScheme.onSurfaceVariant),
              recognizer: isAt && !isHotComment
                  ? (NoDeadlineTapGestureRecognizer()
                      ..onTap = () => Get.toNamed('/member?mid=${e.rid}'))
                  : null,
            );
          },
        ),
      ],
    ),
  );
}

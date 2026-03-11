import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/avatar_badge_type.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';

class PendantAvatar extends StatelessWidget {
  final BadgeType _badgeType;
  final String? avatar;
  final double size;
  final double badgeSize;
  final String? garbPendantImage;
  final int? roomId;
  final VoidCallback? onTap;
  final bool isMemberAvatar;

  const PendantAvatar({
    super.key,
    required this.avatar,
    required this.size,
    this.isMemberAvatar = false,
    double? badgeSize,
    bool isVip = false,
    int? officialType,
    this.garbPendantImage,
    this.roomId,
    this.onTap,
  }) : _badgeType = officialType == null || officialType < 0
           ? isVip
                 ? BadgeType.vip
                 : BadgeType.none
           : officialType == 0
           ? BadgeType.person
           : officialType == 1
           ? BadgeType.institution
           : BadgeType.none,
       badgeSize = badgeSize ?? size / 3;

  static bool showDynDecorate = Pref.showDynDecorate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget? pendant;
    if (showDynDecorate && !garbPendantImage.isNullOrEmpty) {
      final pendantSize = size * 1.75;
      pendant = Positioned(
        // -(size * 1.75 - size) / 2
        top: -0.375 * size + (isMemberAvatar ? 2 : 0),
        child: IgnorePointer(
          child: NetworkImgLayer(
            type: .emote,
            width: pendantSize,
            height: pendantSize,
            src: garbPendantImage,
            getPlaceHolder: () => const SizedBox.shrink(),
          ),
        ),
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        onTap == null
            ? _buildAvatar(colorScheme, isMemberAvatar)
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: _buildAvatar(colorScheme, isMemberAvatar),
              ),
        ?pendant,
        if (roomId != null)
          Positioned(
            bottom: 0,
            child: InkWell(
              onTap: () => PageUtils.toLiveRoom(roomId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(36)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      size: 16,
                      applyTextScaling: true,
                      Icons.equalizer_rounded,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    Text(
                      '直播中',
                      style: TextStyle(
                        height: 1,
                        fontSize: 13,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_badgeType != BadgeType.none)
          _buildBadge(context, colorScheme, isMemberAvatar),
      ],
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme, bool isMemberAvatar) =>
      isMemberAvatar
      ? DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: colorScheme.surface,
            ),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: NetworkImgLayer(
              src: avatar,
              width: size,
              height: size,
              type: ImageType.avatar,
            ),
          ),
        )
      : NetworkImgLayer(
          src: avatar,
          width: size,
          height: size,
          type: ImageType.avatar,
        );

  Widget _buildBadge(
    BuildContext context,
    ColorScheme colorScheme,
    bool isMemberAvatar,
  ) {
    final child = switch (_badgeType) {
      BadgeType.vip => Image.asset(
        'assets/images/big-vip.png',
        width: badgeSize,
        height: badgeSize,
        cacheWidth: badgeSize.cacheSize(context),
        semanticLabel: _badgeType.desc,
      ),
      _ => Icon(
        Icons.offline_bolt,
        color: _badgeType.color,
        size: badgeSize,
        semanticLabel: _badgeType.desc,
      ),
    };
    final offset = isMemberAvatar ? 2.0 : 0.0;
    return Positioned(
      right: offset,
      bottom: offset,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface,
          ),
          child: child,
        ),
      ),
    );
  }
}

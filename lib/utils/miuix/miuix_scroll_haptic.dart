import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_ui/material_ui.dart';

/// miuix 的滚动边界触感判据里用到的两个阈值。
///
/// 取自 miuix 的 `scrollEndHaptic`(`miuix-ui/.../utils/ScrollEndHaptic.kt`):
/// `POST_FLING_AVAILABLE_VELOCITY_THRESHOLD = 1.0`(抛掷时边界吃不下的速度)、
/// `PRE_SCROLL_RESET_THRESHOLD = 1.0`(往回滚多少算离开边界)。
abstract final class MiuixScrollHaptic {
  /// 边界吃不下的速度阈值(px/s)。
  static const double availableVelocityThreshold = 1;

  /// 往回滚多少像素算离开边界、可以再次触发。
  static const double resetThreshold = 1;

  /// 是否该给一次触感。
  ///
  /// miuix 的条件是「可用速度 > 1 且已消耗速度 < 25」——也就是边界把抛掷速度吃掉了。
  /// Flutter 的 `OverscrollNotification` 只在滚动视图吃不下这段位移时才发,已经等价于后者,
  /// 所以这里只要判断速度与「这个边界是否已经震过」。
  static bool shouldHaptic({
    required double overscroll,
    required double velocity,
    required bool alreadyHit,
  }) {
    if (alreadyHit) {
      return false;
    }
    return overscroll.abs() > 0 && velocity.abs() >= availableVelocityThreshold;
  }
}

/// 抛掷到列表边界时给一次触感的包装组件(等价于 miuix 的 `Modifier.scrollEndHaptic`)。
///
/// miuix 用的是 `HapticFeedbackType.TextHandleMove`,在 Flutter 里对应
/// [HapticFeedback.selectionClick]。
///
/// 接一次就够:它的判据与状态机对所有子滚动视图生效。同一个边界只震一次,往回滚超过
/// [MiuixScrollHaptic.resetThreshold] 之后复位,与 miuix 的状态机一致。
class MiuixScrollEndHaptic extends StatefulWidget {
  const MiuixScrollEndHaptic({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// 关掉就完全不触发(有些机型系统自己在边缘也会给震动,那时可以关掉避免双震)。
  final bool enabled;

  @override
  State<MiuixScrollEndHaptic> createState() => _MiuixScrollEndHapticState();
}

enum _HitBoundary { none, top, bottom }

class _MiuixScrollEndHapticState extends State<MiuixScrollEndHaptic> {
  _HitBoundary _hit = _HitBoundary.none;

  bool _onNotification(ScrollNotification notification) {
    if (notification is! OverscrollNotification) {
      return false;
    }
    final overscroll = notification.overscroll;
    final boundary = overscroll > 0 ? _HitBoundary.bottom : _HitBoundary.top;
    // 往回滚够多就复位,允许再次触发。
    if (_hit != _HitBoundary.none &&
        _hit != boundary &&
        overscroll.abs() > MiuixScrollHaptic.resetThreshold) {
      _hit = _HitBoundary.none;
    }
    if (MiuixScrollHaptic.shouldHaptic(
      overscroll: overscroll,
      velocity: notification.velocity ?? 0,
      alreadyHit: _hit == boundary,
    )) {
      _hit = boundary;
      if (widget.enabled) {
        HapticFeedback.selectionClick();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}

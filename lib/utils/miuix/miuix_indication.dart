import 'package:material_ui/material_ui.dart';
import 'package:PiliPlus/utils/miuix/miuix_motion.dart';

/// miuix 的按压反馈：整块表面淡入一层很淡的纯色，而不是水波纹。
///
/// MIUI 的控件按下时不扩散圆形波纹，而是给整个表面叠一层 10% 的前景色（miuix 的
/// `MiuixIndication`：PRESS_ALPHA_DELTA = 0.10，悬停 0.06，聚焦 0.08，进出用弹簧）。这里用
/// 时长近似的曲线复现按下/抬起：进入 200ms、退出 350ms，对应 miuix 弹簧的 0.2 / 0.35 秒响应。
///
/// 接进主题即可替换掉 Material 的水波纹（Android 上 M3 默认是 `InkSparkle`）：
///
/// ```dart
/// ThemeData(splashFactory: MiuixIndication(colors.onSurface))
/// ```
///
/// 与 miuix 的差异：miuix 另外把悬停、聚焦的增量也算进这层叠加色里，Flutter 的悬停/聚焦高亮
/// 由 `InkWell` 的 `overlayColor` 单独负责，所以这里只画按下状态；画笔会裁到控件自己的圆角内。
///
/// 另外要注意 Flutter 的调用时机：点按成功时 `InkWell` 只调 [InteractiveInkFeature.confirm]，
/// **不会**再调 [InteractiveInkFeature.cancel]，所以抬手后的淡出必须由 [confirm] 自己安排——
/// 否则这层叠加色会一直留在被点过的控件上（表现就是「切走以后上一个标签页上还剩一块色」）。
class MiuixIndication extends InteractiveInkFeatureFactory {
  const MiuixIndication(
    this.color, {
    this.pressAlpha = 0.1,
    this.enterDuration = MiuixMotion.enter,
    this.exitDuration = MiuixMotion.exit,
  });

  /// 叠加色，通常是 `MiuixColors.onSurface`。
  final Color color;

  /// 按下时叠加的最大不透明度（miuix 的 PRESS_ALPHA_DELTA）。
  final double pressAlpha;

  /// 按下提示淡入的时长。
  final Duration enterDuration;

  /// 抬起后淡出的时长。
  final Duration exitDuration;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return _MiuixIndicationFeature(
      controller: controller,
      referenceBox: referenceBox,
      color: this.color,
      pressAlpha: pressAlpha,
      enterDuration: enterDuration,
      exitDuration: exitDuration,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      onRemoved: onRemoved,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MiuixIndication &&
      other.color == color &&
      other.pressAlpha == pressAlpha &&
      other.enterDuration == enterDuration &&
      other.exitDuration == exitDuration;

  @override
  int get hashCode =>
      Object.hash(color, pressAlpha, enterDuration, exitDuration);
}

class _MiuixIndicationFeature extends InteractiveInkFeature {
  _MiuixIndicationFeature({
    required super.controller,
    required super.referenceBox,
    required super.color,
    required this.pressAlpha,
    required this.enterDuration,
    required this.exitDuration,
    this.rectCallback,
    this.borderRadius,
    super.customBorder,
    super.onRemoved,
  }) {
    _controller = AnimationController(
      vsync: controller.vsync,
      duration: enterDuration,
    )
      ..addListener(controller.markNeedsPaint)
      ..addStatusListener(_handleStatusChanged);
    controller.addInkFeature(this);
  }

  final double pressAlpha;
  final Duration enterDuration;
  final Duration exitDuration;
  final RectCallback? rectCallback;
  final BorderRadius? borderRadius;

  late final AnimationController _controller;
  bool _disposed = false;

  @override
  void confirm() {
    // 先按 miuix 的进入时长淡入到 pressAlpha，再按退出时长淡出到 0（对应 miuix 的
    // PressEnterSpring / PressExitSpring）。
    _controller.duration = enterDuration;
    _controller.forward().whenComplete(() {
      if (_disposed) {
        return;
      }
      _controller.duration = exitDuration;
      _controller.reverse();
    });
  }

  @override
  void cancel() {
    _controller
      ..duration = exitDuration
      ..reverse();
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    // miuix 的进出都是弹簧，这里用它的减速曲线近似（阻尼 1/0.95 时的形状最接近）。
    final value = MiuixMotion.decelerate.transform(_controller.value);
    if (value <= 0) {
      return;
    }
    final rect = rectCallback?.call() ?? (Offset.zero & referenceBox.size);
    if (rect.isEmpty) {
      return;
    }
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * pressAlpha * value);
    final border = customBorder;
    final rrect = border == null ? borderRadius?.toRRect(rect) : null;
    canvas.save();
    if (border != null) {
      canvas.clipPath(border.getOuterPath(rect));
    } else if (rrect != null) {
      canvas.clipRRect(rrect);
    }
    canvas
      ..drawRect(rect, paint)
      ..restore();
  }
}

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// miuix 的动效参数。
///
/// 曲线与时长都取自 miuix 自己的实现，而不是 Flutter/Material 的默认值：
///
/// * [programmatic] 是 miuix 导航的进场曲线（`NavProgrammaticEasing`）：把一条欠阻尼弹簧的
///   阶跃响应烘焙成一条曲线（response = 0.8、damping = 0.95），配 [programmaticDuration]
///   （`NavDriverSpec.PROGRAMMATIC_DURATION_MILLIS` = 500ms）播放。中段很快、尾巴很长，不会回弹。
/// * [decelerate] / [accelerate] / [sinOut] 对应 miuix `anim` 模块里的 `DecelerateEasing`、
///   `AccelerateEasing` 与 `SinOutEasing`。
/// * [spring] 对应 `folmeSpring(damping, response)`：刚度 k = (2π/response)²、阻尼比可调。
/// * [fast] / [enter] / [exit] 是 miuix 组件自己用的时长：拖拽手柄按下 100ms、抬起 150ms，
///   按压反馈进入 200ms、退出 350ms。
abstract final class MiuixMotion {
  /// miuix 按压反馈进入的时长（`MiuixIndication` 的 PressEnterSpring，响应 0.2s）。
  static const Duration enter = Duration(milliseconds: 200);

  /// miuix 按压反馈退出的时长（`MiuixIndication` 的 PressExitSpring，响应 0.35s）。
  static const Duration exit = Duration(milliseconds: 350);

  /// 快速反馈（手柄按下、抬起），对应 miuix 手柄的 100ms / 150ms。
  static const Duration fast = Duration(milliseconds: 100);

  /// 快速反馈的回落时长。
  static const Duration fastExit = Duration(milliseconds: 150);

  /// miuix 导航的程序化过场时长（`PROGRAMMATIC_DURATION_MILLIS`）。
  static const Duration programmaticDuration = Duration(milliseconds: 500);

  /// miuix 导航的过场曲线（烘焙好的弹簧阶跃响应，response = 0.8、damping = 0.95）。
  static const Curve programmatic = _MiuixProgrammaticCurve();

  /// miuix 的 `DecelerateEasing`：1 − (1 − t)²。
  static const Curve decelerate = _MiuixDecelerateCurve();

  /// miuix 的 `AccelerateEasing`：t²。
  static const Curve accelerate = _MiuixAccelerateCurve();

  /// miuix 的 `SinOutEasing`：sin(t · π/2)。
  static const Curve sinOut = _MiuixSinOutCurve();

  /// miuix 的 `folmeSpring`：刚度 k = (2π / response)²，阻尼比 [damping]，质量取 1。
  ///
  /// damping = 1 时临界阻尼（不回弹），小于 1 会来回摆一下，大于 1 更慢。
  static SpringDescription spring({
    double damping = 1,
    double response = 0.3,
  }) {
    final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
    // 阻尼系数 c = 2ζ√(k·m)，质量 m = 1。
    final critical = 2 * math.sqrt(stiffness);
    return SpringDescription(
      mass: 1,
      stiffness: stiffness,
      damping: damping * critical,
    );
  }

  /// 稳定后的默认弹簧（miuix 导航手势落位的 spring：damping 1、stiffness 146）。
  static SpringDescription get settleSpring => const SpringDescription(
    mass: 1,
    stiffness: 146,
    damping: 2 * 12.0830459736, // 2 * sqrt(146) ≈ 临界阻尼
  );
}

/// miuix 过场曲线：`NavSettleEasing(response = 0.8, damping = 0.95)` 的阶跃响应。
///
/// 解一组欠阻尼弹簧：
/// ω = 2π/response、k = ω²、c = damping · 4π/response，
/// w = √(4k − c²)/2、r = −c/2、c₂ = r/w，
/// f(t) = e^{r·t} · (−cos(w·t) + c₂·sin(w·t)) + 1。
class _MiuixProgrammaticCurve extends Curve {
  const _MiuixProgrammaticCurve();

  static const double _response = 0.8;
  static const double _damping = 0.95;

  @override
  double transformInternal(double t) {
    const omega = 2 * math.pi / _response;
    const k = omega * omega;
    const c = _damping * 4 * math.pi / _response;
    final w = math.sqrt(4 * k - c * c) / 2;
    const r = -c / 2;
    final c2 = r / w;
    final decay = math.exp(r * t);
    return decay * (-math.cos(w * t) + c2 * math.sin(w * t)) + 1;
  }
}

/// miuix 的 `DecelerateEasing`（factor = 1）。
class _MiuixDecelerateCurve extends Curve {
  const _MiuixDecelerateCurve();

  @override
  double transformInternal(double t) => 1 - (1 - t) * (1 - t);
}

/// miuix 的 `AccelerateEasing`（factor = 1）。
class _MiuixAccelerateCurve extends Curve {
  const _MiuixAccelerateCurve();

  @override
  double transformInternal(double t) => t * t;
}

/// miuix 的 `SinOutEasing`。
class _MiuixSinOutCurve extends Curve {
  const _MiuixSinOutCurve();

  @override
  double transformInternal(double t) => math.sin(t * math.pi / 2);
}

/// miuix 的页面过渡（对应 `NavTransitions.MiuixDefault`）。
///
/// 进场页从右侧整屏滑入，被覆盖的页面向左视差移动四分之一屏宽、透明度降到 90%，时长与曲线
/// 用 miuix 导航那套（[MiuixMotion.programmaticDuration] + [MiuixMotion.programmatic]）。
class MiuixPageTransitionsBuilder extends PageTransitionsBuilder {
  const MiuixPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) {
      return child;
    }
    final width = MediaQuery.sizeOf(context).width;
    return _MiuixPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      width: width,
      child: child,
    );
  }
}

class _MiuixPageTransition extends StatelessWidget {
  const _MiuixPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.width,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inCurve = CurvedAnimation(
      parent: animation,
      curve: MiuixMotion.programmatic,
      reverseCurve: MiuixMotion.programmatic.flipped,
    );
    final coverCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: MiuixMotion.programmatic,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([inCurve, coverCurve]),
      child: child,
      builder: (context, child) {
        final enter = inCurve.value;
        final cover = coverCurve.value;
        final page = child ?? const SizedBox.shrink();
        return Transform.translate(
          // 被覆盖时向左视差 1/4 屏宽（miuix 的 covered 处理）。
          offset: Offset(-cover * width * 0.25, 0),
          child: Opacity(
            opacity: 1 - 0.1 * cover,
            child: Transform.translate(
              // 进场页从右侧整屏滑入。
              offset: Offset((1 - enter) * width, 0),
              child: cover <= 0
                  ? page
                  : Stack(
                      fit: StackFit.passthrough,
                      children: [
                        page,
                        // miuix 的遮罩：正在被覆盖的页面上压一层最深 50% 的暗色
                        // （NavDisplayEffects.dimAmount = 0.5），随过场进度淡入。
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: const Color(
                                0xFF000000,
                              ).withValues(alpha: 0.5 * cover),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:material_ui/material_ui.dart';

/// miuix 的底部弹层拖拽手柄。
///
/// miuix 的弹层顶部有一条固定的手柄：抓取区 24dp 高、手柄本身 45×4dp、圆角 2dp，颜色是 20%
/// 的次级文字色；按下或拖动时手柄加长到 55dp、纵向放大 1.15 倍、颜色加深到 35%，松开后再
/// 回到原样（进入 100ms、退出 150ms）。
///
/// 这里只画外观并监听按下，不参与手势判定——拖动仍然交给弹层自己的识别器，所以放在
/// [BottomSheet] 内容上方不会抢走滚动或拖拽。
class MiuixDragHandle extends StatefulWidget {
  const MiuixDragHandle({super.key, this.color});

  /// 手柄颜色，默认取 `colorScheme.onSurfaceVariant`（即 miuix 的次级文字色）。
  final Color? color;

  /// 未按下时的手柄宽度。
  static const double restWidth = 45;

  /// 按下时的手柄宽度。
  static const double pressedWidth = 55;

  /// 手柄高度。
  static const double handleHeight = 4;

  /// 手柄圆角（4dp 高、半径 2dp，也就是胶囊）。
  static const double handleRadius = 2;

  /// 抓取区高度。
  static const double areaHeight = 24;

  @override
  State<MiuixDragHandle> createState() => _MiuixDragHandleState();
}

class _MiuixDragHandleState extends State<MiuixDragHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 150),
  );

  late final Animation<double> _pressed = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (pressed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: SizedBox(
          height: MiuixDragHandle.areaHeight,
          width: double.infinity,
          child: Center(
            child: AnimatedBuilder(
              animation: _pressed,
              builder: (context, _) {
                final t = _pressed.value;
                return Container(
                  width: _lerp(
                    MiuixDragHandle.restWidth,
                    MiuixDragHandle.pressedWidth,
                    t,
                  ),
                  height: _lerp(
                    MiuixDragHandle.handleHeight,
                    MiuixDragHandle.handleHeight * 1.15,
                    t,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: _lerp(0.2, 0.35, t)),
                    borderRadius: BorderRadius.circular(
                      MiuixDragHandle.handleRadius,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

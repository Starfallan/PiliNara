import 'package:PiliPlus/utils/miuix/miuix_icon_data.dart';
import 'package:material_ui/material_ui.dart';

/// 把 miuix 图标的 SVG 风格路径串解析成 [Path]。
///
/// 生成器只产出绝对坐标的 `M` / `L` / `H` / `V` / `Q` / `C` / `Z`,所以这里只认这几种命令,
/// 不做相对命令与圆弧的兼容（省下来的复杂度换解析速度)。解析结果按路径串缓存,重复绘制不重复解析。
Path parseMiuixIconPath(String svgPath) {
  final cached = _pathCache[svgPath];
  if (cached != null) {
    return cached;
  }
  final path = Path();
  final tokens = svgPath
      .split(RegExp(r'[\s,]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  var i = 0;
  var currentX = 0.0;
  var currentY = 0.0;
  double read() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    switch (tokens[i++]) {
      case 'M':
        currentX = read();
        currentY = read();
        path.moveTo(currentX, currentY);
      case 'L':
        currentX = read();
        currentY = read();
        path.lineTo(currentX, currentY);
      case 'H':
        currentX = read();
        path.lineTo(currentX, currentY);
      case 'V':
        currentY = read();
        path.lineTo(currentX, currentY);
      case 'Q':
        final controlX = read();
        final controlY = read();
        currentX = read();
        currentY = read();
        path.quadraticBezierTo(controlX, controlY, currentX, currentY);
      case 'C':
        final x1 = read();
        final y1 = read();
        final x2 = read();
        final y2 = read();
        currentX = read();
        currentY = read();
        path.cubicTo(x1, y1, x2, y2, currentX, currentY);
      case 'Z':
        path.close();
      default:
        break;
    }
  }
  _pathCache[svgPath] = path;
  return path;
}

final Map<String, Path> _pathCache = {};

/// miuix 的图标。
///
/// miuix 的图标是矢量(不是字体),所以这里用 [CustomPaint] 把路径画出来;路径已经在生成时
/// 翻正方向并缩放到 24×24,这里只负责按 [size] 缩放与上色。
class MiuixIcon extends StatelessWidget {
  const MiuixIcon(
    this.data, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final MiuixIconData data;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolved = color ?? iconTheme.color;
    final painter = CustomPaint(
      size: Size.square(size),
      painter: _MiuixIconPainter(
        // 生成器已经把坐标缩放并翻正到 24×24，这里直接用。
        path: parseMiuixIconPath(data.path),
        color: resolved,
      ),
    );
    if (semanticLabel == null) {
      return painter;
    }
    return Semantics(label: semanticLabel, child: painter);
  }
}

class _MiuixIconPainter extends CustomPainter {
  const _MiuixIconPainter({required this.path, required this.color});

  final Path path;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas
      ..save()
      ..transform(Matrix4.diagonal3Values(scale, scale, 1).storage)
      ..drawPath(
        path,
        Paint()
          ..color = color ?? const Color(0xFF000000)
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_MiuixIconPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// miuix 的连续圆角（squircle）。
///
/// MIUI / HyperOS 的圆角不是圆的一段弧，而是"连续圆角"：角块比半径大一圈，两条边用三次贝塞尔
/// 连接过去，所以直线和圆弧交界处没有突然的曲率跳变。miuix 在 Android 上用 `miuix-squircle`
/// 模块的 shader 画这套轮廓，这里用同一套几何把它写成 [Path]：
///
/// * 角块（corner tile）= 圆角半径 × [miuixSquircleExtension]，并夹在短边的一半以内；
/// * 每条边到角块之间用三次贝塞尔过渡，控制点比例固定为 [miuixSquircleControl]。
///
/// 把 [miuixSquircleExtension] 取 1 就退化成普通圆角，这也是 miuix 在不支持 shader 的平台上
/// 的回落画法（[MiuixSquircleBorder.enabled] 为 false 时走同一条路）。
const double miuixSquircleExtension = 1.1;

/// miuix 的贝塞尔控制点比例，必须与它预烘焙 SDF 时用的值一致。
const double miuixSquircleControl = 0.643;

/// 角块尺寸：`radius × extension`，夹在 0 与短边一半之间，与 miuix 的 `tile` 一致。
double miuixSquircleTile(
  double cornerRadius,
  Size size, {
  double extension = miuixSquircleExtension,
}) {
  final clamped = extension.clamp(1.0, 2.0);
  final halfMin = math.min(size.width.abs(), size.height.abs()) * 0.5;
  return math.min(
    math.max(0.0, cornerRadius * clamped),
    math.max(0.0, halfMin),
  );
}

/// 生成 [rect] 的 miuix 连续圆角路径。
///
/// [enabled] 为 false 时返回普通圆角矩形（miuix 的回落画法）；[topOnly] 用于底部弹层这类只圆
/// 上面两角的表面。
Path miuixSquirclePath(
  Rect rect,
  double cornerRadius, {
  double extension = miuixSquircleExtension,
  bool enabled = true,
  bool topOnly = false,
}) {
  final path = Path();
  if (rect.isEmpty) {
    return path;
  }
  if (!enabled) {
    final horizontal = math.max(0.0, cornerRadius);
    path.addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(horizontal),
        topRight: Radius.circular(horizontal),
        bottomLeft: topOnly ? Radius.zero : Radius.circular(horizontal),
        bottomRight: topOnly ? Radius.zero : Radius.circular(horizontal),
      ),
    );
    return path;
  }

  final tile = miuixSquircleTile(cornerRadius, rect.size, extension: extension);
  if (tile <= 0) {
    path.addRect(rect);
    return path;
  }

  final left = rect.left;
  final top = rect.top;
  final right = rect.right;
  final bottom = rect.bottom;
  final handle = tile * (1 - miuixSquircleControl);

  path
    ..moveTo(left + tile, top)
    ..lineTo(right - tile, top)
    ..cubicTo(right - handle, top, right, top + handle, right, top + tile);
  if (topOnly) {
    path
      ..lineTo(right, bottom)
      ..lineTo(left, bottom);
  } else {
    path
      ..lineTo(right, bottom - tile)
      ..cubicTo(
        right,
        bottom - handle,
        right - handle,
        bottom,
        right - tile,
        bottom,
      )
      ..lineTo(left + tile, bottom)
      ..cubicTo(
        handle + left,
        bottom,
        left,
        bottom - handle,
        left,
        bottom - tile,
      );
  }
  path
    ..lineTo(left, top + tile)
    ..cubicTo(left, top + handle, left + handle, top, left + tile, top)
    ..close();
  return path;
}

/// miuix 连续圆角的描边形状，可直接当作 [ThemeData] 各组件主题的 `shape` 使用。
///
/// miuix 的圆角是全局开关（`LocalSquircleEnabled`，默认开），[enabled] 对应它的回落分支。
class MiuixSquircleBorder extends OutlinedBorder {
  const MiuixSquircleBorder({
    this.cornerRadius = 16,
    this.extension = miuixSquircleExtension,
    this.enabled = true,
    this.topOnly = false,
    super.side = BorderSide.none,
  });

  /// 圆角半径；连续圆角的实际角块是它的 [extension] 倍。
  final double cornerRadius;

  /// 角块相对半径的倍数，miuix 的默认值是 1.1。
  final double extension;

  /// 关掉就退回普通圆角矩形。
  final bool enabled;

  /// 只圆上面两角（底部弹层）。
  final bool topOnly;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      miuixSquirclePath(
        rect,
        cornerRadius,
        extension: extension,
        enabled: enabled,
        topOnly: topOnly,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final inset = math.max(side.strokeInset, 0.0);
    return miuixSquirclePath(
      rect.deflate(inset),
      math.max(0.0, cornerRadius - inset),
      extension: extension,
      enabled: enabled,
      topOnly: topOnly,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.color.a == 0) {
      return;
    }
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), side.toPaint());
  }

  @override
  MiuixSquircleBorder copyWith({BorderSide? side}) => MiuixSquircleBorder(
    cornerRadius: cornerRadius,
    extension: extension,
    enabled: enabled,
    topOnly: topOnly,
    side: side ?? this.side,
  );

  @override
  MiuixSquircleBorder scale(double t) => MiuixSquircleBorder(
    cornerRadius: cornerRadius * t,
    extension: extension,
    enabled: enabled,
    topOnly: topOnly,
    side: side.scale(t),
  );

  @override
  bool operator ==(Object other) =>
      other is MiuixSquircleBorder &&
      other.cornerRadius == cornerRadius &&
      other.extension == extension &&
      other.enabled == enabled &&
      other.topOnly == topOnly &&
      other.side == side;

  @override
  int get hashCode =>
      Object.hash(cornerRadius, extension, enabled, topOnly, side);

  @override
  String toString() =>
      'MiuixSquircleBorder($cornerRadius, extension: $extension, topOnly: $topOnly)';
}

/// 输入框用的连续圆角边框。
///
/// MIUI 的输入框是填充式的（底色 `secondaryContainer`，圆角 16，不带描边），所以默认
/// [borderSide] 是 [BorderSide.none]；聚焦或报错时由调用方给出对应的描边色。
class MiuixSquircleInputBorder extends InputBorder {
  const MiuixSquircleInputBorder({
    this.cornerRadius = 16,
    this.extension = miuixSquircleExtension,
    this.enabled = true,
    super.borderSide = BorderSide.none,
  });

  final double cornerRadius;
  final double extension;
  final bool enabled;

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions {
    final inset = math.max(borderSide.strokeInset, 0.0);
    return EdgeInsets.all(inset);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      miuixSquirclePath(
        rect,
        cornerRadius,
        extension: extension,
        enabled: enabled,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final inset = math.max(borderSide.strokeInset, 0.0);
    return miuixSquirclePath(
      rect.deflate(inset),
      math.max(0.0, cornerRadius - inset),
      extension: extension,
      enabled: enabled,
    );
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none || borderSide.color.a == 0) {
      return;
    }
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), borderSide.toPaint());
  }

  @override
  MiuixSquircleInputBorder copyWith({BorderSide? borderSide}) =>
      MiuixSquircleInputBorder(
        cornerRadius: cornerRadius,
        extension: extension,
        enabled: enabled,
        borderSide: borderSide ?? this.borderSide,
      );

  @override
  MiuixSquircleInputBorder scale(double t) => MiuixSquircleInputBorder(
    cornerRadius: cornerRadius * t,
    extension: extension,
    enabled: enabled,
    borderSide: borderSide.scale(t),
  );

  @override
  bool operator ==(Object other) =>
      other is MiuixSquircleInputBorder &&
      other.cornerRadius == cornerRadius &&
      other.extension == extension &&
      other.enabled == enabled &&
      other.borderSide == borderSide;

  @override
  int get hashCode => Object.hash(cornerRadius, extension, enabled, borderSide);
}

import 'dart:math' as math;

class VideoPaneGeometry {
  const VideoPaneGeometry({
    required this.width,
    required this.height,
    required this.automaticWidth,
    required this.minRightWidth,
    this.minIntroHeight = 120,
  });

  static const dividerWidth = 10.0;
  static const minLeftWidth = 500.0;
  static const aspectRatio = 16 / 9;

  final double width;
  final double height;
  final double automaticWidth;
  final double minRightWidth;
  final double minIntroHeight;

  double get contentWidth => width - dividerWidth;
  double get maxLeftWidth => math.min(
    contentWidth - minRightWidth,
    (height - minIntroHeight) * aspectRatio,
  );
  bool get canResize => width.isFinite && height.isFinite &&
      maxLeftWidth > minLeftWidth + 1;
  double get minRatio => minLeftWidth / contentWidth;
  double get maxRatio => maxLeftWidth / contentWidth;
  double leftWidth(double? ratio) =>
      (ratio == null ? automaticWidth : contentWidth * ratio)
          .clamp(minLeftWidth, maxLeftWidth);
  double ratioForWidth(double width) =>
      (width / contentWidth).clamp(minRatio, maxRatio);

  bool sameBounds(VideoPaneGeometry other) =>
      width == other.width && height == other.height &&
      minRightWidth == other.minRightWidth &&
      minIntroHeight == other.minIntroHeight;
}

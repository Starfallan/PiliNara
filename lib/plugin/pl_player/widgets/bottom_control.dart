import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/view/view.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BottomControl extends StatelessWidget {
  const BottomControl({
    super.key,
    required this.maxWidth,
    required this.isFullScreen,
    required this.controller,
    required this.buildBottomControl,
    required this.videoDetailController,
    this.isPipMode = false,
  });

  final double maxWidth;
  final bool isFullScreen;
  final PlPlayerController controller;
  final ValueGetter<Widget> buildBottomControl;
  final VideoDetailController videoDetailController;
  final bool isPipMode;

  void onDragStart(ThumbDragDetails duration) {
    feedBack();
    controller
      ..onDesktopProgressDragStart(duration.timeStamp)
      ..onChangedSliderStart(duration.timeStamp);
  }

  void onDragUpdate(ThumbDragDetails duration) {
    controller
      ..updateDesktopProgressPreviewFromDrag(duration.timeStamp)
      ..onUpdatedSliderProgress(duration.timeStamp);
  }

  void onSeek(Duration duration) {
    controller
      ..onChangedSliderEnd()
      ..onChangedSlider(duration.inSeconds)
      ..seekTo(Duration(seconds: duration.inSeconds), isSeek: false);
  }

  void onHoverStart(ThumbDragDetails duration) {
    controller.onDesktopProgressHoverStart(duration.timeStamp);
  }

  void onHoverUpdate(ThumbDragDetails duration) {
    controller.onDesktopProgressHoverUpdate(duration.timeStamp);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final primary = colorScheme.isLight
        ? colorScheme.inversePrimary
        : colorScheme.primary;
    final thumbGlowColor = primary.withAlpha(80);
    final bufferedBarColor = primary.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
            child: Obx(
              () => Offstage(
                offstage: !controller.showControls.value,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Obx(() {
                      final int value = controller.sliderPositionSeconds.value;
                      final int max = controller.duration.value.inSeconds;
                      return ProgressBar(
                        progress: Duration(seconds: value),
                        buffered: Duration(
                          seconds: controller.bufferedSeconds.value,
                        ),
                        total: Duration(seconds: max),
                        progressBarColor: primary,
                        baseBarColor: const Color(0x33FFFFFF),
                        bufferedBarColor: bufferedBarColor,
                        thumbColor: primary,
                        thumbGlowColor: thumbGlowColor,
                        barHeight: 3.5,
                        thumbRadius: 7,
                        thumbGlowRadius: 25,
                        onDragStart: onDragStart,
                        onDragUpdate: onDragUpdate,
                        onSeek: onSeek,
                        onHoverStart: PlatformUtils.isDesktop
                            ? onHoverStart
                            : null,
                        onHoverUpdate: PlatformUtils.isDesktop
                            ? onHoverUpdate
                            : null,
                        onHoverEnd: PlatformUtils.isDesktop
                            ? controller.onDesktopProgressHoverEnd
                            : null,
                      );
                    }),
                    if (controller.enableBlock &&
                        videoDetailController.segmentProgressList.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 5.25,
                        child: SegmentProgressBar(
                          segments: videoDetailController.segmentProgressList,
                        ),
                      ),
                    if (!isPipMode &&
                        controller.showViewPoints &&
                        videoDetailController.viewPointList.isNotEmpty &&
                        !videoDetailController.showVP.value)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 5.25,
                        child: ViewPointDividerBar(
                          segments: videoDetailController.viewPointList,
                          progress: controller.duration.value.inSeconds > 0
                              ? controller.sliderPositionSeconds.value /
                                  controller.duration.value.inSeconds
                              : 0.0,
                        ),
                      ),
                    if (!isPipMode &&
                        controller.showViewPoints &&
                        videoDetailController.viewPointList.isNotEmpty &&
                        videoDetailController.showVP.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.75),
                        child: ViewPointSegmentProgressBar(
                          segments: videoDetailController.viewPointList,
                          onSeek: PlatformUtils.isDesktop
                              ? (position) =>
                                    controller.seekTo(position, isSeek: false)
                              : null,
                        ),
                      ),

                    if (!isPipMode && videoDetailController.showDmTrendChart.value)
                      if (videoDetailController.dmTrend.value?.dataOrNull
                          case final list?)
                        buildDmChart(primary, list, videoDetailController, 4.5),

                    if (PlatformUtils.isDesktop)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Obx(() {
                            final duration =
                                controller.duration.value.inMilliseconds;
                            final progress = duration > 0
                                ? controller.sliderPositionSeconds.value *
                                      1000 /
                                      duration
                                : 0.0;
                            final hoverValue =
                                controller.showDesktopProgressFeedback.value
                                ? controller.desktopProgressHoverValue.value
                                : null;
                            return CustomPaint(
                              painter: _DesktopProgressHoverPainter(
                                hoverValue: hoverValue,
                                progressValue: progress,
                                color: primary,
                                thumbGlowColor: thumbGlowColor,
                                isDragging: controller.isSliderMoving.value,
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          buildBottomControl(),
        ],
      ),
    );
  }
}

class _DesktopProgressHoverPainter extends CustomPainter {
  const _DesktopProgressHoverPainter({
    required this.hoverValue,
    required this.progressValue,
    required this.color,
    required this.thumbGlowColor,
    required this.isDragging,
  });

  static const double _barHeight = 3.5;
  static const double _thumbRadius = 7.0;
  static const double _thumbGlowRadius = 25.0;

  final double? hoverValue;
  final double progressValue;
  final Color color;
  final Color thumbGlowColor;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final value = hoverValue;
    if (value == null) {
      return;
    }

    const capRadius = _barHeight / 2;
    final availableWidth = size.width - _barHeight;
    final centerY = size.height - _thumbRadius;
    final hoverDx = value * availableWidth + capRadius;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const triangleHalfWidth = 6.0;
    const triangleHeight = 8.0;
    const gap = 4.0;

    canvas
      ..drawPath(
        Path()
          ..moveTo(
            hoverDx - triangleHalfWidth,
            centerY - gap - triangleHeight,
          )
          ..lineTo(
            hoverDx + triangleHalfWidth,
            centerY - gap - triangleHeight,
          )
          ..lineTo(hoverDx, centerY - gap)
          ..close(),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(
            hoverDx - triangleHalfWidth,
            centerY + gap + triangleHeight,
          )
          ..lineTo(
            hoverDx + triangleHalfWidth,
            centerY + gap + triangleHeight,
          )
          ..lineTo(hoverDx, centerY + gap)
          ..close(),
        paint,
      );

    final progressDx = progressValue.clamp(0.0, 1.0).toDouble() *
            availableWidth +
        capRadius;
    final center = Offset(progressDx, centerY);
    if (isDragging) {
      canvas.drawCircle(
        center,
        _thumbGlowRadius,
        Paint()..color = thumbGlowColor,
      );
    }
    canvas.drawCircle(center, _thumbRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _DesktopProgressHoverPainter oldDelegate) {
    return oldDelegate.hoverValue != hoverValue ||
        oldDelegate.progressValue != progressValue ||
        oldDelegate.color != color ||
        oldDelegate.thumbGlowColor != thumbGlowColor ||
        oldDelegate.isDragging != isDragging;
  }
}

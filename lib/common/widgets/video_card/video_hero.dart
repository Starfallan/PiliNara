/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliPlus.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:math' as math;

import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show Listenable, ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;

/// Coordinates the thumbnail ↔ inline-player spatial transition.
///
/// The coordinator owns the transition constants and tag generation so card
/// widgets only register a source and the detail page only registers a
/// destination. A source tag contains both the video id and a unique mounted
/// source id; this is important when the same BVID appears more than once in a
/// list.
abstract final class VideoSpatialTransition {
  static const Duration duration = Duration(milliseconds: 650);

  /// The first four fifths are reserved for the two source containers. The
  /// remaining part lets the destination settle before secondary content
  /// appears.
  static const double secondaryStart = 0.80;
  static const double destinationSurfaceStart = 0.86;

  static final ValueNotifier<bool> enabledNotifier = ValueNotifier(
    Pref.enableVideoSharedElement,
  );

  static int _nextSourceId = 0;

  static bool get enabled => enabledNotifier.value;

  static void setEnabled(bool value) {
    if (enabledNotifier.value != value) {
      enabledNotifier.value = value;
    }
  }

  static int nextSourceId() => ++_nextSourceId;

  /// Returns the legacy-compatible tag used by detail pages without a card
  /// source (deep links, history, PiP, and similar entry points).
  static String? tagForVideo(Object? videoId, {int? sourceId}) {
    final value = videoId?.toString();
    if (value == null || value.isEmpty || value == 'null') {
      return null;
    }
    return sourceId == null
        ? 'video-hero-$value'
        : 'video-hero-$value-source-$sourceId';
  }

  /// Derive the information tag from the same source token as the media tag.
  /// This keeps the controller's `heroTag` separate from visual identity.
  static String? infoTagForMediaTag(String? mediaTag) {
    if (mediaTag == null || mediaTag.isEmpty) return null;
    return '$mediaTag-info';
  }

  static String? containerTagForMediaTag(String? mediaTag) {
    if (mediaTag == null || mediaTag.isEmpty) return null;
    return '$mediaTag-container';
  }

  static bool hasSourceTag(Object? arguments) => switch (arguments) {
    final Map arguments =>
      arguments['videoHeroTag'] is String &&
          (arguments['videoHeroTag'] as String).isNotEmpty,
    _ => false,
  };

  static double _clampProgress(double value) =>
      value.clamp(0.0, 1.0).toDouble();

  /// A single route-driven progress for all spatial containers.
  static double geometryProgress(double routeProgress) =>
      motionCurve.transform(_clampProgress(routeProgress));

  /// Progress reserved for related-video placeholders and separators.
  static double secondaryProgress(double routeProgress) {
    final value = _clampProgress(routeProgress);
    final normalized = ((value - secondaryStart) / (1 - secondaryStart))
        .clamp(0.0, 1.0)
        .toDouble();
    return Curves.easeOutCubic.transform(normalized);
  }

  /// Drives the destination container with the exact same geometry progress
  /// as the media and header anchors.
  static double destinationBackdropProgress(
    double routeProgress, {
    bool reversing = false,
  }) {
    if (!reversing) return geometryProgress(routeProgress);

    // On pop the route value runs from 1 → 0, while Hero's flight runs
    // from destination → source with a forward 0 → 1 progress. Convert
    // to that flight coordinate before applying the accepted curve unchanged,
    // then map back to the source → destination page-rectangle coordinate.
    return 1 - geometryProgress(1 - _clampProgress(routeProgress));
  }

  static double secondaryItemProgress(double routeProgress, int index) {
    final itemIndex = index.clamp(0, 5);
    final start = secondaryStart + itemIndex * 0.025;
    final end = math.min(1.0, start + 0.12);
    final normalized = ((_clampProgress(routeProgress) - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return Curves.easeOutCubic.transform(normalized);
  }

  static double _secondaryOpacity(double routeProgress) {
    // The route controller itself runs from 1 → 0 on pop. Re-inverting it
    // here kept secondary content opaque until the final part of the return,
    // producing the recorded hard page replacement. Reuse the same timing
    // window in both directions so reverse naturally dismisses it first.
    return secondaryProgress(routeProgress);
  }

  /// The emphasized curve is intentionally bounded at the destination. The
  /// tiny settle term changes the final velocity without exposing a player
  /// edge past its target rectangle.
  static const Curve motionCurve = _VideoSpatialCurve();

  static Widget routeTransition({
    required PageRoute<dynamic> route,
    required Animation<double> animation,
    required Widget child,
    bool hasSource = true,
  }) {
    // Do not fade or translate the complete route. The route remains a normal
    // Navigator route; only its media, info, and secondary layers opt into the
    // spatial choreography below.
    return VideoSpatialRouteScope(
      route: route,
      animation: animation,
      hasSource: hasSource,
      child: child,
    );
  }

  /// Keeps the destination page fully laid out while clipping its paint to a
  /// rounded rectangle that grows from the complete source card to the full
  /// page. Media and header Heroes remain separate paint owners, but all
  /// three containers share [geometryProgress].
  static Widget pageSurface({
    required Widget child,
    required Color color,
  }) {
    return Builder(
      builder: (context) {
        final scope = VideoSpatialRouteScope.maybeOf(context);
        if (scope == null || !scope.hasSource) return child;
        return AnimatedBuilder(
          animation: scope.animation,
          child: child,
          builder: (context, child) {
            final isReversing =
                scope.animation.status == AnimationStatus.reverse ||
                scope.route.popGestureInProgress;
            final progress = destinationBackdropProgress(
              scope.animation.value,
              reversing: isReversing,
            );
            final mediaTag = switch (scope.route.settings.arguments) {
              final Map arguments when arguments['videoHeroTag'] is String =>
                arguments['videoHeroTag'] as String,
              _ => null,
            };
            final sourceBounds = VideoSpatialTransitionRegistry.lookup(
              containerTagForMediaTag(mediaTag),
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                final destinationRect = Offset.zero & constraints.biggest;
                final sourceRect = sourceBounds?.isUsable == true
                    ? sourceBounds!.rect
                    : destinationRect;
                final rect = Rect.lerp(sourceRect, destinationRect, progress)!;
                final radius = BorderRadius.lerp(
                  const BorderRadius.all(Radius.circular(12)),
                  BorderRadius.zero,
                  progress,
                )!;
                final clipper = _VideoSpatialPageClipper(rect, radius);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: ClipRRect(
                        clipper: clipper,
                        child: ColoredBox(color: color),
                      ),
                    ),
                    ClipRRect(clipper: clipper, child: child),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Small fixed surfaces such as the status-bar chrome are not part of the
  /// Hero overlay, so reveal them with the destination background plane.
  static Widget primaryChrome({required Widget child}) {
    return Builder(
      builder: (context) {
        final scope = VideoSpatialRouteScope.maybeOf(context);
        if (scope == null || !scope.hasSource) return child;
        return AnimatedBuilder(
          animation: scope.animation,
          child: child,
          builder: (context, child) {
            final opacity = destinationBackdropProgress(
              scope.animation.value,
            );
            return IgnorePointer(
              ignoring: opacity < 0.96,
              child: Opacity(opacity: opacity, child: child),
            );
          },
        );
      },
    );
  }

  /// Primary detail content used by metadata, tabs, and intro controls. It
  /// follows the same geometry progress as the card container and Heroes.
  static Widget chrome({
    required Widget child,
    double startDelay = 0.0,
    double slideDistance = 8.0,
  }) {
    return Builder(
      builder: (context) {
        final scope = VideoSpatialRouteScope.maybeOf(context);
        if (scope == null || !scope.hasSource) return child;

        return AnimatedBuilder(
          animation: scope.animation,
          child: child,
          builder: (context, child) {
            final isReversing =
                scope.animation.status == AnimationStatus.reverse ||
                scope.route.popGestureInProgress;
            final routeProgress = isReversing
                ? scope.animation.value + startDelay
                : scope.animation.value - startDelay;
            final opacity = geometryProgress(routeProgress);
            final translation = isReversing
                ? -slideDistance * 0.35 * (1 - opacity)
                : slideDistance * (1 - opacity);

            return IgnorePointer(
              ignoring: opacity < 0.96,
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, translation),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Related content remains mounted and can fetch early, while its pixels
  /// wait for the primary containers.
  static Widget secondarySliver({required Widget sliver}) {
    return Builder(
      builder: (context) {
        final scope = VideoSpatialRouteScope.maybeOf(context);
        if (scope == null || !scope.hasSource) return sliver;
        return AnimatedBuilder(
          animation: scope.animation,
          child: sliver,
          builder: (context, child) {
            final opacity = _secondaryOpacity(scope.animation.value);
            return SliverOpacity(
              opacity: opacity,
              sliver: SliverIgnorePointer(
                ignoring: opacity < 0.96,
                sliver: child,
              ),
            );
          },
        );
      },
    );
  }

  static Widget secondaryItem({
    required int index,
    required Widget child,
  }) {
    return Builder(
      builder: (context) {
        final scope = VideoSpatialRouteScope.maybeOf(context);
        if (scope == null || !scope.hasSource) return child;
        return AnimatedBuilder(
          animation: scope.animation,
          child: child,
          builder: (context, child) {
            final progress = secondaryItemProgress(
              scope.animation.value,
              index,
            );
            return IgnorePointer(
              ignoring: progress < 0.96,
              child: Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - progress)),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }

  static double destinationPosterOpacity(
    Animation<double> animation,
    VideoSpatialRouteScope scope,
  ) {
    final value = animation.value.clamp(0.0, 1.0).toDouble();
    final isReversing =
        animation.status == AnimationStatus.reverse ||
        scope.route.popGestureInProgress;
    if (isReversing) {
      final progress = (1 - value).clamp(0.0, 1.0).toDouble();
      return Curves.easeOutCubic.transform(
        (progress / 0.22).clamp(0.0, 1.0).toDouble(),
      );
    }

    final progress =
        ((value - destinationSurfaceStart) / (1 - destinationSurfaceStart))
            .clamp(0.0, 1.0)
            .toDouble();
    return 1 - Curves.easeOutCubic.transform(progress);
  }

  /// Keep the live destination mounted for layout and player initialisation,
  /// but do not paint it until the media Hero is almost home. Routes without
  /// a valid card source use the immediate fallback.
  static double destinationSurfaceOpacity({
    required double routeProgress,
    required bool reversing,
    required bool hasVisibleSource,
  }) {
    if (!hasVisibleSource) return 1;
    final value = _clampProgress(routeProgress);
    if (reversing) {
      // Hero's shuttle owns the only visible media representation for the
      // entire reverse flight. The live surface remains mounted and resumes
      // painting automatically if an interactive gesture is cancelled.
      return 0;
    }
    final reveal =
        ((value - destinationSurfaceStart) / (1 - destinationSurfaceStart))
            .clamp(0.0, 1.0)
            .toDouble();
    return Curves.easeOutCubic.transform(reveal);
  }

  static Widget destination({
    required String? tag,
    required Widget poster,
    required Widget child,
    ValueListenable<bool>? liveReadiness,
  }) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        VideoSpatialTransitionDestination(
          tag: tag,
          poster: poster,
          liveReadiness: liveReadiness,
          child: child,
        ),
        Positioned.fill(
          child: VideoHero(
            tag: tag,
            borderRadius: BorderRadius.zero,
            flightChild: poster,
            flightFit: BoxFit.contain,
            // The live player is intentionally outside the Hero. This
            // transparent anchor gives Hero the destination geometry without
            // rebuilding a platform video surface in the overlay.
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  static Widget destinationInfo({
    required String? tag,
    required Widget child,
  }) {
    return VideoHero(
      // Callers pass the already-derived info anchor. Deriving again here
      // produced `-info-info`, leaving the destination header unpaired and
      // visible underneath the media flight.
      tag: tag,
      scaleFlightChild: false,
      flightBackgroundColor: Colors.transparent,
      child: child,
    );
  }
}

/// A source registration that survives rebuilds of a keyed/list item element.
class VideoSpatialTransitionSource extends StatefulWidget {
  const VideoSpatialTransitionSource({
    super.key,
    required this.videoId,
    required this.builder,
  });

  final Object? videoId;
  final Widget Function(BuildContext, VideoSpatialTransitionHandle) builder;

  @override
  State<VideoSpatialTransitionSource> createState() =>
      _VideoSpatialTransitionSourceState();
}

class VideoSpatialTransitionHandle {
  VideoSpatialTransitionHandle._();

  String? _videoId;
  String? _tag;
  String? _infoTag;

  String? get tag => _tag;
  String? get infoTag => _infoTag;
  String? get videoId => _videoId;

  Widget wrap(
    Widget child, {
    BorderRadius borderRadius = BorderRadius.zero,
    Widget? flightChild,
    BoxFit flightFit = BoxFit.cover,
    Alignment flightAlignment = Alignment.center,
  }) {
    return _VideoSpatialBoundsReporter(
      tag: _tag,
      videoId: _videoId,
      child: VideoHero(
        tag: _tag,
        borderRadius: borderRadius,
        flightChild: flightChild ?? child,
        flightFit: flightFit,
        flightAlignment: flightAlignment,
        child: child,
      ),
    );
  }

  /// Wrap only the card's info column so its surrounding Expanded/Flex
  /// ParentData stays attached to the Row/Column that owns it.
  Widget wrapInfo(Widget child, {Widget? flightChild}) {
    return _VideoSpatialBoundsReporter(
      tag: _infoTag,
      videoId: _videoId,
      child: VideoHero(
        tag: _infoTag,
        borderRadius: BorderRadius.zero,
        flightChild: flightChild ?? child,
        scaleFlightChild: false,
        flightBackgroundColor: Colors.transparent,
        child: child,
      ),
    );
  }
}

class _VideoSpatialTransitionSourceState
    extends State<VideoSpatialTransitionSource> {
  final _handle = VideoSpatialTransitionHandle._();
  late int _sourceId;

  @override
  void initState() {
    super.initState();
    _sourceId = VideoSpatialTransition.nextSourceId();
    _updateVideoId(widget.videoId);
  }

  @override
  void didUpdateWidget(VideoSpatialTransitionSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _sourceId = VideoSpatialTransition.nextSourceId();
      _updateVideoId(widget.videoId);
    }
  }

  void _updateVideoId(Object? videoId) {
    VideoSpatialTransitionRegistry.remove(_handle.tag);
    VideoSpatialTransitionRegistry.remove(_handle.infoTag);
    VideoSpatialTransitionRegistry.remove(
      VideoSpatialTransition.containerTagForMediaTag(_handle.tag),
    );
    _handle
      .._videoId = videoId?.toString()
      .._tag = VideoSpatialTransition.tagForVideo(videoId, sourceId: _sourceId)
      .._infoTag = VideoSpatialTransition.infoTagForMediaTag(_handle._tag);
  }

  @override
  void dispose() {
    VideoSpatialTransitionRegistry.remove(_handle.tag);
    VideoSpatialTransitionRegistry.remove(_handle.infoTag);
    VideoSpatialTransitionRegistry.remove(
      VideoSpatialTransition.containerTagForMediaTag(_handle.tag),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _VideoSpatialBoundsReporter(
      tag: VideoSpatialTransition.containerTagForMediaTag(_handle.tag),
      videoId: _handle.videoId,
      child: widget.builder(context, _handle),
    );
  }
}

/// The destination side keeps a poster over the live texture until the route
/// is almost settled. The readiness listenable is consumed here instead of
/// rebuilding the destination Hero, which keeps the flight pair stable while
/// media_kit creates or recreates its platform texture.
class VideoSpatialTransitionDestination extends StatefulWidget {
  const VideoSpatialTransitionDestination({
    super.key,
    required this.tag,
    required this.poster,
    required this.child,
    this.liveReadiness,
  });

  final String? tag;
  final Widget poster;
  final Widget child;
  final ValueListenable<bool>? liveReadiness;

  @override
  State<VideoSpatialTransitionDestination> createState() =>
      _VideoSpatialTransitionDestinationState();
}

class _VideoSpatialTransitionDestinationState
    extends State<VideoSpatialTransitionDestination>
    with SingleTickerProviderStateMixin {
  late final AnimationController _posterHandoffController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: _isLiveReady ? 1.0 : 0.0,
  );

  bool get _isLiveReady => widget.liveReadiness?.value ?? true;

  @override
  void initState() {
    super.initState();
    widget.liveReadiness?.addListener(_onLiveReadinessChanged);
  }

  @override
  void didUpdateWidget(VideoSpatialTransitionDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveReadiness != widget.liveReadiness) {
      oldWidget.liveReadiness?.removeListener(_onLiveReadinessChanged);
      widget.liveReadiness?.addListener(_onLiveReadinessChanged);
      _posterHandoffController.value = _isLiveReady ? 1.0 : 0.0;
    }
  }

  void _onLiveReadinessChanged() {
    if (!mounted) return;
    if (_isLiveReady) {
      _posterHandoffController.forward();
    } else {
      _posterHandoffController.reverse();
    }
  }

  @override
  void dispose() {
    widget.liveReadiness?.removeListener(_onLiveReadinessChanged);
    _posterHandoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = VideoSpatialRouteScope.maybeOf(context);
    if (scope == null) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: _fitPoster(widget.poster)),
          widget.child,
        ],
      );
    }

    final animation = widget.liveReadiness == null
        ? scope.animation
        : Listenable.merge(<Listenable>[
            scope.animation,
            widget.liveReadiness!,
            _posterHandoffController,
          ]);
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) {
        final isReversing =
            scope.animation.status == AnimationStatus.reverse ||
            scope.route.popGestureInProgress;
        final sourceBounds = VideoSpatialTransitionRegistry.lookup(widget.tag);
        final hasVisibleSource = sourceBounds?.isUsable == true;
        final routePosterOpacity = hasVisibleSource
            ? VideoSpatialTransition.destinationPosterOpacity(
                scope.animation,
                scope,
              )
            : 0.0;
        final fallbackProgress = isReversing && !hasVisibleSource
            ? (1 - scope.animation.value).clamp(0.0, 1.0).toDouble()
            : 0.0;
        // If the backend has not exposed a drawable frame, keep the poster
        // fully opaque. The live child remains mounted underneath it, so the
        // player can finish initialising without ever flashing a black
        // texture. Once readiness changes, this same frame becomes a normal
        // poster handoff. The player surface itself is never faded or
        // transformed by this coordinator.
        final posterHandoff = _posterHandoffController.value;
        final handoffPosterOpacity =
            routePosterOpacity + (1 - routePosterOpacity) * (1 - posterHandoff);

        final surfaceOpacity = VideoSpatialTransition.destinationSurfaceOpacity(
          routeProgress: scope.animation.value,
          reversing: isReversing,
          hasVisibleSource: hasVisibleSource,
        );
        Widget content = IgnorePointer(
          ignoring: surfaceOpacity < 0.96,
          child: Opacity(
            opacity: surfaceOpacity,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                child!,
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: handoffPosterOpacity,
                      child: _fitPoster(widget.poster),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (fallbackProgress > 0) {
          content = Transform.scale(
            alignment: Alignment.center,
            scale: 1 - 0.04 * Curves.easeOutCubic.transform(fallbackProgress),
            child: content,
          );
        }
        return content;
      },
    );
  }
}

/// Route-level state shared by the destination crossfade and chrome layers.
/// It is deliberately an inherited value rather than a
/// controller owned by the video page, so custom routes and iOS gestures can
/// drive it from the Navigator's real animation.
class VideoSpatialRouteScope extends InheritedWidget {
  const VideoSpatialRouteScope({
    super.key,
    required this.route,
    required this.animation,
    this.hasSource = true,
    required super.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final bool hasSource;

  static VideoSpatialRouteScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VideoSpatialRouteScope>();

  @override
  bool updateShouldNotify(VideoSpatialRouteScope oldWidget) =>
      route != oldWidget.route || animation != oldWidget.animation;
}

/// Latest source geometry is advisory only. Hero remains the authority for a
/// real flight; stale or unavailable entries are never fed back into Hero.
class VideoSpatialSourceBounds {
  const VideoSpatialSourceBounds({
    required this.tag,
    required this.videoId,
    required this.rect,
    required this.visible,
    this.paintedAt = Duration.zero,
  });

  final String tag;
  final String? videoId;
  final Rect rect;
  final bool visible;
  final Duration paintedAt;

  bool get isUsable =>
      visible &&
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.width.isFinite &&
      rect.height.isFinite &&
      rect.width > 0 &&
      rect.height > 0;

  bool isFresh({Duration maxAge = const Duration(milliseconds: 120)}) {
    if (!isUsable) return false;
    final now = _currentFrameTimeStampOrZero();
    return now >= paintedAt && now - paintedAt <= maxAge;
  }

  VideoSpatialSourceBounds copyWith({bool? visible}) =>
      VideoSpatialSourceBounds(
        tag: tag,
        videoId: videoId,
        rect: rect,
        visible: visible ?? this.visible,
        paintedAt: paintedAt,
      );
}

abstract final class VideoSpatialTransitionRegistry {
  static final Map<String, VideoSpatialSourceBounds> _sources = {};

  static VideoSpatialSourceBounds? lookup(String? tag) {
    if (tag == null) return null;
    return _sources[tag];
  }

  static void update({
    required String tag,
    required String? videoId,
    required Rect rect,
    bool visible = true,
    Duration? paintedAt,
  }) {
    _sources[tag] = VideoSpatialSourceBounds(
      tag: tag,
      videoId: videoId,
      rect: rect,
      visible: visible,
      paintedAt: paintedAt ?? _currentFrameTimeStampOrZero(),
    );
  }

  static void markUnavailable(String tag) {
    final source = _sources[tag];
    if (source != null) {
      _sources[tag] = source.copyWith(visible: false);
    }
  }

  static void remove(String? tag) {
    if (tag != null) {
      _sources.remove(tag);
    }
  }
}

Duration _currentFrameTimeStampOrZero() {
  final scheduler = SchedulerBinding.instance;
  return scheduler.schedulerPhase == SchedulerPhase.idle
      ? Duration.zero
      : scheduler.currentFrameTimeStamp;
}

class _VideoSpatialBoundsReporter extends SingleChildRenderObjectWidget {
  const _VideoSpatialBoundsReporter({
    required this.tag,
    required this.videoId,
    required super.child,
  });

  final String? tag;
  final String? videoId;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _VideoSpatialBoundsRenderObject(tag: tag, videoId: videoId);

  @override
  void updateRenderObject(
    BuildContext context,
    _VideoSpatialBoundsRenderObject renderObject,
  ) {
    if (renderObject.tag != tag) {
      VideoSpatialTransitionRegistry.remove(renderObject.tag);
    }
    renderObject
      ..tag = tag
      ..videoId = videoId;
  }
}

class _VideoSpatialBoundsRenderObject extends RenderProxyBox {
  _VideoSpatialBoundsRenderObject({this.tag, this.videoId});

  String? tag;
  String? videoId;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (tag case final tag?) {
      // `paint` is called for partially clipped children too. Use the actual
      // canvas clip in addition to attachment/size so an off-screen recycled
      // card cannot become the pop target merely because its last paint rect
      // is still in the registry.
      final visible =
          attached &&
          hasSize &&
          !size.isEmpty &&
          context.canvas.getLocalClipBounds().overlaps(offset & size);
      if (visible) {
        VideoSpatialTransitionRegistry.update(
          tag: tag,
          videoId: videoId,
          rect: localToGlobal(Offset.zero) & size,
        );
      } else {
        VideoSpatialTransitionRegistry.markUnavailable(tag);
      }
    }
  }

  @override
  void detach() {
    if (tag case final tag?) {
      VideoSpatialTransitionRegistry.markUnavailable(tag);
    }
    super.detach();
  }
}

class VideoHero extends StatelessWidget {
  static void setEnabled(bool value) {
    VideoSpatialTransition.setEnabled(value);
  }

  const VideoHero({
    super.key,
    required this.tag,
    required this.child,
    this.enabled,
    this.flightChild,
    this.borderRadius = BorderRadius.zero,
    this.flightFit = BoxFit.cover,
    this.flightAlignment = Alignment.center,
    this.scaleFlightChild = true,
    this.flightBackgroundColor = Colors.black,
  });

  final String? tag;
  final Widget child;
  final bool? enabled;
  final Widget? flightChild;
  final BorderRadius borderRadius;
  final BoxFit flightFit;
  final Alignment flightAlignment;
  final bool scaleFlightChild;
  final Color flightBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final heroChild = _VideoHeroChild(
      flightChild: flightChild ?? child,
      borderRadius: borderRadius,
      flightFit: flightFit,
      flightAlignment: flightAlignment,
      scaleFlightChild: scaleFlightChild,
      flightBackgroundColor: flightBackgroundColor,
      child: ClipRRect(
        clipBehavior: Clip.antiAlias,
        borderRadius: borderRadius,
        child: child,
      ),
    );
    final heroTag = tag;
    if (heroTag == null) {
      return heroChild;
    }

    if (enabled case final enabled?) {
      return enabled ? _buildHero(heroTag, heroChild) : heroChild;
    }

    return ValueListenableBuilder<bool>(
      valueListenable: VideoSpatialTransition.enabledNotifier,
      child: heroChild,
      builder: (context, enabled, child) {
        return enabled
            ? _buildHero(heroTag, child! as _VideoHeroChild)
            : child!;
      },
    );
  }

  Widget _buildHero(String heroTag, _VideoHeroChild child) {
    return Hero(
      tag: heroTag,
      transitionOnUserGestures: true,
      // Keep the Hero's progress linear so the coordinator owns the single
      // emphasized geometry curve and interactive back gestures track the
      // route controller without being eased twice.
      curve: Curves.linear,
      reverseCurve: Curves.linear,
      createRectTween: (begin, end) => _VideoRectTween(begin: begin, end: end),
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            final fromHero = fromHeroContext.widget as Hero;
            final toHero = toHeroContext.widget as Hero;
            final fromChild = fromHero.child is _VideoHeroChild
                ? fromHero.child as _VideoHeroChild
                : null;
            final toChild = toHero.child is _VideoHeroChild
                ? toHero.child as _VideoHeroChild
                : null;

            final presentation = flightDirection == HeroFlightDirection.pop
                ? toChild
                : fromChild;
            final presentationChild = flightDirection == HeroFlightDirection.pop
                ? toChild?.flightChild ?? toHero.child
                : fromChild?.flightChild ?? fromHero.child;

            return _VideoSpatialFlightShuttle(
              animation: animation,
              poster: presentationChild,
              fromHeader: fromChild?.scaleFlightChild == false
                  ? fromChild?.flightChild
                  : null,
              toHeader: toChild?.scaleFlightChild == false
                  ? toChild?.flightChild
                  : null,
              flightDirection: flightDirection,
              beginRadius: fromChild?.borderRadius ?? BorderRadius.zero,
              endRadius: toChild?.borderRadius ?? BorderRadius.zero,
              flightFit: presentation?.flightFit ?? BoxFit.cover,
              flightAlignment:
                  presentation?.flightAlignment ?? Alignment.center,
              scaleFlightChild: presentation?.scaleFlightChild ?? true,
              flightBackgroundColor:
                  presentation?.flightBackgroundColor ?? Colors.black,
            );
          },
      child: child,
    );
  }
}

class _VideoHeroChild extends StatelessWidget {
  const _VideoHeroChild({
    required this.child,
    required this.flightChild,
    required this.borderRadius,
    required this.flightFit,
    required this.flightAlignment,
    required this.scaleFlightChild,
    required this.flightBackgroundColor,
  });

  final Widget child;
  final Widget flightChild;
  final BorderRadius borderRadius;
  final BoxFit flightFit;
  final Alignment flightAlignment;
  final bool scaleFlightChild;
  final Color flightBackgroundColor;

  @override
  Widget build(BuildContext context) => child;
}

class _VideoSpatialFlightShuttle extends StatelessWidget {
  const _VideoSpatialFlightShuttle({
    required this.animation,
    required this.poster,
    required this.fromHeader,
    required this.toHeader,
    required this.flightDirection,
    required this.beginRadius,
    required this.endRadius,
    required this.flightFit,
    required this.flightAlignment,
    required this.scaleFlightChild,
    required this.flightBackgroundColor,
  });

  final Animation<double> animation;
  final Widget poster;
  final Widget? fromHeader;
  final Widget? toHeader;
  final HeroFlightDirection flightDirection;
  final BorderRadius beginRadius;
  final BorderRadius endRadius;
  final BoxFit flightFit;
  final Alignment flightAlignment;
  final bool scaleFlightChild;
  final Color flightBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: poster,
      builder: (context, child) {
        final rawProgress = animation.value.clamp(0.0, 1.0).toDouble();
        final progress = VideoSpatialTransition.motionCurve.transform(
          rawProgress,
        );

        final flightProgress = flightDirection == HeroFlightDirection.push
            ? rawProgress
            : 1 - rawProgress;
        final headerHandoff = Curves.easeInOutCubic.transform(
          ((flightProgress - 0.42) / 0.36).clamp(0.0, 1.0).toDouble(),
        );
        final fromHeader = this.fromHeader;
        final toHeader = this.toHeader;
        final flightContent = !scaleFlightChild &&
                fromHeader != null &&
                toHeader != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 1 - headerHandoff,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: fromHeader,
                    ),
                  ),
                  Opacity(
                    opacity: headerHandoff,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: toHeader,
                    ),
                  ),
                ],
              )
            : Align(alignment: flightAlignment, child: child);

        return ClipRRect(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.lerp(beginRadius, endRadius, progress)!,
          child: scaleFlightChild
              ? ColoredBox(
                  color: flightBackgroundColor,
                  child: _fitPoster(
                    child!,
                    fit: flightFit,
                    alignment: flightAlignment,
                  ),
                )
              : flightContent,
        );
      },
    );
  }
}

Widget _fitPoster(
  Widget child, {
  BoxFit fit = BoxFit.fill,
  Alignment alignment = Alignment.center,
}) {
  return SizedBox.expand(
    child: FittedBox(fit: fit, alignment: alignment, child: child),
  );
}

class _VideoRectTween extends RectTween {
  _VideoRectTween({required super.begin, required super.end});

  @override
  Rect? lerp(double t) =>
      super.lerp(VideoSpatialTransition.motionCurve.transform(t));
}

class _VideoSpatialCurve extends Curve {
  const _VideoSpatialCurve();

  static const Curve _emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  @override
  double transformInternal(double t) {
    final progress = t.clamp(0.0, 1.0).toDouble();
    final base = _emphasized.transform(progress);
    if (progress <= 0.78 || progress >= 1.0) {
      return base;
    }

    final settleProgress = ((progress - 0.78) / 0.22).clamp(0.0, 1.0);
    final settle = math.sin(
      math.pi * Curves.easeInOut.transform(settleProgress),
    );
    return math.min(1.0, base + 0.012 * settle * settle);
  }
}

class _VideoSpatialPageClipper extends CustomClipper<RRect> {
  const _VideoSpatialPageClipper(this.rect, this.borderRadius);

  final Rect rect;
  final BorderRadius borderRadius;

  @override
  RRect getClip(Size size) => borderRadius.toRRect(rect);

  @override
  bool shouldReclip(_VideoSpatialPageClipper oldClipper) =>
      rect != oldClipper.rect || borderRadius != oldClipper.borderRadius;
}

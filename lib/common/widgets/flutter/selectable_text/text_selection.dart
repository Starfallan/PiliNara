// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/flutter/selectable_text/tap_and_drag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    hide
        BaseTapAndDragGestureRecognizer,
        TapAndHorizontalDragGestureRecognizer,
        TapAndPanGestureRecognizer;
import 'package:flutter/material.dart' hide TextSelectionGestureDetector;

class CustomTextSelectionGestureDetectorBuilder
    extends TextSelectionGestureDetectorBuilder {
  CustomTextSelectionGestureDetectorBuilder({required super.delegate});

  @override
  Widget buildGestureDetector({
    Key? key,
    HitTestBehavior? behavior,
    required Widget child,
  }) {
    return TextSelectionGestureDetector(
      key: key,
      onTapTrackStart: onTapTrackStart,
      onTapTrackReset: onTapTrackReset,
      onTapDown: onTapDown,
      onForcePressStart: delegate.forcePressEnabled ? onForcePressStart : null,
      onForcePressEnd: delegate.forcePressEnabled ? onForcePressEnd : null,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapDown: onSecondaryTapDown,
      onSingleTapUp: onSingleTapUp,
      onSingleTapCancel: onSingleTapCancel,
      onUserTap: onUserTap,
      onSingleLongTapStart: onSingleLongTapStart,
      onSingleLongTapMoveUpdate: onSingleLongTapMoveUpdate,
      onSingleLongTapEnd: onSingleLongTapEnd,
      onSingleLongTapCancel: onSingleLongTapCancel,
      onDoubleTapDown: onDoubleTapDown,
      onTripleTapDown: onTripleTapDown,
      onDragSelectionStart: onDragSelectionStart,
      onDragSelectionUpdate: onDragSelectionUpdate,
      onDragSelectionEnd: onDragSelectionEnd,
      onUserTapAlwaysCalled: onUserTapAlwaysCalled,
      behavior: behavior,
      child: child,
    );
  }
}

/// A gesture detector to respond to non-exclusive event chains for a text field.
///
/// An ordinary [GestureDetector] configured to handle events like tap and
/// double tap will only recognize one or the other. This widget detects both:
/// the first tap and then any subsequent taps that occurs within a time limit
/// after the first.
///
/// See also:
///
///  * [TextField], a Material text field which uses this gesture detector.
///  * [CupertinoTextField], a Cupertino text field which uses this gesture
///    detector.
class TextSelectionGestureDetector extends StatefulWidget {
  /// Create a [TextSelectionGestureDetector].
  ///
  /// Multiple callbacks can be called for one sequence of input gesture.
  const TextSelectionGestureDetector({
    super.key,
    this.onTapTrackStart,
    this.onTapTrackReset,
    this.onTapDown,
    this.onForcePressStart,
    this.onForcePressEnd,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.onSingleTapUp,
    this.onSingleTapCancel,
    this.onUserTap,
    this.onSingleLongTapStart,
    this.onSingleLongTapMoveUpdate,
    this.onSingleLongTapEnd,
    this.onSingleLongTapCancel,
    this.onDoubleTapDown,
    this.onTripleTapDown,
    this.onDragSelectionStart,
    this.onDragSelectionUpdate,
    this.onDragSelectionEnd,
    this.onUserTapAlwaysCalled = false,
    this.behavior,
    required this.child,
  });

  /// {@template flutter.gestures.selectionrecognizers.TextSelectionGestureDetector.onTapTrackStart}
  /// Callback used to indicate that a tap tracking has started upon
  /// a [PointerDownEvent].
  /// {@endtemplate}
  final VoidCallback? onTapTrackStart;

  /// {@template flutter.gestures.selectionrecognizers.TextSelectionGestureDetector.onTapTrackReset}
  /// Callback used to indicate that a tap tracking has been reset which
  /// happens on the next [PointerDownEvent] after the timer between two taps
  /// elapses, the recognizer loses the arena, the gesture is cancelled or
  /// the recognizer is disposed of.
  /// {@endtemplate}
  final VoidCallback? onTapTrackReset;

  /// Called for every tap down including every tap down that's part of a
  /// double click or a long press, except touches that include enough movement
  /// to not qualify as taps (e.g. pans and flings).
  final GestureTapDragDownCallback? onTapDown;

  /// Called when a pointer has tapped down and the force of the pointer has
  /// just become greater than [ForcePressGestureRecognizer.startPressure].
  final GestureForcePressStartCallback? onForcePressStart;

  /// Called when a pointer that had previously triggered [onForcePressStart] is
  /// lifted off the screen.
  final GestureForcePressEndCallback? onForcePressEnd;

  /// Called for a tap event with the secondary mouse button.
  final GestureTapCallback? onSecondaryTap;

  /// Called for a tap down event with the secondary mouse button.
  final GestureTapDownCallback? onSecondaryTapDown;

  /// Called for the first tap in a series of taps, consecutive taps do not call
  /// this method.
  ///
  /// For example, if the detector was configured with [onTapDown] and
  /// [onDoubleTapDown], three quick taps would be recognized as a single tap
  /// down, followed by a tap up, then a double tap down, followed by a single tap down.
  final GestureTapDragUpCallback? onSingleTapUp;

  /// Called for each touch that becomes recognized as a gesture that is not a
  /// short tap, such as a long tap or drag. It is called at the moment when
  /// another gesture from the touch is recognized.
  final GestureCancelCallback? onSingleTapCancel;

  /// Called for the first tap in a series of taps when [onUserTapAlwaysCalled] is
  /// disabled, which is the default behavior.
  ///
  /// When [onUserTapAlwaysCalled] is enabled, this is called for every tap,
  /// including consecutive taps.
  final GestureTapCallback? onUserTap;

  /// Called for a single long tap that's sustained for longer than
  /// [kLongPressTimeout] but not necessarily lifted. Not called for a
  /// double-tap-hold, which calls [onDoubleTapDown] instead.
  final GestureLongPressStartCallback? onSingleLongTapStart;

  /// Called after [onSingleLongTapStart] when the pointer is dragged.
  final GestureLongPressMoveUpdateCallback? onSingleLongTapMoveUpdate;

  /// Called after [onSingleLongTapStart] when the pointer is lifted.
  final GestureLongPressEndCallback? onSingleLongTapEnd;

  /// Called after [onSingleLongTapStart] when the pointer is canceled.
  final GestureLongPressCancelCallback? onSingleLongTapCancel;

  /// Called after a momentary hold or a short tap that is close in space and
  /// time (within [kDoubleTapTimeout]) to a previous short tap.
  final GestureTapDragDownCallback? onDoubleTapDown;

  /// Called after a momentary hold or a short tap that is close in space and
  /// time (within [kDoubleTapTimeout]) to a previous double-tap.
  final GestureTapDragDownCallback? onTripleTapDown;

  /// Called when a mouse starts dragging to select text.
  final GestureTapDragStartCallback? onDragSelectionStart;

  /// Called repeatedly as a mouse moves while dragging.
  final GestureTapDragUpdateCallback? onDragSelectionUpdate;

  /// Called when a mouse that was previously dragging is released.
  final GestureTapDragEndCallback? onDragSelectionEnd;

  /// Whether [onUserTap] will be called for all taps including consecutive taps.
  ///
  /// Defaults to false, so [onUserTap] is only called for each distinct tap.
  final bool onUserTapAlwaysCalled;

  /// How this gesture detector should behave during hit testing.
  ///
  /// This defaults to [HitTestBehavior.deferToChild].
  final HitTestBehavior? behavior;

  /// Child below this widget.
  final Widget child;

  @override
  State<StatefulWidget> createState() => _TextSelectionGestureDetectorState();
}

class _TextSelectionGestureDetectorState
    extends State<TextSelectionGestureDetector> {
  // Converts the details.consecutiveTapCount from a TapAndDrag*Details object,
  // which can grow to be infinitely large, to a value between 1 and 3. The value
  // that the raw count is converted to is based on the default observed behavior
  // on the native platforms.
  //
  // This method should be used in all instances when details.consecutiveTapCount
  // would be used.
  static int _getEffectiveConsecutiveTapCount(int rawCount) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        // From observation, these platform's reset their tap count to 0 when
        // the number of consecutive taps exceeds 3. For example on Debian Linux
        // with GTK, when going past a triple click, on the fourth click the
        // selection is moved to the precise click position, on the fifth click
        // the word at the position is selected, and on the sixth click the
        // paragraph at the position is selected.
        return rawCount <= 3
            ? rawCount
            : (rawCount % 3 == 0 ? 3 : rawCount % 3);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // From observation, these platform's either hold their tap count at 3.
        // For example on macOS, when going past a triple click, the selection
        // should be retained at the paragraph that was first selected on triple
        // click.
        return math.min(rawCount, 3);
      case TargetPlatform.windows:
        // From observation, this platform's consecutive tap actions alternate
        // between double click and triple click actions. For example, after a
        // triple click has selected a paragraph, on the next click the word at
        // the clicked position will be selected, and on the next click the
        // paragraph at the position is selected.
        return rawCount < 2 ? rawCount : 2 + rawCount % 2;
    }
  }

  void _handleTapTrackStart() {
    widget.onTapTrackStart?.call();
  }

  void _handleTapTrackReset() {
    widget.onTapTrackReset?.call();
  }

  // The down handler is force-run on success of a single tap and optimistically
  // run before a long press success.
  void _handleTapDown(TapDragDownDetails details) {
    widget.onTapDown?.call(details);
    // This isn't detected as a double tap gesture in the gesture recognizer
    // because it's 2 single taps, each of which may do different things depending
    // on whether it's a single tap, the first tap of a double tap, the second
    // tap held down, a clean double tap etc.
    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 2) {
      return widget.onDoubleTapDown?.call(details);
    }

    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 3) {
      return widget.onTripleTapDown?.call(details);
    }
  }

  void _handleTapUp(TapDragUpDetails details) {
    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 1) {
      widget.onSingleTapUp?.call(details);
      widget.onUserTap?.call();
    } else if (widget.onUserTapAlwaysCalled) {
      widget.onUserTap?.call();
    }
  }

  void _handleTapCancel() {
    widget.onSingleTapCancel?.call();
  }

  void _handleDragStart(TapDragStartDetails details) {
    widget.onDragSelectionStart?.call(details);
  }

  void _handleDragUpdate(TapDragUpdateDetails details) {
    widget.onDragSelectionUpdate?.call(details);
  }

  void _handleDragEnd(TapDragEndDetails details) {
    widget.onDragSelectionEnd?.call(details);
  }

  void _forcePressStarted(ForcePressDetails details) {
    widget.onForcePressStart?.call(details);
  }

  void _forcePressEnded(ForcePressDetails details) {
    widget.onForcePressEnd?.call(details);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    widget.onSingleLongTapStart?.call(details);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    widget.onSingleLongTapMoveUpdate?.call(details);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    widget.onSingleLongTapEnd?.call(details);
  }

  void _handleLongPressCancel() {
    widget.onSingleLongTapCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{};

    gestures[TapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(debugOwner: this),
          (TapGestureRecognizer instance) {
            instance
              ..onSecondaryTap = widget.onSecondaryTap
              ..onSecondaryTapDown = widget.onSecondaryTapDown;
          },
        );

    if (widget.onSingleLongTapStart != null ||
        widget.onSingleLongTapMoveUpdate != null ||
        widget.onSingleLongTapEnd != null ||
        widget.onSingleLongTapCancel != null) {
      gestures[LongPressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              debugOwner: this,
              supportedDevices: <PointerDeviceKind>{PointerDeviceKind.touch},
            ),
            (LongPressGestureRecognizer instance) {
              instance
                ..onLongPressStart = _handleLongPressStart
                ..onLongPressMoveUpdate = _handleLongPressMoveUpdate
                ..onLongPressEnd = _handleLongPressEnd
                ..onLongPressCancel = _handleLongPressCancel;
            },
          );
    }

    if (widget.onDragSelectionStart != null ||
        widget.onDragSelectionUpdate != null ||
        widget.onDragSelectionEnd != null) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.iOS:
          gestures[TapAndHorizontalDragGestureRecognizer] =
              GestureRecognizerFactoryWithHandlers<
                TapAndHorizontalDragGestureRecognizer
              >(
                () => TapAndHorizontalDragGestureRecognizer(debugOwner: this),
                (TapAndHorizontalDragGestureRecognizer instance) {
                  instance
                    // Text selection should start from the position of the first pointer
                    // down event.
                    ..dragStartBehavior = DragStartBehavior.down
                    ..eagerVictoryOnDrag =
                        defaultTargetPlatform != TargetPlatform.iOS
                    ..onTapTrackStart = _handleTapTrackStart
                    ..onTapTrackReset = _handleTapTrackReset
                    ..onTapDown = _handleTapDown
                    ..onDragStart = _handleDragStart
                    ..onDragUpdate = _handleDragUpdate
                    ..onDragEnd = _handleDragEnd
                    ..onTapUp = _handleTapUp
                    ..onCancel = _handleTapCancel;
                },
              );
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          gestures[TapAndPanGestureRecognizer] =
              GestureRecognizerFactoryWithHandlers<TapAndPanGestureRecognizer>(
                () => TapAndPanGestureRecognizer(debugOwner: this),
                (TapAndPanGestureRecognizer instance) {
                  instance
                    // Text selection should start from the position of the first pointer
                    // down event.
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onTapTrackStart = _handleTapTrackStart
                    ..onTapTrackReset = _handleTapTrackReset
                    ..onTapDown = _handleTapDown
                    ..onDragStart = _handleDragStart
                    ..onDragUpdate = _handleDragUpdate
                    ..onDragEnd = _handleDragEnd
                    ..onTapUp = _handleTapUp
                    ..onCancel = _handleTapCancel;
                },
              );
      }
    }

    if (widget.onForcePressStart != null || widget.onForcePressEnd != null) {
      gestures[ForcePressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<ForcePressGestureRecognizer>(
            () => ForcePressGestureRecognizer(debugOwner: this),
            (ForcePressGestureRecognizer instance) {
              instance
                ..onStart = widget.onForcePressStart != null
                    ? _forcePressStarted
                    : null
                ..onEnd = widget.onForcePressEnd != null
                    ? _forcePressEnded
                    : null;
            },
          );
    }

    return RawGestureDetector(
      gestures: gestures,
      excludeFromSemantics: true,
      behavior: widget.behavior,
      child: widget.child,
    );
  }
}

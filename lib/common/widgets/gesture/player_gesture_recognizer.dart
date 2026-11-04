import 'package:PiliPlus/common/widgets/gesture/device_kind_scale_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/gesture/player_gesture_diagnostics.dart';
import 'package:flutter/gestures.dart'
    show LongPressGestureRecognizer,
        RecognizerCallback, GestureRecognizer;

mixin PlayerGestureMixin on GestureRecognizer {
  bool isPosAllowed = true;

  @override
  T? invokeCallback<T>(
    String name,
    RecognizerCallback<T> callback, {
    String Function()? debugReport,
  }) {
    if (!isPosAllowed) return null;
    return super.invokeCallback(name, callback, debugReport: debugReport);
  }
}

class PlayerScaleGestureRecognizer extends DeviceKindScaleGestureRecognizer
    with PlayerGestureMixin, PlayerGestureTrace {
  PlayerScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    super.dragStartBehavior,
    super.trackpadScrollCausesScale,
    super.trackpadScrollToScaleFactor,
    PlayerGestureDiagnostics? diagnostics,
  }) {
    this.diagnostics = diagnostics;
  }
}

class PlayerLongPressGestureRecognizer extends LongPressGestureRecognizer
    with PlayerGestureTrace {
  PlayerLongPressGestureRecognizer({
    super.duration,
    PlayerGestureDiagnostics? diagnostics,
  }) {
    this.diagnostics = diagnostics;
  }
}

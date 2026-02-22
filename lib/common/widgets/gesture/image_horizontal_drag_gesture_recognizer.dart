import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/gesture/image_tap_gesture_recognizer.dart'
    show ImageGestureRecognizerMixin;
import 'package:flutter/gestures.dart';

typedef IsBoundaryAllowed =
    bool Function(Offset? initialPosition, OffsetPair lastPosition);

class ImageHorizontalDragGestureRecognizer
    extends CustomHorizontalDragGestureRecognizer
    with ImageGestureRecognizerMixin {
  ImageHorizontalDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  IsBoundaryAllowed? isBoundaryAllowed;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    return super.hasSufficientGlobalDistanceToAccept(
          pointerDeviceKind,
          deviceTouchSlop,
        ) &&
        (isBoundaryAllowed?.call(initialPosition, lastPosition) ?? true);
  }

  @override
  void dispose() {
    isBoundaryAllowed = null;
    super.dispose();
  }
}

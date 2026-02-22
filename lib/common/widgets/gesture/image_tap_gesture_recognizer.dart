import 'package:flutter/gestures.dart'
    show
        GestureRecognizer,
        TapGestureRecognizer,
        DoubleTapGestureRecognizer,
        PointerDownEvent;

mixin ImageGestureRecognizerMixin on GestureRecognizer {
  int? _pointer;

  @override
  void addPointer(PointerDownEvent event) {
    if (_pointer == event.pointer) {
      return;
    }
    _pointer = event.pointer;
    super.addPointer(event);
  }
}

class ImageTapGestureRecognizer extends TapGestureRecognizer
    with ImageGestureRecognizerMixin {
  ImageTapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    super.preAcceptSlopTolerance,
    super.postAcceptSlopTolerance,
  });
}

class ImageDoubleTapGestureRecognizer extends DoubleTapGestureRecognizer
    with ImageGestureRecognizerMixin {
  ImageDoubleTapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });
}

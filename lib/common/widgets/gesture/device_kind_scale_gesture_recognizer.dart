import 'package:flutter/gestures.dart';

class DeviceKindScaleGestureRecognizer extends ScaleGestureRecognizer {
  DeviceKindScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    super.dragStartBehavior,
    super.trackpadScrollCausesScale,
    super.trackpadScrollToScaleFactor,
  });

  final Map<int, PointerDeviceKind> _pointerKinds = {};

  bool _acceptsKind(PointerDeviceKind kind) =>
      _pointerKinds.isEmpty || _pointerKinds.values.first == kind;

  // 提前过滤，避免 handleNonAllowedPointer 连带拒绝正在进行的手势。
  @override
  void addPointer(PointerDownEvent event) {
    if (_acceptsKind(event.kind)) {
      super.addPointer(event);
    }
  }

  @override
  void addPointerPanZoom(PointerPanZoomStartEvent event) {
    if (_acceptsKind(event.kind)) {
      super.addPointerPanZoom(event);
    }
  }

  @override
  void startTrackingPointer(int pointer, [Matrix4? transform]) {
    _pointerKinds[pointer] = getKindForPointer(pointer);
    super.startTrackingPointer(pointer, transform);
  }

  @override
  void stopTrackingPointer(int pointer) {
    _pointerKinds.remove(pointer);
    super.stopTrackingPointer(pointer);
  }

  @override
  void dispose() {
    _pointerKinds.clear();
    super.dispose();
  }
}

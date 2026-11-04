import 'dart:io' show Platform;

import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class PlayerGestureDiagnostics with WidgetsBindingObserver {
  PlayerGestureDiagnostics({required this.describeState});

  final String Function() describeState;
  static int _nextSession = 0;
  final int _session = ++_nextSession;
  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, int> _lastSamples = {};
  final Set<int> _observedPointers = {};
  int _sequence = 0;
  bool _attached = false;

  bool get enabled => Platform.isWindows && Pref.enableLog;

  void log(String event, String Function() details, {bool sample = false}) {
    if (!enabled) return;
    final elapsed = _clock.elapsedMilliseconds;
    if (sample) {
      final previous = _lastSamples[event];
      if (previous != null && elapsed - previous < 750) return;
      _lastSamples[event] = elapsed;
    }
    // 现有错误日志页只持久化 error/fatal，诊断也经同一 Logger 链路保存。
    logger.e(
      '[PlayerGesture] session=$_session seq=${++_sequence} t=${elapsed}ms '
      '$event ${details()} | ${describeState()}',
    );
  }

  void attach() {
    if (!enabled || _attached) return;
    _attached = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    WidgetsBinding.instance.addObserver(this);
    log('attach', () => 'diagnostics=release-capable');
  }

  void dispose() {
    if (!_attached) return;
    log('detach', () => 'observed=$_observedPointers');
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  void _onPointer(PointerEvent event) {
    if (!enabled) return;
    final boundary = event is PointerDownEvent ||
        event is PointerUpEvent ||
        event is PointerCancelEvent ||
        event is PointerPanZoomStartEvent ||
        event is PointerPanZoomEndEvent;
    if (event is PointerDownEvent || event is PointerPanZoomStartEvent) {
      _observedPointers.add(event.pointer);
    } else if (event is PointerUpEvent ||
        event is PointerCancelEvent ||
        event is PointerPanZoomEndEvent) {
      _observedPointers.remove(event.pointer);
    } else if (!_observedPointers.contains(event.pointer) ||
        (event is! PointerMoveEvent && event is! PointerPanZoomUpdateEvent)) {
      return;
    }
    log(
      'raw.${event.runtimeType}',
      () => 'pointer=${event.pointer} device=${event.device} '
          'kind=${event.kind.name} buttons=${event.buttons} '
          'position=${event.position} synthesized=${event.synthesized} '
          'sourceUs=${event.timeStamp.inMicroseconds} observed=$_observedPointers',
      sample: !boundary,
    );
  }

  @override
  void didChangeMetrics() {
    log('metrics', () => 'window metrics changed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log('lifecycle', () => state.name);
  }
}

mixin PlayerGestureTrace on OneSequenceGestureRecognizer {
  PlayerGestureDiagnostics? diagnostics;
  final Set<int> tracedPointers = {};

  @override
  void startTrackingPointer(int pointer, [Matrix4? transform]) {
    super.startTrackingPointer(pointer, transform);
    tracedPointers.add(pointer);
    diagnostics?.log(
      '$debugDescription.track',
      () => 'pointer=$pointer tracked=$tracedPointers',
    );
  }

  @override
  void stopTrackingPointer(int pointer) {
    diagnostics?.log(
      '$debugDescription.untrack.before',
      () => 'pointer=$pointer tracked=$tracedPointers',
    );
    super.stopTrackingPointer(pointer);
    tracedPointers.remove(pointer);
    diagnostics?.log(
      '$debugDescription.untrack.after',
      () => 'pointer=$pointer tracked=$tracedPointers',
    );
  }

  @override
  void acceptGesture(int pointer) {
    diagnostics?.log('$debugDescription.accept', () => 'pointer=$pointer');
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    diagnostics?.log('$debugDescription.reject', () => 'pointer=$pointer');
    super.rejectGesture(pointer);
  }

  @override
  T? invokeCallback<T>(
    String name,
    RecognizerCallback<T> callback, {
    String Function()? debugReport,
  }) {
    diagnostics?.log(
      '$debugDescription.$name',
      () => 'tracked=$tracedPointers',
      sample: name.contains('Update'),
    );
    return super.invokeCallback(name, callback, debugReport: debugReport);
  }
}

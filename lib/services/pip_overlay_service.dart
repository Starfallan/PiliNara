import 'dart:async';

import 'package:PiliPlus/services/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VideoStackManager {
  static int _videoPageCount = 0;

  static void increment() {
    _videoPageCount++;
    _log('increment: count = $_videoPageCount');
  }

  static void decrement() {
    if (_videoPageCount > 0) {
      _videoPageCount--;
      _log('decrement: count = $_videoPageCount');
    }
  }

  static bool isReturningToVideo() {
    final result = _videoPageCount > 1;
    if (result) {
      _log('isReturningToVideo check: true (count = $_videoPageCount)');
    }
    return result;
  }

  static void _log(String msg) {
    try {
      throw Exception('[VideoStackManager] $msg');
    } catch (e, s) {
      logger.e('[PiP Debug]', error: e, stackTrace: s);
    }
  }
}

class PipOverlayService {
  static const double pipWidth = 200;
  static const double pipHeight = 112;

  static OverlayEntry? _overlayEntry;
  static bool isInPipMode = false;

  static VoidCallback? _onCloseCallback;
  static VoidCallback? _onTapToReturnCallback;
  
  // 保存控制器引用，防止被 GC
  static dynamic _savedController;
  static final Map<String, dynamic> _savedControllers = {};

  static void startPip({
    required BuildContext context,
    required Widget Function(bool isPipMode) videoPlayerBuilder,
    VoidCallback? onClose,
    VoidCallback? onTapToReturn,
    dynamic controller,
    Map<String, dynamic>? additionalControllers,
  }) {
    if (isInPipMode) {
      return;
    }

    isInPipMode = true;
    _onCloseCallback = onClose;
    _onTapToReturnCallback = onTapToReturn;
    _savedController = controller;
    if (additionalControllers != null) {
      _savedControllers.addAll(additionalControllers);
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => PipWidget(
        videoPlayerBuilder: videoPlayerBuilder,
        onClose: () {
          stopPip(callOnClose: true, immediate: true);
        },
        onTapToReturn: () {
          final callback = _onTapToReturnCallback;
          _onCloseCallback = null;
          _onTapToReturnCallback = null;
          callback?.call();
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final overlayContext = Get.overlayContext ?? context;
        Overlay.of(overlayContext).insert(_overlayEntry!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error inserting pip overlay: $e');
        }
        isInPipMode = false;
        _overlayEntry = null;
      }
    });
  }

  static T? getSavedController<T>() => _savedController as T?;
  
  static T? getAdditionalController<T>(String key) => _savedControllers[key] as T?;

  static void stopPip({bool callOnClose = true, bool immediate = false}) {
    if (!isInPipMode && _overlayEntry == null) {
      return;
    }

    isInPipMode = false;

    final closeCallback = callOnClose ? _onCloseCallback : null;
    _onCloseCallback = null;
    _onTapToReturnCallback = null;
    _savedController = null;
    _savedControllers.clear();

    final overlayToRemove = _overlayEntry;
    _overlayEntry = null;

    void removeAndCallback() {
      try {
        overlayToRemove?.remove();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error removing pip overlay: $e');
        }
      }
      closeCallback?.call();
    }

    if (immediate) {
      removeAndCallback();
    } else {
      Future.delayed(const Duration(milliseconds: 300), removeAndCallback);
    }
  }
}

class PipWidget extends StatefulWidget {
  final Widget Function(bool isPipMode) videoPlayerBuilder;
  final VoidCallback onClose;
  final VoidCallback onTapToReturn;

  const PipWidget({
    super.key,
    required this.videoPlayerBuilder,
    required this.onClose,
    required this.onTapToReturn,
  });

  @override
  State<PipWidget> createState() => _PipWidgetState();
}

class _PipWidgetState extends State<PipWidget> {
  double? _left;
  double? _top;
  final double _width = PipOverlayService.pipWidth;
  final double _height = PipOverlayService.pipHeight;

  bool _showControls = true;
  Timer? _hideTimer;

  bool _isClosing = false;

  late final Widget _videoPlayerWidget;

  @override
  void initState() {
    super.initState();
    _videoPlayerWidget = widget.videoPlayerBuilder(true);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (PipOverlayService._overlayEntry != null) {
      PipOverlayService._onCloseCallback = null;
      PipOverlayService._onTapToReturnCallback = null;
    }
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onTap() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isClosing) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;

    _left ??= screenSize.width - _width - 16;
    _top ??= screenSize.height - _height - 100;

    return Positioned(
      left: _left!,
      top: _top!,
      child: GestureDetector(
        onTap: _onTap,
        onPanStart: (_) {
          _hideTimer?.cancel();
        },
        onPanUpdate: (details) {
          setState(() {
            _left = (_left! + details.delta.dx).clamp(
              0.0,
              screenSize.width - _width,
            );
            _top = (_top! + details.delta.dy).clamp(
              0.0,
              screenSize.height - _height,
            );
          });
        },
        onPanEnd: (_) {
          if (_showControls) {
            _startHideTimer();
          }
        },
        child: Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AbsorbPointer(
                    child: _videoPlayerWidget,
                  ),
                ),
                if (_showControls) ...[
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        _hideTimer?.cancel();
                        setState(() {
                          _isClosing = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          widget.onClose();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        _hideTimer?.cancel();
                        setState(() {
                          _isClosing = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          widget.onTapToReturn();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_full,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class LivePipOverlayService {
  static OverlayEntry? _overlayEntry;
  static bool _isInPipMode = false;
  static String? _currentLiveHeroTag;
  static int? _currentRoomId;

  static VoidCallback? _onCloseCallback;
  static VoidCallback? _onReturnCallback;
  
  // 保存控制器引用，防止被 GC
  static dynamic _savedController;

  static bool get isInPipMode => _isInPipMode;

  static int? get currentRoomId => _currentRoomId;
  
  static T? getSavedController<T>() => _savedController as T?;

  static void startLivePip({
    required BuildContext context,
    required String heroTag,
    required int roomId,
    required PlPlayerController plPlayerController,
    VoidCallback? onClose,
    VoidCallback? onReturn,
    dynamic controller,
  }) {
    if (_isInPipMode) {
      stopLivePip(callOnClose: true);
    }

    _isInPipMode = true;
    _currentLiveHeroTag = heroTag;
    _currentRoomId = roomId;
    _onCloseCallback = onClose;
    _onReturnCallback = onReturn;
    _savedController = controller;

    _overlayEntry = OverlayEntry(
      builder: (context) => LivePipWidget(
        heroTag: heroTag,
        roomId: roomId,
        plPlayerController: plPlayerController,
        onClose: () {
          stopLivePip(callOnClose: true);
        },
        onReturn: () {
          final callback = _onReturnCallback;

          final overlayToRemove = _overlayEntry;
          _overlayEntry = null;

          try {
            overlayToRemove?.remove();
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error removing live pip overlay: $e');
            }
          }

          callback?.call();
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final overlayContext = Get.overlayContext ?? context;
        Overlay.of(overlayContext).insert(_overlayEntry!);
      } catch (e) {
        SmartDialog.showToast('Overlay insert failed: $e');
        _isInPipMode = false;
        _overlayEntry = null;
      }
    });
  }

  static void stopLivePip({bool callOnClose = true}) {
    if (!_isInPipMode && _overlayEntry == null) {
      return;
    }

    _isInPipMode = false;
    _currentLiveHeroTag = null;
    _currentRoomId = null;

    final closeCallback = callOnClose ? _onCloseCallback : null;
    _onCloseCallback = null;
    _onReturnCallback = null;
    _savedController = null;

    final overlayToRemove = _overlayEntry;
    _overlayEntry = null;

    try {
      overlayToRemove?.remove();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error removing live pip overlay: $e');
      }
    }

    closeCallback?.call();
  }

  static bool isCurrentLiveRoom(int roomId) {
    return _isInPipMode && _currentRoomId == roomId;
  }
}

class LivePipWidget extends StatefulWidget {
  final String heroTag;
  final int roomId;
  final PlPlayerController plPlayerController;
  final VoidCallback onClose;
  final VoidCallback onReturn;

  const LivePipWidget({
    super.key,
    required this.heroTag,
    required this.roomId,
    required this.plPlayerController,
    required this.onClose,
    required this.onReturn,
  });

  @override
  State<LivePipWidget> createState() => _LivePipWidgetState();
}

class _LivePipWidgetState extends State<LivePipWidget> {
  double? _left;
  double? _top;
  final double _width = 200;
  final double _height = 112;

  bool _showControls = true;
  Timer? _hideTimer;

  late final Widget _videoPlayerWidget;

  @override
  void initState() {
    super.initState();
    _videoPlayerWidget = PLVideoPlayer(
      maxWidth: _width,
      maxHeight: _height,
      plPlayerController: widget.plPlayerController,
      headerControl: const SizedBox.shrink(),
      bottomControl: const SizedBox.shrink(),
      danmuWidget: const SizedBox.shrink(),
    );
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (LivePipOverlayService._overlayEntry != null) {
      LivePipOverlayService._onCloseCallback = null;
      LivePipOverlayService._onReturnCallback = null;
    }
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
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
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 12,
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
                        widget.onClose();
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
                        widget.onReturn();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_full,
                          color: Colors.white,
                          size: 28,
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

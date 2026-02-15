import 'dart:async';
import 'dart:math' show max;

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/view.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class LivePipOverlayService {
  static OverlayEntry? _overlayEntry;
  static bool _isInPipMode = false;
  static bool isVertical = false;

  static double lastLeft = 0;
  static double lastTop = 0;
  static double lastWidth = 0;
  static double lastHeight = 0;

  static Rect get pipRect => Rect.fromLTWH(lastLeft, lastTop, lastWidth, lastHeight);

  static String? _currentLiveHeroTag;
  static int? _currentRoomId;

  static VoidCallback? _onCloseCallback;
  static VoidCallback? _onReturnCallback;

  static void _logPipDebug(String message) {
    if (!Pref.enableLog && !kDebugMode) return;
    try {
      final logMsg = '[LivePipOverlayService] $message';
      throw Exception(logMsg);
    } catch (e, s) {
      logger.e('[PiP Debug]', error: e, stackTrace: s);
    }
  }

  static Rect? get currentBounds {
    if (_overlayEntry == null || !_isInPipMode) return null;
    return _lastBounds;
  }
  static Rect? _lastBounds;
  static void updateBounds(Rect bounds) {
    if (!Pref.enableInAppToNativePip) return;

    if (lastLeft == bounds.left &&
        lastTop == bounds.top &&
        lastWidth == bounds.width &&
        lastHeight == bounds.height) return;

    lastLeft = bounds.left;
    lastTop = bounds.top;
    lastWidth = bounds.width;
    lastHeight = bounds.height;
    _lastBounds = bounds;

    _logPipDebug('updateBounds called: left=${bounds.left}, top=${bounds.top}, width=${bounds.width}, height=${bounds.height}');

    // 同步给播放器控制器，以便更新原生 PIP 的 sourceRectHint
    final controller = PlPlayerController.instance;
    if (controller != null && _isInPipMode) {
      controller.syncPipParams();
    }
  }

  static String? get currentHeroTag => _currentLiveHeroTag;
  static int? get currentRoomId => _currentRoomId;

  static void onReturn() {
    final callback = _onReturnCallback;
    _onCloseCallback = null;
    _onReturnCallback = null;
    callback?.call();
  }

  // 保存控制器引用，防止被 GC
  static dynamic _savedController;
  static PlPlayerController? _savedPlayerController;

  static bool get isInPipMode => _isInPipMode;

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
    isVertical = plPlayerController.isVertical;
    _currentLiveHeroTag = heroTag;
    _currentRoomId = roomId;
    _onCloseCallback = onClose;
    _onReturnCallback = onReturn;
    _savedController = controller;
    _savedPlayerController = plPlayerController;

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
        if (kDebugMode) {
          debugPrint('Error inserting live pip overlay: $e');
        }
        SmartDialog.showToast('小窗启动失败: $e');
        
        // 完整清理所有状态
        _isInPipMode = false;
        _currentLiveHeroTag = null;
        _currentRoomId = null;
        _overlayEntry = null;
        _savedController = null;
        _savedPlayerController = null;
        
        // 通知调用者失败
        onClose?.call();
      }
    });
  }

  static void stopLivePip({bool callOnClose = true, bool immediate = false}) {
    if (!_isInPipMode && _overlayEntry == null) {
      return;
    }

    _isInPipMode = false;
    _currentLiveHeroTag = null;
    _currentRoomId = null;
    
    // 清理坐标缓存，防止影响后续的非小窗模式 PiP
    _lastBounds = null;
    
    // 通知原生端清除 sourceRectHint，恢复全屏 PiP 模式
    final controller = PlPlayerController.instance;
    if (controller != null) {
      if (!isInPipMode) {
        // 如果不是应用内小窗，则重置为普通模式
        controller.syncPipParams(autoEnable: false, clearSourceRectHint: true);
        Future.delayed(const Duration(milliseconds: 300), () {
          // 重新同步，若当前是视频页则会使用 videoViewRect
          controller.syncPipParams();
        });
      } else {
        // 如果是 Native PiP 关闭，但还在应用内小窗（这一般不发生，通常是一起关闭）
        controller.syncPipParams(autoEnable: true);
      }
    }

    final closeCallback = callOnClose ? _onCloseCallback : null;
    final playerController = _savedPlayerController;
    
    _onCloseCallback = null;
    _onReturnCallback = null;
    _savedController = null;
    _savedPlayerController = null;

    final overlayToRemove = _overlayEntry;
    _overlayEntry = null;

    void removeAndCallback() {
      try {
        overlayToRemove?.remove();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error removing live pip overlay: $e');
        }
      }
      closeCallback?.call();
    }

    if (immediate) {
      removeAndCallback();
    } else {
      Future.delayed(const Duration(milliseconds: 300), removeAndCallback);
    }

    // 如果需要清理，先停止播放器
    if (callOnClose && playerController != null) {
      try {
        // 停止播放但不 dispose，因为其他地方可能还在使用
        playerController.pause();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error pausing player: $e');
        }
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

class _LivePipWidgetState extends State<LivePipWidget> with WidgetsBindingObserver {
  double? _left;
  double? _top;
  double _scale = 1.0;
  double get _width => (LivePipOverlayService.isVertical ? 112 : 200) * _scale;
  double get _height => (LivePipOverlayService.isVertical ? 200 : 112) * _scale;

  bool _showControls = true;
  Timer? _hideTimer;
  final GlobalKey _videoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startHideTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  void _onDoubleTap() {
    setState(() {
      if (_scale < 1.1) {
        _scale = 1.5;
      } else if (_scale < 1.6) {
        _scale = 2.0;
      } else {
        _scale = 1.0;
      }

      // 缩放后立即计算并约束位置，防止按钮或部分窗口超出屏幕
      final screenSize = MediaQuery.of(context).size;
      _left = (_left ?? 0.0)
          .clamp(0.0, max(0.0, screenSize.width - _width))
          .toDouble();
      _top = (_top ?? 0.0)
          .clamp(0.0, max(0.0, screenSize.height - _height))
          .toDouble();
    });
    _startHideTimer();
    
    // 缩放后立即同步新的位置和尺寸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? renderBox =
          _videoKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final offset = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        LivePipOverlayService.updateBounds(
            Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    _left ??= screenSize.width - _width - 16;
    _top ??= screenSize.height - _height - 100;

    // 更新当前位置信息给 Service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? renderBox =
          _videoKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final offset = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        LivePipOverlayService.updateBounds(
            Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
      } else {
        LivePipOverlayService.updateBounds(
            Rect.fromLTWH(_left!, _top!, _width, _height));
      }
    });

    final double currentWidth = _width;
    final double currentHeight = _height;
    final double currentLeft = _left!;
    final double currentTop = _top!;

    return Positioned(
        left: currentLeft,
        top: currentTop,
        child: GestureDetector(
          onTap: _onTap,
          onDoubleTap: _onDoubleTap,
          onPanStart: (_) {
            _hideTimer?.cancel();
          },
          onPanUpdate: (details) {
            setState(() {
              _left = (_left! + details.delta.dx).clamp(
                0.0,
                max(0.0, screenSize.width - currentWidth),
              ).toDouble();
              _top = (_top! + details.delta.dy).clamp(
                0.0,
                max(0.0, screenSize.height - currentHeight),
              ).toDouble();
            });
          },
          onPanEnd: (_) {
            if (_showControls) {
              _startHideTimer();
            }
            // 拖动结束后立即同步最终位置给原生端
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final RenderBox? renderBox =
                  _videoKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                final offset = renderBox.localToGlobal(Offset.zero);
                final size = renderBox.size;
                LivePipOverlayService.updateBounds(
                    Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
              }
            });
          },
          child: Container(
            key: _videoKey,
            width: currentWidth,
            height: currentHeight,
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
                      child: PLVideoPlayer(
                        maxWidth: currentWidth,
                        maxHeight: currentHeight,
                        isPipMode: true,
                        plPlayerController: widget.plPlayerController,
                        headerControl: const SizedBox.shrink(),
                        bottomControl: const SizedBox.shrink(),
                        danmuWidget: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  if (_showControls) ...[
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                    // 左上角关闭
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        onTap: () {
                          _hideTimer?.cancel();
                          widget.onClose();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // 右上角放大/还原
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          _hideTimer?.cancel();
                          widget.onReturn();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.open_in_full,
                            color: Colors.white,
                            size: 20,
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

import 'dart:async';
import 'dart:math' show max;

import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
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

  static int getCount() => _videoPageCount;

  static bool isReturningToVideo() {
    final result = _videoPageCount > 1;
    if (result) {
      _log('isReturningToVideo check: true (count = $_videoPageCount)');
    }
    return result;
  }

  static void _log(String msg) {
    if (!Pref.enableLog && !kDebugMode) return;
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
  static bool isVertical = false;

  static OverlayEntry? _overlayEntry;
  static bool isInPipMode = false;
  static final RxBool _isNativePip = false.obs;
  static bool get isNativePip => _isNativePip.value;
  static set isNativePip(bool value) => _isNativePip.value = value;

  static double lastLeft = 0;
  static double lastTop = 0;
  static double lastWidth = 0;
  static double lastHeight = 0;

  static Rect get pipRect => Rect.fromLTWH(lastLeft, lastTop, lastWidth, lastHeight);

  static VoidCallback? _onCloseCallback;
  static VoidCallback? _onTapToReturnCallback;

  static void _logPipDebug(String message) {
    if (!Pref.enableLog && !kDebugMode) return;
    try {
      final logMsg = '[PipOverlayService] $message';
      throw Exception(logMsg);
    } catch (e, s) {
      logger.e('[PiP Debug]', error: e, stackTrace: s);
    }
  }

  // 【伪全屏方案】不需要精确坐标追踪，移除 currentBounds 和 updateBounds

  static void onTapToReturn() {
    final callback = _onTapToReturnCallback;
    _onCloseCallback = null;
    _onTapToReturnCallback = null;
    callback?.call();
  }
  
  // 保存控制器引用，防止被 GC
  static dynamic _savedController;
  static final Map<String, dynamic> _savedControllers = {};

  static void startPip({
    required BuildContext context,
    required Widget Function(bool isNative, double width, double height)
    videoPlayerBuilder,
    VoidCallback? onClose,
    VoidCallback? onTapToReturn,
    dynamic controller,
    Map<String, dynamic>? additionalControllers,
  }) {
    if (isInPipMode) {
      return;
    }

    isInPipMode = true;
    isVertical = false;
    if (controller is VideoDetailController) {
      isVertical = controller.isVertical.value;
    }

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

  static void stopPip({bool callOnClose = true, bool immediate = false, bool skipSyncParams = false}) {
    if (!isInPipMode && _overlayEntry == null) {
      return;
    }

    isInPipMode = false;
    isNativePip = false;
    
    // 通知原生端禁用 PiP
    final controller = PlPlayerController.instance;
    if (controller != null && !skipSyncParams) {
      controller.syncPipParams(autoEnable: false);
    }

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
  final Widget Function(bool isNative, double width, double height)
  videoPlayerBuilder;
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

class _PipWidgetState extends State<PipWidget> with WidgetsBindingObserver {
  double? _left;
  double? _top;
  double _scale = 1.0;

  // 动态获取小窗尺寸：优先从视频播放器获取实际宽高，fallback 到 isVertical 标志
  double get _width {
    final controller = PipOverlayService.getSavedController<VideoDetailController>();
    final plController = controller?.plPlayerController;
    if (plController?.videoController != null) {
      final state = plController!.videoController!.player.state;
      if (state.width != null && state.height != null && state.height! > 0) {
        // 根据视频实际宽高比计算小窗尺寸
        final aspectRatio = state.width! / state.height!;
        if (aspectRatio > 1) {
          // 横屏视频
          return PipOverlayService.pipWidth * _scale;
        } else {
          // 竖屏视频
          return PipOverlayService.pipHeight * _scale;
        }
      }
    }
    // Fallback: 使用 isVertical 标志
    return (PipOverlayService.isVertical
            ? PipOverlayService.pipHeight
            : PipOverlayService.pipWidth) *
        _scale;
  }

  double get _height {
    final controller = PipOverlayService.getSavedController<VideoDetailController>();
    final plController = controller?.plPlayerController;
    if (plController?.videoController != null) {
      final state = plController!.videoController!.player.state;
      if (state.width != null && state.height != null && state.height! > 0) {
        final aspectRatio = state.width! / state.height!;
        if (aspectRatio > 1) {
          // 横屏视频
          return PipOverlayService.pipHeight * _scale;
        } else {
          // 竖屏视频
          return PipOverlayService.pipWidth * _scale;
        }
      }
    }
    // Fallback
    return (PipOverlayService.isVertical
            ? PipOverlayService.pipWidth
            : PipOverlayService.pipHeight) *
        _scale;
  }

  bool _showControls = true;
  Timer? _hideTimer;

  bool _isClosing = false;
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
    if (PipOverlayService._overlayEntry != null) {
      PipOverlayService._onCloseCallback = null;
      PipOverlayService._onTapToReturnCallback = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!PipOverlayService.isInPipMode) return;
    
    // 【Fallback 恢复机制】当用户回到应用时，恢复小窗状态
    // 这是为了防止伪全屏触发后，系统 PiP 启动失败导致无法恢复的情况
    // onPipChanged 只在真正进入/退出系统 PiP 时触发，如果 PiP 启动失败则不会触发
    if (state == AppLifecycleState.resumed) {
      // 延迟一小段时间，确保 onPipChanged 有机会先执行
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && PipOverlayService.isInPipMode) {
          PipOverlayService.isNativePip = false;
        }
      });
    }
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

  void _resetHideTimer() {
    if (_showControls) {
      _startHideTimer();
    }
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
    
    // 【伪全屏方案】无需同步坐标，移除 updateBounds 调用
  }

  @override
  Widget build(BuildContext context) {
    if (_isClosing) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;

    _left ??= screenSize.width - _width - 16;
    _top ??= screenSize.height - _height - 100;

    // 【伪全屏方案】使用 Obx 响应 isNativePip 状态
    // 当进入系统 PiP 前，Overlay 自动扩展为全屏，确保捕获正确内容
    return Obx(() {
      final bool isNative = PipOverlayService.isNativePip;
      final double currentWidth = isNative ? screenSize.width : _width;
      final double currentHeight = isNative ? screenSize.height : _height;
      final double currentLeft = isNative ? 0 : _left!;
      final double currentTop = isNative ? 0 : _top!;

      return Positioned(
        left: currentLeft,
        top: currentTop,
        child: GestureDetector(
          onTap: isNative ? null : _onTap,
          onDoubleTap: isNative ? null : _onDoubleTap,
          onPanStart: isNative ? null : (_) {
            _hideTimer?.cancel();
          },
          onPanUpdate: isNative ? null : (details) {
            setState(() {
              _left = (_left! + details.delta.dx)
                  .clamp(
                    0.0,
                    max(0.0, screenSize.width - currentWidth),
                  )
                  .toDouble();
              _top = (_top! + details.delta.dy)
                  .clamp(
                    0.0,
                    max(0.0, screenSize.height - currentHeight),
                  )
                  .toDouble();
            });
          },
          onPanEnd: isNative ? null : (_) {
            if (_showControls) {
              _startHideTimer();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: currentWidth,
            height: currentHeight,
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
                      child: widget.videoPlayerBuilder(
                        isNative, // 传入伪全屏状态
                        currentWidth,
                        currentHeight,
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
                          setState(() {
                            _isClosing = true;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onClose();
                          });
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
                    // 右上角还原
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
                            widget.onTapToReturn();
                          });
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
                    // 底部控制栏
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 后退10秒
                          GestureDetector(
                            onTap: () {
                              _resetHideTimer();
                              final controller = PipOverlayService
                                  .getSavedController<VideoDetailController>();
                              final plController = controller?.plPlayerController;
                              if (plController != null) {
                                final current = plController.position;
                                plController.seekTo(
                                  current - const Duration(seconds: 10),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.replay_10,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          // 播放/暂停
                          Obx(() {
                            final controller = PipOverlayService
                                .getSavedController<VideoDetailController>();
                            final plController = controller?.plPlayerController;
                            final isPlaying = plController
                                    ?.playerStatus.value ==
                                PlayerStatus.playing;
                            return GestureDetector(
                              onTap: () {
                                _resetHideTimer();
                                if (isPlaying) {
                                  plController?.pause();
                                } else {
                                  plController?.play();
                                }
                              },
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                            );
                          }),
                          // 前进10秒
                          GestureDetector(
                            onTap: () {
                              _resetHideTimer();
                              final controller = PipOverlayService
                                  .getSavedController<VideoDetailController>();
                              final plController = controller?.plPlayerController;
                              if (plController != null) {
                                final current = plController.position;
                                plController.seekTo(
                                  current + const Duration(seconds: 10),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.forward_10,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

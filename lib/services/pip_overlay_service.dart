import 'dart:async';
import 'dart:math' show max;

import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
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

  static VoidCallback? _onCloseCallback;
  static VoidCallback? _onTapToReturnCallback;

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
    required PlPlayerController plPlayerController,
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
        
        // 允许应用内小窗继续使用 Auto-PiP 手势
        if (Platform.isAndroid && plPlayerController.autoPiP) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isInPipMode) return;
            Utils.sdkInt.then((sdkInt) {
              if (sdkInt >= 31) {
                Utils.channel.invokeMethod('setPipAutoEnterEnabled', {
                  'autoEnable': true,
                });
              }
            });
          });
        }
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

  static void stopPip({
    bool callOnClose = true,
    bool immediate = false,
    bool resetState = true,
  }) {
    if (!isInPipMode && _overlayEntry == null) {
      return;
    }

    if (kDebugMode) {
      debugPrint(
          '[PiP] Stopping PiP mode (immediate: $immediate, callOnClose: $callOnClose, resetState: $resetState)');
    }

    isInPipMode = false;
    isNativePip = false;

    final closeCallback = callOnClose ? _onCloseCallback : null;
    _onCloseCallback = null;
    _onTapToReturnCallback = null;

    // 清理控制器缓存，防止内存泄漏和状态污染
    if (kDebugMode &&
        (_savedController != null || _savedControllers.isNotEmpty)) {
      debugPrint('[PiP] Clearing cached controllers, resetState: $resetState');
    }

    // 强制调用控制器的清理逻辑，特别是 SponsorBlock 相关的监听器
    if (_savedController != null && resetState) {
      try {
        if (_savedController is VideoDetailController) {
          if (kDebugMode) {
            debugPrint(
                '[PiP] Explicitly resetting SponsorBlock state for cached VideoDetailController');
          }
          (_savedController as VideoDetailController).resetBlock();
        } else if (kDebugMode) {
          debugPrint(
              '[PiP] Cached controller is not a VideoDetailController, skipping resetBlock');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PiP] Error while resetting cached controller: $e');
        }
      }
    }

    _savedController = null;
    _savedControllers.clear();

    final overlayToRemove = _overlayEntry;
    _overlayEntry = null;

    void removeAndCallback() {
      try {
        overlayToRemove?.remove();
        if (kDebugMode) {
          debugPrint('[PiP] Overlay entry removed successfully');
        }
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

  double get _width =>
      (PipOverlayService.isVertical
          ? PipOverlayService.pipHeight
          : PipOverlayService.pipWidth) *
      _scale;
  double get _height =>
      (PipOverlayService.isVertical
          ? PipOverlayService.pipWidth
          : PipOverlayService.pipHeight) *
      _scale;

  bool _showControls = true;
  Timer? _hideTimer;

  bool _isClosing = false;

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

    // 此处无需重复处理，状态同步由PlPlayerController中的onPipChanged消息统一管理
    // 而且在Controller中已加入了退出延迟，确保系统转场动画完成后再切换布局。
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isClosing) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;

    _left ??= screenSize.width - _width - 16;
    _top ??= screenSize.height - _height - 100;

    return Obx(() {
      final bool isNative = PipOverlayService.isNativePip;
      
      // 系统 PiP 模式下，直接铺满窗口，不执行任何自定义尺寸或位置计算
      if (isNative) {
        return Positioned.fill(
          child: Container(
            color: Colors.black,
            child: AbsorbPointer(
              child: widget.videoPlayerBuilder(
                true,
                screenSize.width,
                screenSize.height,
              ),
            ),
          ),
        );
      }

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
              _left = (_left! + details.delta.dx)
                  .clamp(
                    0.0,
                    max(0.0, screenSize.width - _width),
                  )
                  .toDouble();
              _top = (_top! + details.delta.dy)
                  .clamp(
                    0.0,
                    max(0.0, screenSize.height - _height),
                  )
                  .toDouble();
            });
          },
          onPanEnd: (_) {
            if (_showControls) {
              _startHideTimer();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
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
                        false,
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

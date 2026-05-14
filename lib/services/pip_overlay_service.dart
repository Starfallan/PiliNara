import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show max;

import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
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
    if (!kDebugMode) return;
    logger.i('[VideoStackManager] $msg');
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
  static PlPlayerController? _savedPlayerController;
  static String? _savedVideoContextKey;
  static String? get savedVideoContextKey => _savedVideoContextKey;
  static final Map<String, dynamic> _savedControllers = {};

  static bool _isVideoLikeRoute(String route) {
    return route.startsWith('/video') || route.startsWith('/liveRoom');
  }

  static void _setSystemAutoPipEnabled(
    PlPlayerController? plPlayerController,
    bool enabled,
  ) {
    // 1. 基础条件判断
    if (!Platform.isAndroid ||
        plPlayerController == null ||
        !plPlayerController.autoPiP ||
        !Pref.enableInAppPipToSystemPip) {
      return;
    }

    // 2. 直接同步获取 sdkInt 并执行逻辑，不再使用 .then
    if (DeviceUtils.sdkInt >= 31) {
      Utils.channel.invokeMethod('setPipAutoEnterEnabled', {
        'autoEnable': enabled,
      });
    }
  }

  static String _keyPart(Object? value) => value?.toString() ?? '';

  static void _pipTrace(String tag, String message) {
    debugPrint('[PiP-Trace] [PipService] [$tag] $message');
  }

  static String? buildVideoContextKey({
    Object? videoType,
    Object? bvid,
    Object? cid,
    Object? epId,
    Object? seasonId,
  }) {
    if (bvid == null &&
        cid == null &&
        epId == null &&
        seasonId == null &&
        videoType == null) {
      return null;
    }
    return [
      _keyPart(videoType),
      _keyPart(bvid),
      _keyPart(cid),
      _keyPart(epId),
      _keyPart(seasonId),
    ].join('|');
  }

  static String? contextKeyFromArgs(Map? args) {
    if (args == null) {
      return null;
    }
    return buildVideoContextKey(
      videoType: args['videoType'],
      bvid: args['bvid'],
      cid: args['cid'],
      epId: args['epId'],
      seasonId: args['seasonId'],
    );
  }

  static String? _contextKeyFromController(dynamic controller) {
    if (controller is! VideoDetailController) {
      return null;
    }
    return buildVideoContextKey(
      videoType: controller.videoType,
      bvid: controller.bvid,
      cid: controller.cid.value,
      epId: controller.epId,
      seasonId: controller.seasonId,
    );
  }

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
    final incomingKey = _contextKeyFromController(controller);
    _pipTrace(
      'startPip-enter',
      'incomingKey=$incomingKey, currentSavedKey=$_savedVideoContextKey, '
          'currentlyInPipMode=$isInPipMode, '
          'controllerHash=${controller?.hashCode}, '
          'playerHash=${plPlayerController.hashCode}',
    );
    if (isInPipMode) {
      _pipTrace('startPip-skip', 'reason=already in PiP mode');
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
    _savedPlayerController = plPlayerController;
    _savedVideoContextKey = _contextKeyFromController(controller);
    if (additionalControllers != null) {
      _savedControllers.addAll(additionalControllers);
    }
    _pipTrace(
      'startPip-stateSaved',
      'savedKey=$_savedVideoContextKey, '
          'additional=${additionalControllers?.length ?? 0}',
    );

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
        _pipTrace('startPip-overlayInserted', '');

        // 允许应用内小窗继续使用 Auto-PiP 手势
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isInPipMode) return;
          _setSystemAutoPipEnabled(plPlayerController, true);
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error inserting pip overlay: $e');
        }
        _pipTrace('startPip-overlayInsertFailed', 'error=$e');
        _setSystemAutoPipEnabled(plPlayerController, false);
        isInPipMode = false;
        _overlayEntry = null;
        _savedController = null;
        _savedPlayerController = null;
        _savedVideoContextKey = null;
        _savedControllers.clear();
      }
    });
  }

  static T? getSavedController<T>() => _savedController as T?;

  static T? getAdditionalController<T>(String key) =>
      _savedControllers[key] as T?;

  static void stopPip({
    bool callOnClose = true,
    bool immediate = false,
    bool resetState = true,
    String? targetContextKey,
  }) {
    _pipTrace(
      'stopPip-enter',
      'callOnClose=$callOnClose, immediate=$immediate, '
          'resetState=$resetState, targetContextKey=$targetContextKey, '
          'savedContextKey=$_savedVideoContextKey, '
          'currentlyInPipMode=$isInPipMode, '
          'hasOverlay=${_overlayEntry != null}',
    );
    if (!isInPipMode && _overlayEntry == null) {
      _pipTrace('stopPip-skip', 'reason=not in PiP mode and no overlay');
      return;
    }

    final bool shouldResetState = targetContextKey == null
        ? resetState
        : targetContextKey != _savedVideoContextKey;

    if (kDebugMode) {
      debugPrint(
        '[PiP] Stopping PiP mode (immediate: $immediate, callOnClose: $callOnClose, shouldResetState: $shouldResetState, targetContextKey: $targetContextKey, savedContextKey: $_savedVideoContextKey)',
      );
    }
    _pipTrace(
      'stopPip-computedReset',
      'shouldResetState=$shouldResetState',
    );

    isInPipMode = false;
    // isNativePip 是 Rx 变量，不能在 build 阶段（如 initState）同步修改，
    // 否则会触发 Obx rebuild 导致 "setState during build" 错误。
    // 延迟到当前帧结束后再更新。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isNativePip = false;
    });

    final closeCallback = callOnClose ? _onCloseCallback : null;
    final playerController = _savedPlayerController;
    _onCloseCallback = null;
    _onTapToReturnCallback = null;

    // 清理控制器缓存，防止内存泄漏和状态污染
    if (kDebugMode &&
        (_savedController != null || _savedControllers.isNotEmpty)) {
      debugPrint(
        '[PiP] Clearing cached controllers, resetState: $shouldResetState, targetContextKey: $targetContextKey, savedContextKey: $_savedVideoContextKey',
      );
    }

    // resetTempSettings 已在 PlPlayerController.setDataSource() 中同步执行。
    // resetBlock 在新 VideoDetailController.onInit() 中同步调用。
    // 旧 controller 进 PiP 时 onClose 跳过了清理，需要在此清除其 SponsorBlock 状态。
    // - cancelBlockListener 同步执行：取消 StreamSubscription，防止旧 listener 在
    //   新视频上继续触发广告跳过（不触碰 Rx，安全）。
    // - resetBlock 剩余部分（清 RxList、videoLabel）延后到下一帧：这些是 Rx 操作，
    //   stopPip 可能从 initState（build 阶段）调用，同步触发会引发
    //   "setState during build" 红屏。
    if (shouldResetState && _savedController is VideoDetailController) {
      final ctrl = _savedController as VideoDetailController;
      _pipTrace(
        'stopPip-resetBlock-sync',
        'cancelBlockListener on savedController=${ctrl.hashCode}',
      );
      ctrl.cancelBlockListener();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pipTrace(
          'stopPip-resetBlock-deferred',
          'resetBlock on savedController=${ctrl.hashCode}',
        );
        ctrl.resetBlock();
      });
    }

    _savedController = null;
    _savedPlayerController = null;
    _savedVideoContextKey = null;
    _savedControllers.clear();

    final overlayToRemove = _overlayEntry;
    _overlayEntry = null;

    // 小窗结束后，仅在视频/直播详情页中保留系统 Auto-PiP，其余场景立即关闭防止误触发
    final currentRoute = Get.currentRoute;
    final keepAutoPip = _isVideoLikeRoute(currentRoute);
    _setSystemAutoPipEnabled(playerController, keepAutoPip);

    // 如果需要清理，先停止播放器
    if (callOnClose && playerController != null) {
      try {
        _pipTrace(
          'stopPip-pausePlayer',
          'player=${playerController.hashCode}',
        );
        // 停止播放但不 dispose，因为其他地方可能还在使用
        playerController.pause();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error pausing player: $e');
        }
      }
    }

    void removeAndCallback() {
      try {
        overlayToRemove?.remove();
        if (kDebugMode) {
          debugPrint('[PiP] Overlay entry removed successfully');
        }
        _pipTrace('stopPip-overlayRemoved', '');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error removing pip overlay: $e');
        }
        _pipTrace('stopPip-overlayRemoveFailed', 'error=$e');
      }
      _pipTrace(
        'stopPip-onCloseCallback-before',
        'hasCallback=${closeCallback != null}',
      );
      closeCallback?.call();
      _pipTrace('stopPip-onCloseCallback-after', '');
    }

    if (immediate) {
      _pipTrace('stopPip-immediate', '');
      removeAndCallback();
    } else {
      _pipTrace('stopPip-deferred', 'delayMs=300');
      Future.delayed(const Duration(milliseconds: 300), removeAndCallback);
    }
    _pipTrace('stopPip-exit', '');
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
                      top: 3,
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
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                    // 右上角还原
                    Positioned(
                      top: 3,
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
                            size: 19,
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
                              final controller =
                                  PipOverlayService.getSavedController<
                                    VideoDetailController
                                  >();
                              final plController =
                                  controller?.plPlayerController;
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
                            final controller =
                                PipOverlayService.getSavedController<
                                  VideoDetailController
                                >();
                            final plController = controller?.plPlayerController;
                            final isPlaying =
                                plController?.playerStatus.value ==
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
                              final controller =
                                  PipOverlayService.getSavedController<
                                    VideoDetailController
                                  >();
                              final plController =
                                  controller?.plPlayerController;
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

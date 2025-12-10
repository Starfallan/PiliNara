import 'dart:math';

import 'package:canvas_danmaku/danmaku_controller.dart';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:canvas_danmaku/models/danmaku_item.dart';
import 'package:canvas_danmaku/models/danmaku_option.dart';
import 'package:canvas_danmaku/scroll_danmaku_painter.dart';
import 'package:canvas_danmaku/special_danmaku_painter.dart';
import 'package:canvas_danmaku/static_danmaku_painter.dart';
import 'package:canvas_danmaku/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DanmakuScreen<T> extends StatefulWidget {
  // 创建Screen后返回控制器
  final ValueChanged<DanmakuController<T>> createdController;
  final DanmakuOption option;

  const DanmakuScreen({
    required this.createdController,
    required this.option,
    super.key,
  });

  @override
  State<DanmakuScreen<T>> createState() => _DanmakuScreenState<T>();
}

class _DanmakuScreenState<T> extends State<DanmakuScreen<T>>
    with SingleTickerProviderStateMixin {
  /// 视图宽度
  double _viewWidth = 0;
  double _viewHeight = 0;
  double devicePixelRatio = 1;

  /// 弹幕配置
  DanmakuOption _option = const DanmakuOption();

  /// 滚动弹幕
  final _scrollDanmakuItems = <DanmakuItem<T>>[];

  /// 静态弹幕
  final _staticDanmakuItems = ListValueNotifier(<DanmakuItem<T>>[]);

  /// 高级弹幕
  final _specialDanmakuItems = <DanmakuItem<T>>[];

  /// 弹幕高度
  late double _danmakuHeight;

  /// 弹幕轨道数
  late int _trackCount;

  /// 弹幕轨道位置
  late List<double> _trackYPositions;

  late final _random = Random();

  late final Ticker _ticker;
  late final ValueNotifier<int> _notifier;
  late int _lastTick = 0;

  /// 运行状态
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _option = widget.option;
    DmUtils.updateSelfSendPaint(_option.strokeWidth);

    _danmakuHeight = _textPainter.height;

    _ticker = createTicker(_tick);
    _notifier = ValueNotifier(0);

    widget.createdController(DanmakuController<T>(
      addDanmaku: _addDanmaku,
      updateOption: _updateOption,
      pause: _pause,
      resume: _resume,
      clear: _clear,
      getOption: () => _option,
      isRunning: () => _running,
      findDanmaku: findDanmaku,
      findSingleDanmaku: findSingleDanmaku,
      getViewWidth: () => _viewWidth,
      getViewHeight: () => _viewHeight,
      scrollDanmaku: _scrollDanmakuItems,
      staticDanmaku: _staticDanmakuItems.value,
      specialDanmaku: _specialDanmakuItems,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (devicePixelRatio != this.devicePixelRatio) {
      this.devicePixelRatio = devicePixelRatio;
      for (var item in _scrollDanmakuItems) {
        item.dispose();
      }
      for (var item in _staticDanmakuItems.value) {
        item.dispose();
      }
      for (var item in _specialDanmakuItems) {
        item.dispose();
      }
    }
  }

  int _time = 0;
  void _tick(Duration elapsed) {
    _notifier.value = elapsed.inMilliseconds + _lastTick;
    if (_time++ > 10) {
      _time = 0;
      _lazyTick(_notifier.value);
    }
  }

  TextPainter get _textPainter => TextPainter(
        text: TextSpan(
          text: '弹幕',
          style: TextStyle(
            fontSize: _option.fontSize,
            height: _option.lineHeight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void dispose() {
    _running = false;
    _ticker.dispose();
    _clearDanmakus();
    _staticDanmakuItems.dispose();
    super.dispose();
  }

  void _handleAddDanmaku(
    DanmakuContentItem<T> content,
    bool Function(double, double) canAdd,
  ) {
    bool added = false;

    final paragraph = DmUtils.generateParagraph(
      content: content,
      fontSize: _option.fontSize,
      fontWeight: _option.fontWeight,
    );

    final danmakuWidth = (content.selfSend
            ? paragraph.maxIntrinsicWidth + 4
            : paragraph.maxIntrinsicWidth) +
        _option.strokeWidth;
    final danmakuHeight = paragraph.height + _option.strokeWidth;

    DanmakuItem<T> getItem(double yPos) => DanmakuItem<T>(
        yPosition: yPos,
        xPosition: _viewWidth,
        width: danmakuWidth,
        height: danmakuHeight,
        content: content,
        image: DmUtils.recordDanmakuImage(
          contentParagraph: paragraph,
          content: content,
          fontSize: _option.fontSize,
          fontWeight: _option.fontWeight,
          strokeWidth: _option.strokeWidth,
          devicePixelRatio: devicePixelRatio,
        ));

    for (var i = 0; i < _trackYPositions.length; i++) {
      final yPosition = _trackYPositions[i];

      if (added = canAdd(yPosition, danmakuWidth)) {
        final item = getItem(yPosition);
        if (content.type == DanmakuItemType.scroll) {
          _scrollDanmakuItems.add(item);
        } else {
          if (_running) {
            _staticDanmakuItems.add(item);
          } else {
            _staticDanmakuItems.value.add(item);
          }
        }
        break;
      }

      if (content.type == DanmakuItemType.scroll &&
          i == _trackYPositions.length - 1) {
        if (content.selfSend) {
          added = true;
          _scrollDanmakuItems.add(getItem(_trackYPositions[0]));
          break;
        }

        if (_option.massiveMode) {
          added = true;
          _scrollDanmakuItems.add(getItem(
            _trackYPositions[_random.nextInt(_trackYPositions.length)],
          ));
          break;
        }
      }
    }

    paragraph.dispose();

    if (_running && added) {
      if (!_ticker.isActive) {
        _ticker.start();
      }
    }
  }

  /// 添加弹幕
  void _addDanmaku(DanmakuContentItem<T> content) {
    if (!mounted) {
      return;
    }

    switch (content.type) {
      case DanmakuItemType.scroll:
        if (_option.hideScroll) return;
        _handleAddDanmaku(content, _scrollCanAddToTrack);
        break;
      case DanmakuItemType.top:
        if (_option.hideTop) return;
        _handleAddDanmaku(
          content,
          (yPosition, danmakuWidth) {
            return _topCanAddToTrack(yPosition);
          },
        );
        break;
      case DanmakuItemType.bottom:
        if (_option.hideBottom) return;
        _handleAddDanmaku(
          content,
          (yPosition, danmakuWidth) {
            if (_option.safeArea && yPosition <= _danmakuHeight) {
              return false;
            }
            return _bottomCanAddToTrack(yPosition);
          },
        );
        break;
      case DanmakuItemType.special:
        if (_option.hideSpecial) return;
        _specialDanmakuItems.add(
          DanmakuItem<T>(
              width: 0,
              height: 0,
              content: content,
              image: DmUtils.recordSpecialDanmakuImg(
                content: content as SpecialDanmakuContentItem,
                fontWeight: _option.fontWeight,
                strokeWidth: _option.strokeWidth,
                devicePixelRatio: devicePixelRatio,
              )),
        );
        if (_running) {
          if (!_ticker.isActive) {
            _ticker.start();
          }
        }
        break;
    }
  }

  /// 暂停
  void _pause() {
    if (!mounted) return;
    _running = false;
    if (_ticker.isActive) {
      _lastTick = _notifier.value;
      _ticker.stop();
    }
  }

  /// 恢复
  void _resume() {
    if (!mounted) return;
    _running = true;
    if (!_ticker.isActive) {
      _ticker.start();
    }
    _staticDanmakuItems.refresh();
  }

  /// 清空弹幕
  void _clear() {
    if (!mounted) return;
    _clearDanmakus();
    if (_ticker.isActive) {
      // SchedulerBinding.instance.addPostFrameCallback(
      //   (_) => _ticker.stop(),
      // );
    } else {
      _notifier.refresh();
    }
  }

  /// 更新弹幕设置
  void _updateOption(DanmakuOption option) {
    final lineHeightChanged = option.lineHeight != _option.lineHeight;
    if (lineHeightChanged) {
      _option = option;
      _danmakuHeight = _textPainter.height;
      _calcTracks();
      return;
    }

    final fontSizeChanged = option.fontSize != _option.fontSize;

    final clearScroll = option.hideScroll && !_option.hideScroll;

    final clearParagraph = fontSizeChanged ||
        option.fontWeight != _option.fontWeight ||
        option.strokeWidth != _option.strokeWidth;

    final needRestart = _ticker.isActive && clearScroll && clearParagraph;
    if (needRestart) {
      _lastTick = _notifier.value;
      _ticker.stop();
    }

    /// 需要隐藏弹幕时清理已有弹幕
    if (clearScroll) {
      for (var e in _scrollDanmakuItems) {
        e.dispose();
      }
      _scrollDanmakuItems.clear();
    }

    final clearTop = option.hideTop && !_option.hideTop;
    final clearBottom = option.hideBottom && !_option.hideBottom;
    if (clearTop || clearBottom) {
      _staticDanmakuItems.removeWhere((e) {
        final needRemove =
            (clearTop && e.content.type == DanmakuItemType.top) ||
                (clearBottom && e.content.type == DanmakuItemType.bottom);
        if (needRemove) {
          e.dispose();
        }
        return needRemove;
      });
    }
    if (option.hideSpecial && !_option.hideSpecial) {
      for (var e in _specialDanmakuItems) {
        e.dispose();
      }
      _specialDanmakuItems.clear();
    }

    /// 清理已经存在的 Paragraph 缓存
    if (clearParagraph) {
      DmUtils.updateSelfSendPaint(_option.strokeWidth);
      for (var item in _scrollDanmakuItems) {
        item.dispose();
      }
      for (var item in _staticDanmakuItems.value) {
        item.dispose();
      }
      for (var item in _specialDanmakuItems) {
        item.dispose();
      }
    }

    final areaChanged = option.area != _option.area;
    final safeAreaChanged = option.safeArea != _option.safeArea;
    _option = option;
    if (fontSizeChanged) {
      _danmakuHeight = _textPainter.height;
    }
    if (fontSizeChanged || areaChanged || safeAreaChanged) {
      _calcTracks();
    }

    if (needRestart) {
      _ticker.start();
    } else {
      _notifier.refresh();
      _staticDanmakuItems.refresh();
    }
  }

  void _clearDanmakus() {
    for (var e in _scrollDanmakuItems) {
      e.dispose();
    }
    _scrollDanmakuItems.clear();
    for (var e in _staticDanmakuItems.value) {
      e.dispose();
    }
    _staticDanmakuItems.clear();
    for (var e in _specialDanmakuItems) {
      e.dispose();
    }
    _specialDanmakuItems.clear();
  }

  /// 确定滚动弹幕是否可以添加
  bool _scrollCanAddToTrack(double yPosition, double newDanmakuWidth) {
    for (DanmakuItem item in _scrollDanmakuItems) {
      if (item.yPosition == yPosition) {
        final existingEndPosition = item.xPosition + item.width;
        // 首先保证进入屏幕时不发生重叠，其次保证知道移出屏幕前不与速度慢的弹幕(弹幕宽度较小)发生重叠
        if (_viewWidth - existingEndPosition < 0) {
          return false;
        }
        if (item.width < newDanmakuWidth) {
          if ((1 -
                  ((_viewWidth - item.xPosition) / (item.width + _viewWidth))) >
              ((_viewWidth) / (_viewWidth + newDanmakuWidth))) {
            return false;
          }
        }
      }
    }
    return true;
  }

  /// 确定顶部弹幕是否可以添加
  bool _topCanAddToTrack(double yPosition) {
    for (DanmakuItem item in _staticDanmakuItems.value) {
      if (item.content.type == DanmakuItemType.top &&
          item.yPosition == yPosition) {
        return false;
      }
    }
    return true;
  }

  /// 确定底部弹幕是否可以添加
  bool _bottomCanAddToTrack(double yPosition) {
    for (DanmakuItem item in _staticDanmakuItems.value) {
      if (item.content.type == DanmakuItemType.bottom &&
          item.yPosition == yPosition) {
        return false;
      }
    }
    return true;
  }

  @pragma("vm:prefer-inline")
  void _lazyTick(int tick) {
    // 移除屏幕外滚动弹幕
    _scrollDanmakuItems.removeWhere((item) => item.needRemove(item.expired));
    // 移除静态弹幕
    _staticDanmakuItems.removeWhere((item) => item.needRemove(!item.suspend &&
        item.drawTick != null &&
        (tick - item.drawTick!) >= _option.staticDurationInMilliseconds));
    // 移除高级弹幕
    _specialDanmakuItems.removeWhere((item) => item.needRemove(item.expired));
    // 暂停动画
    if (_scrollDanmakuItems.isEmpty &&
        _specialDanmakuItems.isEmpty &&
        _staticDanmakuItems.value.isEmpty &&
        _ticker.isActive) {
      _lastTick = tick;
      _ticker.stop();
    }
  }

  void _calcTracks() {
    _trackCount = (_viewHeight * _option.area / _danmakuHeight).floor();

    /// 为字幕留出余量
    if (_option.safeArea && _option.area == 1.0) {
      _trackCount = _trackCount - 1;
    }

    _trackYPositions = List<double>.generate(
        _trackCount, (i) => i * _danmakuHeight,
        growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        /// 计算视图宽度
        _viewWidth = constraints.maxWidth;
        final viewHeight = constraints.maxHeight;
        if (_viewHeight != viewHeight) {
          _viewHeight = viewHeight;
          _calcTracks();
        }

        return ClipRect(
          child: IgnorePointer(
            child: Stack(
              children: [
                RepaintBoundary.wrap(
                  ValueListenableBuilder(
                    valueListenable: _notifier,
                    builder: (context, value, child) {
                      return CustomPaint(
                        willChange: _running,
                        painter: ScrollDanmakuPainter(
                          length: _scrollDanmakuItems.length,
                          danmakuItems: _scrollDanmakuItems,
                          durationInMilliseconds:
                              _option.durationInMilliseconds,
                          fontSize: _option.fontSize,
                          fontWeight: _option.fontWeight,
                          strokeWidth: _option.strokeWidth,
                          devicePixelRatio: devicePixelRatio,
                          running: _running,
                          tick: value,
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),
                  0,
                ),
                RepaintBoundary.wrap(
                  ValueListenableBuilder(
                    valueListenable: _staticDanmakuItems,
                    builder: (context, value, child) {
                      return CustomPaint(
                        painter: StaticDanmakuPainter(
                          length: value.length,
                          danmakuItems: value,
                          staticDurationInMilliseconds:
                              _option.staticDurationInMilliseconds,
                          fontSize: _option.fontSize,
                          fontWeight: _option.fontWeight,
                          strokeWidth: _option.strokeWidth,
                          devicePixelRatio: devicePixelRatio,
                          tick: _notifier.value,
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),
                  1,
                ),
                RepaintBoundary.wrap(
                  ValueListenableBuilder(
                    valueListenable: _notifier, // 与滚动弹幕共用控制器
                    builder: (context, value, child) {
                      return CustomPaint(
                        willChange: _running,
                        painter: SpecialDanmakuPainter(
                          length: _specialDanmakuItems.length,
                          danmakuItems: _specialDanmakuItems,
                          fontSize: _option.fontSize,
                          fontWeight: _option.fontWeight,
                          strokeWidth: _option.strokeWidth,
                          devicePixelRatio: devicePixelRatio,
                          running: _running,
                          tick: value,
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),
                  2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Iterable<DanmakuItem<T>> hitDanmaku(
      List<DanmakuItem<T>> danmakuItems, Offset position) sync* {
    if (danmakuItems.isNotEmpty) {
      final dy = position.dy;
      for (var i in danmakuItems.reversed) {
        final double danmakuY0;
        final double danmakuY1;
        if (i.content.type == DanmakuItemType.bottom) {
          danmakuY1 = _viewHeight - i.yPosition;
          danmakuY0 = danmakuY1 - i.height;
        } else {
          assert(i.content.type != DanmakuItemType.special);
          danmakuY0 = i.yPosition;
          danmakuY1 = danmakuY0 + i.height;
        }

        if (danmakuY0 <= dy && dy <= danmakuY1) {
          final dx = position.dx;
          if (i.xPosition <= dx && dx <= i.xPosition + i.width) {
            yield i;
          }
        }
      }
    }
  }

  DanmakuItem<T>? hitSingleDanmaku(
      List<DanmakuItem<T>> danmakuItems, Offset position) {
    if (danmakuItems.isNotEmpty) {
      final dy = position.dy;
      for (var i in danmakuItems.reversed) {
        final double danmakuY0;
        final double danmakuY1;
        if (i.content.type == DanmakuItemType.bottom) {
          danmakuY1 = _viewHeight - i.yPosition;
          danmakuY0 = danmakuY1 - i.height;
        } else {
          assert(i.content.type != DanmakuItemType.special);
          danmakuY0 = i.yPosition;
          danmakuY1 = danmakuY0 + i.height;
        }

        if (danmakuY0 <= dy && dy <= danmakuY1) {
          final dx = position.dx;
          if (i.xPosition <= dx && dx <= i.xPosition + i.width) {
            return i;
          }
        }
      }
    }
    return null;
  }

  Iterable<DanmakuItem<T>> findDanmaku(Offset pos) =>
      hitDanmaku(_staticDanmakuItems.value, pos)
          .followedBy(hitDanmaku(_scrollDanmakuItems, pos));

  DanmakuItem<T>? findSingleDanmaku(Offset pos) =>
      hitSingleDanmaku(_staticDanmakuItems.value, pos) ??
      hitSingleDanmaku(_scrollDanmakuItems, pos);
}

class ListValueNotifier<T> extends ValueNotifier<List<T>> {
  ListValueNotifier(super.value);

  void add(T item) {
    value.add(item);
    notifyListeners();
  }

  void clear() {
    if (value.isNotEmpty) {
      value.clear();
      notifyListeners();
    }
  }

  void removeWhere(bool Function(T element) test) {
    if (value.removeWhereUnsafe(test)) {
      notifyListeners();
    }
  }
}

extension ValueNotifierExt<T> on ValueNotifier<T> {
  @pragma("vm:prefer-inline")
  void refresh() {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
  }
}

extension<E> on List<E> {
  bool removeWhereUnsafe(bool Function(E) test) {
    int write = 0;
    final length = this.length;
    for (int read = 0; read < length; read++) {
      final element = this[read];
      if (!test(element)) {
        if (write < read) this[write] = element;
        write++;
      }
    }
    if (length != write) {
      this.length = write;
      return true;
    }
    return false;
  }
}

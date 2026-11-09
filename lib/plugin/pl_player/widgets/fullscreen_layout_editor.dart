import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_layout.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/player_control_face.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 全屏播放器布局编辑器。
///
/// 编辑器只在原播放器控件外加边框和勾选，控件本身不附带播放业务动作。
class FullscreenLayoutEditor extends StatefulWidget {
  const FullscreenLayoutEditor({
    super.key,
    required this.initial,
    required this.isMobile,
    required this.supportsPip,
    required this.onSave,
    this.title = '视频标题',
    this.removeSafeArea = false,
  });

  final FullscreenLayout initial;
  final bool isMobile;
  final bool supportsPip;
  final Future<void> Function(FullscreenLayout layout) onSave;
  final String title;
  final bool removeSafeArea;

  @override
  State<FullscreenLayoutEditor> createState() => _FullscreenLayoutEditorState();
}

class _FullscreenLayoutEditorState extends State<FullscreenLayoutEditor> {
  late FullscreenLayout _draft = widget.initial;
  bool _saving = false;
  String? _error;
  PlayerLayoutControl? _dragging;
  ({PlayerLayoutControl control, bool after})? _hover;

  Color get _accent {
    final colors = Theme.of(context).colorScheme;
    return colors.brightness == Brightness.light
        ? colors.inversePrimary
        : colors.primary;
  }

  bool _supported(PlayerLayoutControl item) => switch (item) {
    .pin => !widget.isMobile,
    .pip => widget.supportsPip,
    _ => true,
  };

  Future<void> _save() async {
    if (_saving) return;
    final route = ModalRoute.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_draft);
      if (!mounted) return;
      if (route?.isCurrent == true) {
        Navigator.of(context).pop();
      } else if (route?.isActive == true) {
        setState(() => _saving = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }

  void _toggle(PlayerLayoutControl item) {
    if (!_saving) setState(() => _draft = _draft.toggle(item));
  }

  void _move(PlayerLayoutControl item, PlayerLayoutRegion region, int index) {
    if (_saving) return;
    setState(() {
      _draft = _draft.move(item, region, index);
      _hover = null;
    });
  }

  Widget _check(PlayerLayoutControl item, Widget child, {bool feedback = false}) {
    final selected = _draft.shows(item);
    return Semantics(
      key: feedback ? null : ValueKey('layout-${item.name}'),
      label: '显示${item.label}',
      toggled: selected,
      button: true,
      child: Tooltip(
        message: '${selected ? '隐藏' : '显示'}${item.label}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _saving || feedback ? null : () => _toggle(item),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: selected ? 1 : 0.35,
                child: IgnorePointer(child: child),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? Colors.white70 : Colors.white30,
                        ),
                        borderRadius: const BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -5,
                right: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    child: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? _accent : Colors.white70,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(PlayerLayoutControl item, PlayerLayoutRegion region) {
    final vertical = region == .left || region == .right;
    return Builder(
      builder: (slotContext) => DragTarget<PlayerLayoutControl>(
        onWillAcceptWithDetails: (details) =>
            !_saving && details.data != item && details.data.accepts(region),
        onMove: (details) {
          if (!details.data.accepts(region) || details.data == item) return;
          final box = slotContext.findRenderObject()! as RenderBox;
          final offset = box.globalToLocal(details.offset);
          final after = vertical
              ? offset.dy > box.size.height / 2
              : offset.dx > box.size.width / 2;
          final hover = (control: item, after: after);
          if (_hover != hover) setState(() => _hover = hover);
        },
        onLeave: (_) {
          if (_hover?.control == item) setState(() => _hover = null);
        },
        onAcceptWithDetails: (details) => _move(
          details.data,
          region,
          _draft.items(region).indexOf(item) + (_hover?.after == true ? 1 : 0),
        ),
        builder: (context, candidates, rejected) {
          final hover = _hover;
          final face = _check(
            item,
            _face(item),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              LongPressDraggable<PlayerLayoutControl>(
                data: item,
                maxSimultaneousDrags: _saving ? 0 : 1,
                delay: const Duration(milliseconds: 220),
                dragAnchorStrategy: pointerDragAnchorStrategy,
                onDragStarted: () => setState(() => _dragging = item),
                onDragEnd: (_) {
                  if (mounted) {
                    setState(() {
                      _dragging = null;
                      _hover = null;
                    });
                  }
                },
                feedback: Material(
                  color: Colors.transparent,
                  child: Opacity(
                    opacity: 0.9,
                    child: _check(item, _face(item), feedback: true),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.2, child: face),
                child: face,
              ),
              if (candidates.isNotEmpty && hover?.control == item)
                Positioned(
                  left: vertical || !hover!.after ? 0 : null,
                  right: vertical || hover!.after ? 0 : null,
                  top: !vertical || !hover!.after ? 0 : null,
                  bottom: !vertical || hover!.after ? 0 : null,
                  width: vertical ? null : 3,
                  height: vertical ? 3 : null,
                  child: ColoredBox(color: _accent),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _endSlot(PlayerLayoutRegion region) {
    final side = region == .left || region == .right;
    return DragTarget<PlayerLayoutControl>(
      onWillAcceptWithDetails: (details) =>
          !_saving && details.data.accepts(region),
      onAcceptWithDetails: (details) =>
          _move(details.data, region, _draft.items(region).length),
      builder: (context, candidates, rejected) => SizedBox(
        width: side ? 34 : 8,
        height: side ? 34 : 30,
        child: _dragging?.isSide != true && candidates.isEmpty
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: candidates.isEmpty ? Colors.white38 : _accent),
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                ),
              ),
      ),
    );
  }

  Widget _region(PlayerLayoutRegion region) {
    final side = region == .left || region == .right;
    final items = _draft.items(region).where(_supported).toList();
    final children = [
      for (final item in items) _slot(item, region),
      if (items.isEmpty) _endSlot(region),
    ];
    return side
        ? Column(mainAxisSize: MainAxisSize.min, spacing: 20, children: children)
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _face(PlayerLayoutControl item) => PlayerControlFace(
    control: item,
    bottomWidth: MediaQuery.sizeOf(context).aspectRatio > 1 ? 42 : 35,
  );

  Widget _standalone(PlayerLayoutControl item) => _check(
    item,
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: _face(item),
    ),
  );

  Widget _fixed(Widget child, String label, {double width = 42}) => Tooltip(
    message: '$label（固定）',
    child: SizedBox(width: width, height: 34, child: child),
  );

  Widget _header() {
    final header = _draft.items(PlayerLayoutRegion.header);
    final right = <Widget>[
      _standalone(PlayerLayoutControl.battery),
      const SizedBox(width: 2),
      _standalone(PlayerLayoutControl.clock),
      for (final item in header.take(3).where(_supported)) _slot(item, PlayerLayoutRegion.header),
      _fixed(const Icon(Icons.comment_outlined, size: 19, color: Colors.white), '发弹幕'),
      _fixed(const Icon(CustomIcons.dm_on, size: 20, color: Colors.white), '弹幕开关'),
      _fixed(const Icon(CustomIcons.dm_settings, size: 20, color: Colors.white), '弹幕设置'),
      for (final item in header.skip(3).where(_supported)) _slot(item, PlayerLayoutRegion.header),
      _fixed(const Icon(Icons.more_vert_outlined, size: 19, color: Colors.white), '更多'),
    ];
    return PlayerBar(
      left: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _fixed(const Icon(FontAwesomeIcons.arrowLeft, size: 15, color: Colors.white), '返回'),
          _fixed(const Icon(FontAwesomeIcons.house, size: 15, color: Colors.white), '返回主页'),
        ],
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      right: Row(mainAxisSize: MainAxisSize.min, children: right),
    );
  }

  Widget _actions() => Align(
    alignment: Alignment.centerRight,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in _draft.items(PlayerLayoutRegion.actions).where(_supported))
          _slot(item, PlayerLayoutRegion.actions),
      ],
    ),
  );

  Widget _center() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 76),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '点击勾选显示或隐藏，长按拖动调整同区顺序\n锁定与截图可拖至左侧或右侧',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 8),
          const Text(
            '因视频属性不同，部分功能可能不会展示在屏幕上',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _saving ? null : () => setState(() {
                  _draft = FullscreenLayout.defaults(isMobile: widget.isMobile);
                  _error = null;
                }),
                child: const Text('恢复默认'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '完成编辑'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _progress() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 7),
    child: ProgressBar(
      progress: 38,
      total: 102,
      buffered: 64,
      barHeight: 3.5,
      thumbRadius: 7,
      baseBarColor: const Color(0x33FFFFFF),
      minHeight: widget.isMobile ? null : 23.5,
      progressBarColor: _accent,
      bufferedBarColor: _accent.withValues(alpha: 0.4),
      thumbColor: _accent,
      thumbGlowColor: _accent.withAlpha(80),
    ),
  );

  Widget _time() => DefaultTextStyle(
    style: TextStyle(
      color: Colors.white,
      fontFamily: 'Monospace',
      fontSize: widget.isMobile ? 10 : 12,
      height: 1.4,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('00:38'),
        Text('01:42', style: TextStyle(color: Color(0xFFD0D0D0))),
      ],
    ),
  );

  Widget _bottom() {
    final controls = _draft.items(PlayerLayoutRegion.bottom).where(_supported).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: PlayerBar(
        left: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fixed(const Center(child: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: AlwaysStoppedAnimation(0),
              size: 20,
              color: Colors.white,
            )), '播放'),
            _time(),
            _fixed(const Icon(Icons.skip_previous, size: 22, color: Colors.white), '上一集'),
            _fixed(const Icon(Icons.skip_next, size: 22, color: Colors.white), '下一集'),
          ],
        ),
        right: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in controls) _slot(item, PlayerLayoutRegion.bottom),
            _fixed(const Icon(Icons.fullscreen_exit, size: 24, color: Colors.white), '退出全屏'),
          ],
        ),
      ),
    );
  }

  Widget _preview() => Stack(
    children: [
      Positioned.fill(child: _center()),
      Positioned(
        top: 12,
        left: 0,
        right: 0,
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth.clamp(600, double.infinity),
              child: Stack(
                children: [
                  Column(children: [_header(), const SizedBox(height: 6), _actions()]),
                  Positioned(
                    top: 29,
                    left: 84,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _standalone(PlayerLayoutControl.online),
                        _standalone(PlayerLayoutControl.dmCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 34),
          child: _region(PlayerLayoutRegion.left),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 34),
          child: _region(PlayerLayoutRegion.right),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Column(mainAxisSize: MainAxisSize.min, children: [_progress(), _bottom()]),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (event is KeyDownEvent && !_saving) Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ViewSafeArea(
          left: !widget.removeSafeArea,
          right: !widget.removeSafeArea,
          child: _preview(),
        ),
      ),
    ),
  );
}

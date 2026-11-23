import 'package:PiliPlus/pages/video/models/pane_geometry.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

class VideoPaneResizer extends StatefulWidget {
  const VideoPaneResizer({
    super.key,
    required this.enabled,
    required this.automaticWidth,
    required this.minRightWidth,
    required this.hasIntro,
    required this.readRatio,
    required this.saveRatio,
    required this.onSaveError,
    required this.builder,
  });

  final bool enabled;
  final double automaticWidth;
  final double minRightWidth;
  final bool hasIntro;
  final double? Function() readRatio;
  final Future<void> Function(double?) saveRatio;
  final VoidCallback onSaveError;
  final Widget Function(double width, Size size, double gap, Widget divider) builder;

  @override
  State<VideoPaneResizer> createState() => VideoPaneResizerState();
}

class VideoPaneResizerState extends State<VideoPaneResizer> {
  late double? _savedRatio = widget.readRatio();
  double? _draftRatio;
  bool _editing = false;
  bool _dragging = false;
  bool _hovered = false;
  bool _pressed = false;
  bool _saving = false;
  double _dragOrigin = 0;
  double _dragWidth = 0;
  final Set<int> _pointers = {};
  bool _interrupted = false;
  VideoPaneGeometry? _geometry;
  DialogRoute<void>? _dialog;

  bool get canAdjust => mounted && widget.enabled &&
      (_geometry?.canResize ?? false);
  double? get _ratio => _editing ? _draftRatio : _savedRatio;

  @override
  void didUpdateWidget(VideoPaneResizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _cancelEditing();
    if (!_editing && !_saving) _savedRatio = widget.readRatio();
  }

  void cancelEditing() {
    if (mounted) setState(_cancelEditing);
  }

  void _cancelEditing() {
    _editing = false;
    _dragging = false;
    _pressed = false;
    _interrupted = true;
    final dialog = _dialog;
    _dialog = null;
    if (dialog != null) {
      // 可在布局或 dispose 中触发；只移除自己的 route，不关闭后来打开的页面。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = dialog.navigator;
        if (navigator != null && dialog.isActive) navigator.removeRoute(dialog);
      });
    }
  }

  @override
  void dispose() {
    _cancelEditing();
    super.dispose();
  }

  Future<void> _save(double? ratio) async {
    _saving = true;
    try {
      await widget.saveRatio(ratio);
      if (mounted) setState(() => _savedRatio = ratio);
    } finally {
      _saving = false;
    }
  }

  Future<void> _finishDrag() async {
    if (!_dragging) return;
    final ratio = _draftRatio;
    setState(() {
      _dragging = false;
      _pressed = false;
    });
    try {
      await _save(ratio);
    } catch (_) {
      if (mounted) widget.onSaveError();
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> showRatioDialog() async {
    if (!canAdjust || _dialog != null || _saving || _dragging) return;
    final geometry = _geometry!;
    setState(() {
      _savedRatio = widget.readRatio();
      _draftRatio = _savedRatio;
      _editing = true;
    });
    late final DialogRoute<void> dialog;
    final navigator = Navigator.of(context, rootNavigator: true);
    dialog = DialogRoute<void>(
      context: context,
      requestFocus: true,
      barrierColor: Colors.black12,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (context) => _PaneRatioDialog(
        geometry: geometry,
        initialRatio: _savedRatio,
        onPreview: (ratio) {
          if (mounted && identical(_dialog, dialog)) {
            setState(() => _draftRatio = ratio);
          }
        },
        onSave: (ratio) async {
          if (!canAdjust || !identical(_dialog, dialog)) return;
          await _save(ratio);
          if (dialog.isCurrent) dialog.navigator?.pop();
        },
      ),
    );
    _dialog = dialog;
    try {
      await navigator.push(dialog);
    } finally {
      if (mounted && identical(_dialog, dialog)) {
        setState(() {
          _dialog = null;
          _editing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final geometry = VideoPaneGeometry(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        automaticWidth: widget.automaticWidth,
        minRightWidth: widget.minRightWidth,
        minIntroHeight: widget.hasIntro ? 120 : 0,
      );
      if (_geometry case final previous?) {
        if (!geometry.sameBounds(previous)) _cancelEditing();
      }
      _geometry = geometry;
      final active = canAdjust;
      if (!active) _hovered = false;
      final width = active ? geometry.leftWidth(_ratio) : widget.automaticWidth;
      final colorScheme = Theme.of(context).colorScheme;
      final highlighted = _hovered || _pressed || _dragging;
      final divider = SizedBox(
        width: active ? VideoPaneGeometry.dividerWidth : 0,
        height: constraints.maxHeight,
        child: active ? Semantics(
          label: '页面比例',
          value: '左侧 ${(width / geometry.contentWidth * 100).round()}%',
          onTap: showRatioDialog,
          child: Tooltip(
            message: '拖动调整页面比例',
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: Listener(
                onPointerDown: (event) {
                  if (_pointers.isEmpty) _interrupted = false;
                  _pointers.add(event.pointer);
                  if (_pointers.length > 1) cancelEditing();
                },
                onPointerUp: (event) => _pointers.remove(event.pointer),
                onPointerCancel: (event) {
                  _pointers.remove(event.pointer);
                  cancelEditing();
                },
                child: GestureDetector(
                  key: const ValueKey('video-pane-divider'),
                  behavior: HitTestBehavior.opaque,
                  supportedDevices: const {
                    PointerDeviceKind.mouse, PointerDeviceKind.touch,
                    PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus,
                  },
                  onHorizontalDragDown: (_) {
                    if (!_saving) setState(() => _pressed = true);
                  },
                  onHorizontalDragStart: (details) {
                    if (_saving || _dialog != null || _interrupted) return;
                    setState(() {
                      _editing = _dragging = true;
                      _draftRatio = geometry.ratioForWidth(width);
                      _dragOrigin = details.globalPosition.dx;
                      _dragWidth = width;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    if (!_dragging) return;
                    setState(() {
                      _draftRatio = geometry.ratioForWidth(
                        _dragWidth + details.globalPosition.dx - _dragOrigin,
                      );
                    });
                  },
                  onHorizontalDragEnd: (_) => _finishDrag(),
                  onHorizontalDragCancel: () {
                    if (!_saving) setState(_cancelEditing);
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 1,
                        color: highlighted ? colorScheme.primary :
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      Container(
                        width: 3,
                        height: 28,
                        decoration: BoxDecoration(
                          color: highlighted ? colorScheme.primary : colorScheme.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ) : null,
      );
      return widget.builder(
        width, constraints.biggest,
        active ? VideoPaneGeometry.dividerWidth : 0, divider,
      );
    },
  );
}

class _PaneRatioDialog extends StatefulWidget {
  const _PaneRatioDialog({
    required this.geometry,
    required this.initialRatio,
    required this.onPreview,
    required this.onSave,
  });

  final VideoPaneGeometry geometry;
  final double? initialRatio;
  final ValueChanged<double?> onPreview;
  final Future<void> Function(double?) onSave;

  @override
  State<_PaneRatioDialog> createState() => _PaneRatioDialogState();
}

class _PaneRatioDialogState extends State<_PaneRatioDialog> {
  late double? _ratio = widget.initialRatio;
  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    setState(() { _saving = true; _failed = false; });
    try {
      await widget.onSave(_ratio);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final geometry = widget.geometry;
    final value = geometry.leftWidth(_ratio) / geometry.contentWidth;
    final percent = (value * 100).round();
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        alignment: Alignment.bottomRight,
        scrollable: true,
        title: const Text('页面比例'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_ratio == null ? '自动 · ' : ''}左侧 $percent% · 右侧 ${100 - percent}%'),
              Slider(
                autofocus: true,
                min: geometry.minRatio,
                max: geometry.maxRatio,
                value: value,
                label: '$percent%',
                semanticFormatterCallback: (value) => '左侧 ${(value * 100).round()}%',
                onChanged: _saving ? null : (value) {
                  setState(() => _ratio = value);
                  widget.onPreview(value);
                },
              ),
              const Text('调节范围受窗口大小限制，保留简介和右侧内容的显示空间。'),
              if (_failed) Text('保存失败，请重试',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () {
              setState(() => _ratio = null);
              widget.onPreview(null);
            },
            child: const Text('恢复自动'),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中' : '完成'),
          ),
        ],
      ),
    );
  }
}

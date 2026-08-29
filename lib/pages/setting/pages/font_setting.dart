import 'dart:io';

import 'package:PiliPlus/common/widgets/flutter/popup_menu.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/danmaku/danmaku_font_sync_mode.dart';
import 'package:PiliPlus/utils/app_font.dart';
import 'package:PiliPlus/utils/danmaku_font.dart';
import 'package:PiliPlus/utils/extension/box_ext.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 弹幕字体来源（下拉内置项）；已导入的独立字体以下拉字符串值表示
enum DanmakuFontSource { global, system }

class FontSettingPage extends StatefulWidget {
  const FontSettingPage({super.key});

  @override
  State<FontSettingPage> createState() => _FontSettingPageState();
}

class _FontSettingPageState extends State<FontSettingPage> {
  /// 字体选择："系统默认" 用空串表示
  static const String _systemFontSentinel = '';

  String? _selectedFont = Pref.appFont;
  int _selectedWeight = Pref.appFontWeight;
  double _selectedScale = Pref.defaultTextScale;

  /// 弹幕字体选择：DanmakuFontSource 或已导入字体的字体族名
  Object? _selectedDanmaku = _initialDanmakuSelection();

  late final List<String> _fonts;
  late ColorScheme colorScheme;

  static Object? _initialDanmakuSelection() {
    if (!Pref.enableCustomDanmakuFont) {
      return DanmakuFontSource.system;
    }
    return switch (Pref.danmakuFontSyncMode) {
      DanmakuFontSyncMode.system => DanmakuFontSource.system,
      DanmakuFontSyncMode.custom =>
        Pref.customDanmakuFontFamily ?? DanmakuFontSource.global,
      _ => DanmakuFontSource.global,
    };
  }

  @override
  void initState() {
    super.initState();
    _fonts = FontUtils.getFont().toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorScheme = ColorScheme.of(context);
  }

  /// 弹幕字体菜单显示名（跟随应用字体 / 系统默认弹幕字体 / 导入字体名）
  String get _danmakuLabel => switch (_selectedDanmaku) {
    DanmakuFontSource.global => '跟随应用字体',
    DanmakuFontSource.system => '系统默认弹幕字体',
    String family => DanmakuFont.currentFontName ?? family,
    _ => '系统默认弹幕字体',
  };

  /// 弹幕字体实际生效的 fontFamily（跟随应用字体时取应用字体；系统默认为 null）
  String? get _danmakuFontFamily => switch (_selectedDanmaku) {
    DanmakuFontSource.global => _selectedFont,
    DanmakuFontSource.system => null,
    String family => family,
    _ => null,
  };

  void _saveFontSetting() {
    final (enable, mode) = switch (_selectedDanmaku) {
      DanmakuFontSource.global => (true, DanmakuFontSyncMode.global),
      String _ => (true, DanmakuFontSyncMode.custom),
      _ => (false, DanmakuFontSyncMode.system),
    };

    GStorage.setting.putAllNE({
      SettingBoxKey.appFont: _selectedFont,
      SettingBoxKey.appFontWeight: _selectedWeight,
      SettingBoxKey.defaultTextScale: _selectedScale,
      SettingBoxKey.enableCustomDanmakuFont: enable,
      SettingBoxKey.danmakuFontSyncMode: mode.index,
    });

    Get
      ..back()
      ..updateMyAppTheme();
  }

  /// ref [Typography._withPlatform]
  static final String? _kFontFamily = (switch (defaultTargetPlatform) {
    .iOS => Typography.whiteCupertino,
    .android || .fuchsia => Typography.whiteMountainView,
    .windows => Typography.whiteRedmond,
    .macOS => Typography.whiteRedwoodCity,
    .linux => Typography.whiteHelsinki,
  }).bodyMedium?.fontFamily;

  Future<void> _importAppFont() async {
    SmartDialog.showLoading();
    try {
      final font = await AppFont.pickFonts();
      if (font != null) {
        setState(() => _selectedFont = font);
      }
    } catch (e) {
      SmartDialog.showToast('字体加载失败: $e');
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> _deleteAppFont() async {
    await AppFont.clearFonts();
    setState(() => _selectedFont = null);
  }

  Future<void> _importDanmakuFont() async {
    SmartDialog.showLoading();
    try {
      if (await DanmakuFont.pickAndApply()) {
        setState(() => _selectedDanmaku = Pref.customDanmakuFontFamily);
      }
    } catch (e) {
      SmartDialog.showToast('字体加载失败: $e');
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> _deleteDanmakuFont() async {
    final family = Pref.customDanmakuFontFamily;
    await DanmakuFont.clear();
    setState(() {
      if (_selectedDanmaku == family || family == null) {
        _selectedDanmaku = DanmakuFontSource.global;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomFonts = AppFont.customFonts.isNotEmpty;
    final danmakuImportedFamily = Pref.customDanmakuFontFamily;
    return SimpleScaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _selectedFont = null;
              _selectedWeight = -1;
              _selectedScale = 1;
            }),
            child: const Text('重置'),
          ),
          TextButton(
            onPressed: _saveFontSetting,
            child: const Text('确定'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      'abcdefghijklmnopqrstuvwxyz\n'
                      'ABCDEFGHIJKLMNOPQRSTUVWXYZ\n'
                      '1234567890.:,;\'"(!?)+-*/=\n'
                      '${Platform.isWindows
                          ? "中国智造，惠及全球"
                          : Platform.isMacOS || Platform.isIOS
                          ? "汉体书写信息技术标准相容"
                          : "我能吞下玻璃而不伤身体"}\n\n'
                      '注：部分字体可能无法应用',
                      style: TextStyle(
                        fontFamily: _selectedFont ?? _kFontFamily,
                        fontWeight: _selectedWeight == -1
                            ? null
                            : FontWeight.values[_selectedWeight],
                        fontSize: 14 * _selectedScale,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '弹幕预览：前方高能反应 666',
                      style: TextStyle(
                        fontFamily: _danmakuFontFamily,
                        fontSize: 14 * _selectedScale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildItem(
              Row(
                children: [
                  const Text('字体：', style: TextStyle(fontWeight: .bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StaticPopupMenuButton<String>(
                      initialValue: _selectedFont ?? _systemFontSentinel,
                      borderRadius: BorderRadius.circular(8),
                      itemBuilder: (context) => [
                        for (final entry in AppFont.customFonts.entries)
                          PopupMenuItem<String>(
                            value: entry.key,
                            height: 40,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key.split('/').last,
                                    style: TextStyle(fontFamily: entry.key),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _actionIcon(
                                  tooltip: '移除字体',
                                  icon: Icons.clear,
                                  onPressed: () {
                                    AppFont.removeFont(entry.key);
                                    if (_selectedFont == entry.key) {
                                      _selectedFont = null;
                                    }
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (hasCustomFonts)
                          const CustomPopupMenuDivider(height: 8),
                        PopupMenuItem<String>(
                          value: _systemFontSentinel,
                          height: 40,
                          child: const Text('系统默认'),
                        ),
                        for (final font in _fonts)
                          PopupMenuItem<String>(
                            value: font,
                            height: 40,
                            child: Text(
                              font,
                              style: TextStyle(fontFamily: font),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onSelected: (value) => setState(
                        () => _selectedFont = value.isEmpty
                            ? null
                            : value,
                      ),
                      child: _selectorLabel(
                        text: _selectedFont ?? '系统默认',
                        fontFamily: _selectedFont,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _actionIcon(
                    tooltip: '导入字体文件（TTF/OTF）',
                    icon: Icons.file_open_outlined,
                    onPressed: _importAppFont,
                  ),
                  if (hasCustomFonts)
                    _actionIcon(
                      tooltip: '删除所有已导入字体',
                      icon: Icons.delete_outline,
                      onPressed: _deleteAppFont,
                    ),
                ],
              ),
            ),
            _buildItem(
              Row(
                children: [
                  const Text('字重：', style: TextStyle(fontWeight: .bold)),
                  const SizedBox(
                    width: 40,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '默认/\n'),
                          TextSpan(
                            text: 'w100',
                            style: TextStyle(fontWeight: .w100),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      padding: .zero,
                      value: _selectedWeight.toDouble(),
                      min: -1,
                      max: 8,
                      divisions: 9,
                      label: _selectedWeight == -1
                          ? '默认'
                          : 'w${(_selectedWeight + 1) * 100}',
                      onChanged: (value) {
                        setState(() => _selectedWeight = value.toInt());
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 50,
                    child: Align(
                      alignment: .centerRight,
                      child: Text('w900', style: TextStyle(fontWeight: .w900)),
                    ),
                  ),
                ],
              ),
            ),
            _buildItem(
              Row(
                children: [
                  const Text('字号：', style: TextStyle(fontWeight: .bold)),
                  const SizedBox(
                    width: 40,
                    child: Text('小', style: TextStyle(fontSize: 11.9)),
                  ),
                  Expanded(
                    child: Slider(
                      padding: .zero,
                      value: _selectedScale,
                      min: 0.85,
                      max: 1.6,
                      divisions: 15,
                      secondaryTrackValue: 1,
                      label: _selectedScale == 1.0
                          ? '默认'
                          : _selectedScale.toStringAsFixed(2),
                      onChanged: (value) =>
                          setState(() => _selectedScale = value.toPrecision(2)),
                    ),
                  ),
                  const SizedBox(
                    width: 50,
                    child: Align(
                      alignment: .centerRight,
                      child: Text('大', style: TextStyle(fontSize: 22.4)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.subtitles_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '弹幕字体',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: .bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            _buildItem(
              Row(
                children: [
                  const Text('弹幕：', style: TextStyle(fontWeight: .bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StaticPopupMenuButton<Object>(
                      initialValue: _selectedDanmaku,
                      borderRadius: BorderRadius.circular(8),
                      itemBuilder: (context) => [
                        if (danmakuImportedFamily != null) ...[
                          PopupMenuItem<Object>(
                            value: danmakuImportedFamily,
                            height: 40,
                            child: Text(
                              '${DanmakuFont.currentFontName ?? danmakuImportedFamily}（导入）',
                              style: TextStyle(
                                fontFamily: danmakuImportedFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const CustomPopupMenuDivider(height: 8),
                        ],
                        const PopupMenuItem<Object>(
                          value: DanmakuFontSource.global,
                          height: 40,
                          child: Text('跟随应用字体'),
                        ),
                        const PopupMenuItem<Object>(
                          value: DanmakuFontSource.system,
                          height: 40,
                          child: Text('系统默认弹幕字体'),
                        ),
                      ],
                      onSelected: (value) => setState(
                        () => _selectedDanmaku = value,
                      ),
                      child: _selectorLabel(text: _danmakuLabel),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _actionIcon(
                    tooltip: '导入弹幕字体文件（TTF/OTF）',
                    icon: Icons.file_open_outlined,
                    onPressed: _importDanmakuFont,
                  ),
                  if (danmakuImportedFamily != null)
                    _actionIcon(
                      tooltip: '删除已导入弹幕字体',
                      icon: Icons.delete_outline,
                      onPressed: _deleteDanmakuFont,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 当前选中字体的显示名（字体/弹幕共用）
  Widget _selectorLabel({required String text, String? fontFamily}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontFamily: fontFamily, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  /// 紧凑型操作按钮（导入/删除），40x40 命中区与列表行高匹配
  Widget _actionIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      onPressed: onPressed,
    );
  }

  Widget _buildItem(Widget child) {
    return Container(
      padding: const .symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
        ),
      ),
      child: child,
    );
  }
}

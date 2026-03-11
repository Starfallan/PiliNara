import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';

class DanmakuMergeSettingPage extends StatefulWidget {
  const DanmakuMergeSettingPage({super.key});

  @override
  State<DanmakuMergeSettingPage> createState() =>
      _DanmakuMergeSettingPageState();
}

class _DanmakuMergeSettingPageState extends State<DanmakuMergeSettingPage> {
  static const List<_MergePreset> _distancePresets = <_MergePreset>[
    _MergePreset(value: 0, label: '禁用'),
    _MergePreset(value: 3, label: '轻微 (≤3)'),
    _MergePreset(value: 5, label: '中等 (≤5)'),
    _MergePreset(value: 8, label: '强力 (≤8)'),
  ];

  static const List<_MergePreset> _cosinePresets = <_MergePreset>[
    _MergePreset(value: 101, label: '禁用'),
    _MergePreset(value: 60, label: '轻微 (60%)'),
    _MergePreset(value: 45, label: '中等 (45%)'),
    _MergePreset(value: 30, label: '强力 (30%)'),
  ];

  late bool _mergeDanmaku;
  late double _windowSeconds;
  late int _maxDistance;
  late int _maxCosine;
  late bool _usePinyin;
  late bool _crossMode;
  late bool _skipSubtitle;
  late bool _skipAdvanced;
  late bool _skipBottom;
  late bool _markAtTail;
  late double _markThreshold;
  late double _enlargeThreshold;
  late double _enlargeLogBase;

  @override
  void initState() {
    super.initState();
    _mergeDanmaku = Pref.mergeDanmaku;
    _windowSeconds = Pref.mergeDanmakuWindowSeconds.toDouble();
    _maxDistance = _normalizePresetValue(
      Pref.mergeDanmakuMaxDistance,
      _distancePresets,
    );
    _maxCosine = _normalizePresetValue(
      Pref.mergeDanmakuMaxCosine,
      _cosinePresets,
    );
    _usePinyin = Pref.mergeDanmakuUsePinyin;
    _crossMode = Pref.mergeDanmakuCrossMode;
    _skipSubtitle = Pref.mergeDanmakuSkipSubtitle;
    _skipAdvanced = Pref.mergeDanmakuSkipAdvanced;
    _skipBottom = Pref.mergeDanmakuSkipBottom;
    _markAtTail = Pref.mergeDanmakuMarkAtTail;
    _markThreshold = Pref.mergeDanmakuMarkThreshold.toDouble();
    _enlargeThreshold = Pref.danmakuEnlargeThreshold.toDouble();
    _enlargeLogBase = Pref.danmakuEnlargeLogBase.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('弹幕合并')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SwitchListTile(
            title: const Text('启用合并弹幕'),
            subtitle: const Text('在时间窗口内合并相似弹幕'),
            value: _mergeDanmaku,
            onChanged: (value) => setState(() => _mergeDanmaku = value),
          ),
          _SectionTitle('基础设置', theme),
          ListTile(
            title: const Text('时间阈值'),
            subtitle: Text('合并时间差在 ${_windowSeconds.round()} 秒以内的相似弹幕'),
            trailing: Text(
              '${_windowSeconds.round()}s',
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: _windowSeconds,
              min: 5,
              max: 40,
              divisions: 35,
              label: '${_windowSeconds.round()}',
              onChanged: (value) => setState(() => _windowSeconds = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '时间窗越长，越容易合并跨场景刷屏弹幕，但计算量也会增加。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          _SectionTitle('高级选项', theme),
          ListTile(
            title: const Text('编辑距离合并阈值'),
            subtitle: Text(
              _maxDistance == 0
                  ? '禁用字符频次差合并，仅保留其他相似度判定'
                  : '根据编辑距离判断不完全一致但内容接近的弹幕',
            ),
            trailing: _PresetDropdown(
              value: _maxDistance,
              presets: _distancePresets,
              onChanged: (value) => setState(() => _maxDistance = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '较高阈值能更积极地吞并错别字、少量漏字或重复字符弹幕。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          ListTile(
            title: const Text('词频向量合并阈值'),
            subtitle: Text(
              _maxCosine > 100
                  ? '禁用 2-Gram 词频向量相似判定'
                  : '根据 2-Gram 词频向量夹角判断内容类似的弹幕',
            ),
            trailing: _PresetDropdown(
              value: _maxCosine,
              presets: _cosinePresets,
              onChanged: (value) => setState(() => _maxCosine = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '阈值越低越容易命中，越高则越严格；禁用后只依赖前面的规则。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('识别谐音弹幕'),
            subtitle: const Text('将文本转换为拼音后再进行一次相似匹配'),
            value: _usePinyin,
            onChanged: (value) => setState(() => _usePinyin = value),
          ),
          _SectionTitle('例外设置', theme),
          SwitchListTile(
            title: const Text('合并不同类型的弹幕'),
            subtitle: const Text('关闭后，底部/顶部/滚动弹幕不会互相合并'),
            value: _crossMode,
            onChanged: (value) => setState(() => _crossMode = value),
          ),
          SwitchListTile(
            title: const Text('跳过字幕弹幕'),
            value: _skipSubtitle,
            onChanged: (value) => setState(() => _skipSubtitle = value),
          ),
          SwitchListTile(
            title: const Text('跳过高级弹幕'),
            value: _skipAdvanced,
            onChanged: (value) => setState(() => _skipAdvanced = value),
          ),
          SwitchListTile(
            title: const Text('跳过底部弹幕'),
            value: _skipBottom,
            onChanged: (value) => setState(() => _skipBottom = value),
          ),
          _SectionTitle('显示设置', theme),
          ListTile(
            title: const Text('数量标记位置'),
            subtitle: Text(_markAtTail ? '显示在弹幕尾部' : '显示在弹幕开头'),
            trailing: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('开头')),
                ButtonSegment<bool>(value: true, label: Text('尾部')),
              ],
              selected: {_markAtTail},
              onSelectionChanged: (selection) {
                setState(() => _markAtTail = selection.first);
              },
            ),
          ),
          ListTile(
            title: const Text('数量标记门槛'),
            subtitle: Text('仅当数量大于 ${_markThreshold.round()} 时显示标记'),
            trailing: Text(
              '> ${_markThreshold.round()}',
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: _markThreshold,
              min: 1,
              max: 20,
              divisions: 19,
              label: '${_markThreshold.round()}',
              onChanged: (value) => setState(() => _markThreshold = value),
            ),
          ),
          ListTile(
            title: const Text('字体放大门槛'),
            subtitle: Text('重复 ${_enlargeThreshold.round()} 条以上开始放大'),
            trailing: Text(
              '${_enlargeThreshold.round()}',
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: _enlargeThreshold,
              min: 2,
              max: 20,
              divisions: 18,
              label: '${_enlargeThreshold.round()}',
              onChanged: (value) => setState(() => _enlargeThreshold = value),
            ),
          ),
          ListTile(
            title: const Text('放大速度'),
            subtitle: Text('对数底数 ${_enlargeLogBase.round()}（越小放大越快）'),
            trailing: Text(
              '${_enlargeLogBase.round()}',
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: _enlargeLogBase,
              min: 3,
              max: 10,
              divisions: 7,
              label: '${_enlargeLogBase.round()}',
              onChanged: (value) => setState(() => _enlargeLogBase = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    GStorage.setting.put(SettingBoxKey.mergeDanmaku, _mergeDanmaku);
    GStorage.setting.put(
      SettingBoxKey.mergeDanmakuWindowSeconds,
      _windowSeconds.round(),
    );
    GStorage.setting.put(SettingBoxKey.mergeDanmakuMaxDistance, _maxDistance);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuMaxCosine, _maxCosine);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuUsePinyin, _usePinyin);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuCrossMode, _crossMode);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuSkipSubtitle, _skipSubtitle);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuSkipAdvanced, _skipAdvanced);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuSkipBottom, _skipBottom);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuMarkAtTail, _markAtTail);
    GStorage.setting.put(
      SettingBoxKey.mergeDanmakuMarkThreshold,
      _markThreshold.round(),
    );
    GStorage.setting.put(
      SettingBoxKey.danmakuEnlargeThreshold,
      _enlargeThreshold.round(),
    );
    GStorage.setting.put(
      SettingBoxKey.danmakuEnlargeLogBase,
      _enlargeLogBase.round(),
    );
    Navigator.of(context).pop(true);
  }

  static int _normalizePresetValue(int value, List<_MergePreset> presets) {
    return presets.any((preset) => preset.value == value)
        ? value
        : presets.first.value;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PresetDropdown extends StatelessWidget {
  const _PresetDropdown({
    required this.value,
    required this.presets,
    required this.onChanged,
  });

  final int value;
  final List<_MergePreset> presets;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        items: presets
            .map(
              (preset) => DropdownMenuItem<int>(
                value: preset.value,
                child: Text(preset.label),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

class _MergePreset {
  const _MergePreset({
    required this.value,
    required this.label,
  });

  final int value;
  final String label;
}

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
  late bool _mergeDanmaku;
  late double _windowSeconds;
  late bool _crossMode;
  late bool _skipSubtitle;
  late bool _skipAdvanced;
  late bool _skipBottom;
  late double _enlargeThreshold;
  late double _enlargeLogBase;

  @override
  void initState() {
    super.initState();
    _mergeDanmaku = Pref.mergeDanmaku;
    _windowSeconds = Pref.mergeDanmakuWindowSeconds.toDouble();
    _crossMode = Pref.mergeDanmakuCrossMode;
    _skipSubtitle = Pref.mergeDanmakuSkipSubtitle;
    _skipAdvanced = Pref.mergeDanmakuSkipAdvanced;
    _skipBottom = Pref.mergeDanmakuSkipBottom;
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
    GStorage.setting.put(SettingBoxKey.mergeDanmakuCrossMode, _crossMode);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuSkipSubtitle, _skipSubtitle);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuSkipAdvanced, _skipAdvanced);
    GStorage.setting.put(SettingBoxKey.mergeDanmakuSkipBottom, _skipBottom);
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

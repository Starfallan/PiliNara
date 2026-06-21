import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MergeDanmakuDialog extends StatefulWidget {
  const MergeDanmakuDialog({super.key});

  @override
  State<MergeDanmakuDialog> createState() => _MergeDanmakuDialogState();
}

class _MergeDanmakuDialogState extends State<MergeDanmakuDialog> {
  late bool _mergeDanmaku;
  late double _enlargeThreshold;
  late double _enlargeLogBase;

  @override
  void initState() {
    super.initState();
    _mergeDanmaku = Pref.mergeDanmaku;
    _enlargeThreshold = Pref.danmakuEnlargeThreshold.toDouble();
    _enlargeLogBase = Pref.danmakuEnlargeLogBase.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('合并弹幕设置'),
      contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('启用合并弹幕'),
              subtitle: const Text('合并一段时间内获取到的相同弹幕'),
              value: _mergeDanmaku,
              onChanged: (value) {
                setState(() {
                  _mergeDanmaku = value;
                });
              },
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('字体放大门槛'),
              subtitle: Text('重复 ${_enlargeThreshold.round()} 条以上开始放大'),
              trailing: Text(
                '${_enlargeThreshold.round()}',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
                onChanged: (value) {
                  setState(() {
                    _enlargeThreshold = value;
                  });
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('放大速度'),
              subtitle: Text('对数底数 ${_enlargeLogBase.round()}（越小放大越快）'),
              trailing: Text(
                '${_enlargeLogBase.round()}',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
                onChanged: (value) {
                  setState(() {
                    _enlargeLogBase = value;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                '说明：达到门槛后，字体大小按对数增长。底数越小增长越快。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () {
            GStorage.setting.put(SettingBoxKey.mergeDanmaku, _mergeDanmaku);
            GStorage.setting.put(
              SettingBoxKey.danmakuEnlargeThreshold,
              _enlargeThreshold.round(),
            );
            GStorage.setting.put(
              SettingBoxKey.danmakuEnlargeLogBase,
              _enlargeLogBase.round(),
            );
            Navigator.of(context).pop(true);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/services/bubble_read_service.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// 小站帖子已读记录设置。
///
/// 接口不下发已读状态，已读完全由本地维护：
/// - 总开关关闭时下面两项置灰
/// - 单次：退出小站页即清零；持久：落盘，重启仍在
/// - 停留满设定秒数才计入已读
class BubbleReadSettingPage extends StatefulWidget {
  const BubbleReadSettingPage({super.key});

  @override
  State<BubbleReadSettingPage> createState() => _BubbleReadSettingPageState();
}

class _BubbleReadSettingPageState extends State<BubbleReadSettingPage> {
  late bool _enable = Pref.bubbleReadEnable;
  late bool _persistent = Pref.bubbleReadPersistent;
  late int _delay = Pref.bubbleReadDelay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('小站已读记录')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            title: const Text('记录已读'),
            subtitle: const Text('打开过的帖子在列表里置灰显示'),
            value: _enable,
            onChanged: (value) {
              setState(() => _enable = value);
              Pref.bubbleReadEnable = value;
            },
          ),
          const Divider(height: 1),
          ListTile(
            enabled: _enable,
            title: const Text('保持方式'),
            subtitle: Text(
              _persistent ? '持久：读过的帖子一直显示已读' : '单次：退出小站页面后全部恢复未读',
            ),
            trailing: Text(
              _persistent ? '持久' : '单次',
              style: theme.textTheme.labelLarge?.copyWith(
                color: _enable ? colorScheme.primary : colorScheme.outline,
              ),
            ),
            onTap: _enable ? _pickMode : null,
          ),
          ListTile(
            enabled: _enable,
            title: const Text('已读判定时长'),
            subtitle: const Text('在帖子页停留满该时长才计为已读'),
            trailing: Text(
              '${_delay}秒',
              style: theme.textTheme.labelLarge?.copyWith(
                color: _enable ? colorScheme.primary : colorScheme.outline,
              ),
            ),
            onTap: _enable ? _pickDelay : null,
          ),
          if (BubbleReadService.count > 0) ...[
            const Divider(height: 1),
            ListTile(
              title: const Text('清除已读记录'),
              subtitle: Text('当前已记录 ${BubbleReadService.count} 条'),
              trailing: Icon(Icons.delete_outline, color: colorScheme.error),
              onTap: () {
                BubbleReadService.clearAll();
                setState(() {});
                SmartDialog.showToast('已清除小站已读记录');
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickMode() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('保持方式'),
        children: [
          RadioGroup<bool>(
            groupValue: _persistent,
            onChanged: (value) => Navigator.pop(context, value),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  value: false,
                  title: Text('单次'),
                  subtitle: Text('退出小站页面后再次进入，所有帖子都是未读'),
                ),
                RadioListTile<bool>(
                  value: true,
                  title: Text('持久'),
                  subtitle: Text('只要读过的帖子就一直显示已读'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (result != null && result != _persistent) {
      setState(() => _persistent = result);
      Pref.bubbleReadPersistent = result;
    }
  }

  Future<void> _pickDelay() async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => SliderDialog(
        value: _delay.toDouble(),
        title: const Text('已读判定时长'),
        min: 1,
        max: 30,
        divisions: 29,
        precise: 0,
        suffix: '秒',
      ),
    );
    if (result != null) {
      final value = result.round();
      setState(() => _delay = value);
      Pref.bubbleReadDelay = value;
    }
  }
}

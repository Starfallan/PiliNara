import 'dart:math' show max;

import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/models/common/dm_chart_source.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/pages/danmaku_merge_setting.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/filtering_text.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide RefreshIndicator;

List<SettingsModel> get dmSettings => [
  const SwitchModel(
    title: '弹幕开关',
    subtitle: '是否展示弹幕',
    leading: Icon(CustomIcons.dm_settings),
    setKey: SettingBoxKey.enableShowDanmaku,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '智能防挡',
    subtitle: '让弹幕避开画面中的人物（部分视频支持）',
    leading: Icon(Icons.person_off_outlined),
    setKey: SettingBoxKey.enableDanmakuMask,
    defaultVal: false,
  ),
  if (PlatformUtils.isMobile)
    const SwitchModel(
      title: '启用点击弹幕',
      subtitle: '点击弹幕悬停，支持点赞、复制、举报操作',
      leading: Icon(Icons.touch_app_outlined),
      setKey: SettingBoxKey.enableTapDm,
      defaultVal: true,
    ),
  NormalModel(
    title: '弹幕行高',
    subtitle: '默认1.6',
    leading: const Icon(CustomIcons.dm_settings),
    getTrailing: (theme) => Text(
      Pref.danmakuLineHeight.toString(),
      style: theme.textTheme.titleSmall,
    ),
    onTap: _showDmHeightDialog,
  ),
  const SwitchModel(
    title: '显示会员彩色弹幕',
    leading: Icon(MdiIcons.gradientHorizontal),
    setKey: SettingBoxKey.showVipDanmaku,
    defaultVal: true,
  ),
  NormalModel(
    title: '合并弹幕',
    getSubtitle: () {
      final enabled = Pref.mergeDanmaku;
      if (!enabled) return '已关闭';
      final window = Pref.mergeDanmakuWindowSeconds;
      final crossMode = Pref.mergeDanmakuCrossMode ? '跨类型' : '同类型';
      final enlarge = Pref.danmakuEnlarge
          ? '放大门槛: ${Pref.danmakuEnlargeThreshold}'
          : '字号放大: 关';
      return '时间窗: ${window}s, $crossMode, $enlarge';
    },
    leading: const Icon(Icons.merge),
    onTap: (context, setState) async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DanmakuMergeSettingPage(),
        ),
      );
      setState();
    },
  ),
  NormalModel(
    title: '高能进度条',
    leading: const Icon(Icons.show_chart),
    getSubtitle: () =>
        '当前:「${Pref.dmChartSource.label}」\n显示视频弹幕热度趋势；官方无数据时可使用弹幕密度生成',
    onTap: _showDmChartSourceDialog,
  ),
];

void _showDmHeightDialog(BuildContext context, VoidCallback setState) {
  String danmakuLineHeight = Pref.danmakuLineHeight.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('弹幕行高'),
      content: TextFormField(
        autofocus: true,
        initialValue: danmakuLineHeight,
        keyboardType: const .numberWithOptions(decimal: true),
        onChanged: (value) => danmakuLineHeight = value,
        inputFormatters: FilteringText.decimal,
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final val = max(
                1.0,
                double.parse(danmakuLineHeight).toPrecision(1),
              );
              Get.back();
              await GStorage.setting.put(SettingBoxKey.danmakuLineHeight, val);
              setState();
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

Future<void> _showDmChartSourceDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<DmChartSource>(
    context: context,
    builder: (context) => SelectDialog<DmChartSource>(
      title: '高能进度条',
      value: Pref.dmChartSource,
      values: DmChartSource.values.map((e) => (e, e.label)).toList(),
      subtitleBuilder: (context, index, value) => Text(
        DmChartSource.values[index].desc,
        style: TextTheme.of(context).bodySmall,
      ),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.dmChartSource, res.index);
    setState();
  }
}

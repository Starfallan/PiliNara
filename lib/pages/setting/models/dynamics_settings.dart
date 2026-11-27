import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart'
    show DynamicsDataModel, ItemModulesModel;
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/user_whitelist.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide RefreshIndicator;

List<SettingsModel> get dynamicsSettings => [
  SplitModel(
    normalModel: const NormalModel.split(
      title: '检查未读动态',
      subtitle: '点击设置检查周期(min)',
      leading: Icon(Icons.notifications_none),
    ),
    switchModel: SwitchModel.split(
      defaultVal: true,
      setKey: SettingBoxKey.checkDynamic,
      onChanged: (value) => Get.find<MainController>().checkDynamic = value,
      onTap: _showDynDialog,
    ),
  ),
  const SwitchModel(
    title: '发布/转发动态反诈',
    subtitle: '发布/转发动态后检查动态是否可见',
    leading: Icon(CustomIcons.shield_published),
    setKey: SettingBoxKey.enableCreateDynAntifraud,
    defaultVal: false,
  ),
  SwitchModel(
    title: '显示动态警告/争议信息',
    leading: const Icon(Icons.warning_amber_rounded),
    setKey: SettingBoxKey.showDynDispute,
    defaultVal: false,
    onChanged: (val) => ItemModulesModel.showDynDispute = val,
  ),
  const SwitchModel(
    title: '动态/专栏详情页展示底部操作栏',
    leading: Icon(Icons.more_horiz),
    setKey: SettingBoxKey.showDynActionBar,
    defaultVal: true,
  ),
  PopupModel(
    title: '动态展示',
    leading: const Icon(Icons.dynamic_feed_rounded),
    value: () => Pref.defaultDynamicType,
    items: DynamicsTabType.values.take(4),
    onSelected: (value, setState) => GStorage.setting
        .put(SettingBoxKey.defaultDynamicType, value.index)
        .whenComplete(setState),
  ),
  SwitchModel(
    title: '显示动态互动内容',
    subtitle: '开启后则在动态卡片底部显示互动内容（如关注的人点赞、热评等）',
    leading: const Icon(Icons.quickreply_outlined),
    setKey: SettingBoxKey.showDynInteraction,
    defaultVal: true,
    onChanged: (val) => ItemModulesModel.showDynInteraction = val,
  ),
  getListBanWordModel(
    title: '动态关键词过滤',
    key: SettingBoxKey.banWordForDyn,
    onChanged: (value) {
      DynamicsDataModel.banWordForDyn = value;
      DynamicsDataModel.enableFilter = value.isNotEmpty;
    },
  ),
  getListUidModel(
    title: '动态屏蔽用户',
    getUids: () => Pref.dynamicsBlockedMids,
    setUids: (uids) {
      Pref.dynamicsBlockedMids = uids;
      GlobalData().dynamicsBlockedMids = uids;
      DynamicsDataModel.dynamicsBlockedMids = uids;
    },
    onUpdate: () {
      // Changes are immediately reflected
    },
  ),
  getListUidWithNameModel(
    title: '动态白名单用户',
    leading: const Icon(Icons.person_add_alt_1_outlined),
    emptySubtitle: '点击添加白名单用户',
    countSubtitleBuilder: (count) => '已加入白名单 $count 个用户',
    getUidsMap: () => Pref.whitelistMids,
    setUidsMap: UserWhitelist.save,
    onUpdate: () {
      // Changes are immediately reflected
    },
  ),
  const SwitchModel(
    title: '\u9690\u85cf\u7eaf\u6587\u5b57\u52a8\u6001',
    subtitle: '\u4ec5\u5f71\u54cd\u5173\u6ce8\u6d41\u3001\u6309 UP \u4e3b\u6d4f\u89c8\u548c\u4e2a\u4eba\u7a7a\u95f4\uff0c\u91cd\u65b0\u8fdb\u5165\u6216\u5237\u65b0\u540e\u751f\u6548',
    leading: Icon(Icons.notes_outlined),
    setKey: SettingBoxKey.hideTextDyn,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '\u9690\u85cf\u56fe\u6587\u52a8\u6001',
    subtitle: '\u4ec5\u5f71\u54cd\u5173\u6ce8\u6d41\u3001\u6309 UP \u4e3b\u6d4f\u89c8\u548c\u4e2a\u4eba\u7a7a\u95f4\uff0c\u91cd\u65b0\u8fdb\u5165\u6216\u5237\u65b0\u540e\u751f\u6548',
    leading: Icon(Icons.image_outlined),
    setKey: SettingBoxKey.hideImageDyn,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '\u9690\u85cf\u52a8\u6001\u8bfb\u8005\u8bc4\u8bba',
    subtitle: '\u9690\u85cf\u52a8\u6001\u5361\u7247\u70ed\u8bc4\u548c\u8be6\u60c5\u9875\u8bc4\u8bba\uff1b\u4f5c\u8005\u4ecd\u53ef\u67e5\u770b\u548c\u7ba1\u7406\u8bc4\u8bba',
    leading: Icon(Icons.comment_outlined),
    setKey: SettingBoxKey.hideDynamicComments,
    defaultVal: false,
  ),
  SwitchModel(
    title: '屏蔽带货动态',
    subtitle: '过滤包含商品推广的动态',
    leading: const Icon(Icons.shopping_bag_outlined),
    setKey: SettingBoxKey.antiGoodsDyn,
    defaultVal: false,
    onChanged: (value) {
      DynamicsDataModel.antiGoodsDyn = value;
    },
  ),
  SwitchModel(
    title: '屏蔽无权查看的动态',
    subtitle: '过滤当前账号无权查看的受限动态,如充电专属(文章,图文等)动态',
    leading: const Icon(Icons.visibility_off_outlined),
    setKey: SettingBoxKey.removeBlockedDyn,
    defaultVal: false,
    onChanged: (value) {
      DynamicsDataModel.removeBlockedDyn = value;
    },
  ),
  SwitchModel(
    title: '屏蔽充电专属视频动态',
    subtitle: '过滤充电专属视频动态',
    leading: const Icon(Icons.video_library_outlined),
    setKey: SettingBoxKey.removeOnlyFansVideoDyn,
    defaultVal: false,
    onChanged: (value) {
      DynamicsDataModel.removeOnlyFansVideoDyn = value;
    },
  ),
  SwitchModel(
    title: '屏蔽动态视频',
    subtitle: '过滤动态流中的动态视频（信息密度较低，仅非 UP 页生效）',
    leading: const Icon(Icons.smart_display_outlined),
    setKey: SettingBoxKey.removeDynVideoDyn,
    defaultVal: false,
    onChanged: (value) {
      DynamicsDataModel.removeDynVideoDyn = value;
    },
  ),
];

void _showDynDialog(BuildContext context) {
  String dynamicPeriod = Pref.dynamicPeriod.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('检查周期'),
      content: TextFormField(
        autofocus: true,
        initialValue: dynamicPeriod,
        keyboardType: TextInputType.number,
        onChanged: (value) => dynamicPeriod = value,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(suffixText: 'min'),
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
          onPressed: () {
            try {
              final val = int.parse(dynamicPeriod);
              Get.back();
              GStorage.setting.put(SettingBoxKey.dynamicPeriod, val);
              Get.find<MainController>().dynamicPeriod = val * 60 * 1000;
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

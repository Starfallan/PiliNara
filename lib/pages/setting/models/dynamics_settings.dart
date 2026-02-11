import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

List<SettingsModel> get dynamicsSettings => [
  getListBanWordModel(
    title: '关键词过滤',
    key: SettingBoxKey.banWordForDyn,
    onChanged: (value) {
      DynamicsDataModel.banWordForDyn = value;
      DynamicsDataModel.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getListUidModel(
    title: '屏蔽用户',
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
];

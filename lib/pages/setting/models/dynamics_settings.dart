import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

List<SettingsModel> get dynamicsSettings => [
  getBanWordModel(
    title: '关键词过滤',
    key: SettingBoxKey.banWordForDyn,
    onChanged: (value) {
      DynamicsDataModel.banWordForDyn = value;
      DynamicsDataModel.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  NormalModel(
    leading: const Icon(Icons.person_off_outlined),
    title: '屏蔽用户',
    getSubtitle: () {
      final blockedMids = Pref.dynamicsBlockedMids;
      if (blockedMids.isEmpty) {
        return '点击添加';
      }
      return '已屏蔽 ${blockedMids.length} 个用户';
    },
    onTap: (context, setState) {
      Set<int> blockedMids = Set<int>.from(Pref.dynamicsBlockedMids);
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('屏蔽用户'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('输入用户UID（一行一个）'),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: TextFormField(
                        autofocus: true,
                        initialValue: blockedMids.join('\n'),
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.number,
                        minLines: 3,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          hintText: '例如：\n12345678\n87654321',
                        ),
                        onChanged: (value) {
                          // Parse user input into a set of integers
                          blockedMids = value
                              .split('\n')
                              .map((e) => int.tryParse(e.trim()))
                              .where((e) => e != null)
                              .cast<int>()
                              .toSet();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: Get.back,
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              TextButton(
                child: const Text('保存'),
                onPressed: () {
                  Get.back();
                  Pref.dynamicsBlockedMids = blockedMids;
                  GlobalData().dynamicsBlockedMids = blockedMids;
                  setState();
                  SmartDialog.showToast('已保存');
                },
              ),
            ],
          );
        },
      );
    },
  ),
  const SwitchModel(
    title: '屏蔽带货动态',
    subtitle: '过滤包含商品推广的动态',
    leading: Icon(Icons.shopping_bag_outlined),
    setKey: SettingBoxKey.antiGoodsDyn,
    defaultVal: false,
    onChanged: (value) {
      DynamicsDataModel.antiGoodsDyn = value;
    },
  ),
];

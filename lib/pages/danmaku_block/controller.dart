import 'dart:convert';

import 'package:PiliPlus/http/danmaku_block.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dm_block_type.dart';
import 'package:PiliPlus/models/user/danmaku_block.dart';
import 'package:PiliPlus/models/user/danmaku_rule.dart';
import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class DanmakuBlockController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final List<RxList<SimpleRule>> rules = List.generate(
    DmBlockType.values.length,
    (_) => <SimpleRule>[].obs,
  );

  late TabController tabController;

  @override
  void onInit() {
    super.onInit();
    RuleFilter.logDebug('DanmakuBlockController.onInit');
    queryDanmakuFilter();
    tabController = TabController(length: 3, vsync: this);
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  Future<void> queryDanmakuFilter() async {
    RuleFilter.logDebug(
      'queryDanmakuFilter start '
      'keyword=${rules[0].length}, regex=${rules[1].length}, uid=${rules[2].length}',
    );
    SmartDialog.showLoading(msg: '正在同步弹幕屏蔽规则……');
    final result = await DanmakuFilterHttp.danmakuFilter();
    SmartDialog.dismiss();
    if (result case Success(:final response)) {
      RuleFilter.logDebug(
        'queryDanmakuFilter success '
        'valid=${response.valid}, ver=${response.ver}, toast=${response.toast ?? ""}',
      );
      RuleFilter.logDebug(
        RuleFilter.formatRulesSnapshot('serverRules', [
          response.rule,
          response.rule1,
          response.rule2,
        ]),
      );
      rules[0].addAll(response.rule);
      rules[1].addAll(response.rule1);
      rules[2].addAll(response.rule2);
      RuleFilter.logDebug(
        'queryDanmakuFilter applied '
        'keyword=${rules[0].length}, regex=${rules[1].length}, uid=${rules[2].length}',
      );
      if (response.toast case final toast?) {
        SmartDialog.showToast(toast);
      }
    } else {
      RuleFilter.logDebug('queryDanmakuFilter failed: $result');
      result.toast();
    }
  }

  Future<void> danmakuFilterDel(int tabIndex, int itemIndex, int id) async {
    final item = itemIndex < rules[tabIndex].length
        ? rules[tabIndex][itemIndex]
        : null;
    RuleFilter.logDebug(
      'danmakuFilterDel start '
      'tabIndex=$tabIndex, itemIndex=$itemIndex, id=$id, '
      'filter=${item?.filter ?? "<unknown>"}',
    );
    SmartDialog.showLoading(msg: '正在删除弹幕屏蔽规则……');
    final res = await DanmakuFilterHttp.danmakuFilterDel(ids: id);
    SmartDialog.dismiss();
    if (res.isSuccess) {
      rules[tabIndex].removeAt(itemIndex);
      RuleFilter.logDebug(
        'danmakuFilterDel success '
        'tabIndex=$tabIndex, remain=${rules[tabIndex].length}',
      );
      SmartDialog.showToast('删除成功');
    } else {
      RuleFilter.logDebug('danmakuFilterDel failed: $res');
      res.toast();
    }
  }

  Future<void> danmakuFilterAdd({
    required String filter,
    required int type,
  }) async {
    final rawFilter = filter;
    if (type == 2) {
      filter = getCrc32(ascii.encode(filter), 0).toRadixString(16);
    }
    RuleFilter.logDebug(
      'danmakuFilterAdd start '
      'type=$type(${DmBlockType.values[type].label}), rawFilter=$rawFilter, requestFilter=$filter',
    );
    SmartDialog.showLoading(msg: '正在添加弹幕屏蔽规则……');
    final res = await DanmakuFilterHttp.danmakuFilterAdd(
      filter: filter,
      type: type,
    );
    SmartDialog.dismiss();
    if (res case Success(:final response)) {
      rules[type].add(response);
      RuleFilter.logDebug(
        'danmakuFilterAdd success '
        'type=$type(${DmBlockType.values[type].label}), responseId=${response.id}, '
        'responseFilter=${response.filter}, currentCount=${rules[type].length}',
      );
      SmartDialog.showToast('添加成功');
    } else {
      RuleFilter.logDebug('danmakuFilterAdd failed: $res');
      res.toast();
    }
  }
}

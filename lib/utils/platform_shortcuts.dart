import 'dart:io';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

// 全局工具：当前是否按下了"本平台的快捷修饰键"
bool get isPrimaryModifierPressed {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS: // macOS 用 ⌘
      return HardwareKeyboard.instance.isMetaPressed;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.android:
    case TargetPlatform.iOS: // iPadOS 外接键盘也走这里
    case TargetPlatform.fuchsia:
      return HardwareKeyboard.instance.isControlPressed; // 其余用 Ctrl
  }
}

class ShortcutHandler {
  // 处理退出快捷键 (Cmd+Q)
  static KeyEventResult? handleQuitKey(KeyEvent event) {
    if (!Pref.keyboardControl) return null;
    if (event is! KeyDownEvent) return null;

    if (event.logicalKey != LogicalKeyboardKey.keyQ) {
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS &&
        HardwareKeyboard.instance.isMetaPressed) {
      exit(0);
    }
    return null;
  }

  // 处理刷新快捷键
  static KeyEventResult? handleRefreshKey(KeyEvent event) {
    if (!Pref.keyboardControl) return null;
    if (event is! KeyDownEvent) return null;
    // 1. 先匹配字母 R
    if (event.logicalKey != LogicalKeyboardKey.keyR) {
      return null;
    }
    // 2. 再判断本平台的"主修饰键"是否按下
    if (!isPrimaryModifierPressed) return null;
    // 3. 防止 Shift/Alt/等其它修饰符干扰
    if (HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return null;
    }
    // 4. 真正干活
    handleRefreshShortcut();
    return KeyEventResult.handled;
  }

  // 处理设置快捷键 (主修饰键 + ,)
  static KeyEventResult? handleSettingsKey(KeyEvent event) {
    if (!Pref.keyboardControl) return null;
    if (event is! KeyDownEvent) return null;
    // 1. 先匹配逗号键
    if (event.logicalKey != LogicalKeyboardKey.comma) {
      return null;
    }
    // 2. 再判断本平台的"主修饰键"是否按下
    if (!isPrimaryModifierPressed) return null;
    // 3. 防止 Shift/Alt/等其它修饰符干扰
    if (HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return null;
    }
    // 4. 打开设置页面
    handleSettingsShortcut();
    return KeyEventResult.handled;
  }

  // 处理Control+R快捷键刷新
  static void handleRefreshShortcut() {
    // 获取当前路由
    final context = Get.context;
    if (context == null) return;
    // 尝试获取当前页面的控制器
    final currentController = _getCurrentPageController();
    if (currentController != null) {
      // 如果当前控制器有onRefresh方法，则调用它
      if (currentController is ScrollOrRefreshMixin) {
        currentController.onRefresh();
      }
    }
  }

  // 获取当前页面的控制器
  static dynamic _getCurrentPageController() {
    try {
      // 获取主页控制器
      final mainController = Get.find<MainController>();
      final currentIndex = mainController.selectedIndex.value;
      // 根据当前索引获取对应的控制器
      if (mainController.navigationBars[currentIndex] ==
          NavigationBarType.home) {
        final homeController = Get.find<HomeController>();
        return homeController.controller;
      } else if (mainController.navigationBars[currentIndex] ==
          NavigationBarType.dynamics) {
        return Get.find<DynamicsController>();
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 处理Alt+H/Opt+H返回主页快捷键
  static KeyEventResult? handleHomeShortcut(KeyEvent event) {
    if (!Pref.keyboardControl) return null;
    if (event is! KeyDownEvent) return null;
    // 1. 先匹配字母 H
    if (event.logicalKey != LogicalKeyboardKey.keyH) {
      return null;
    }
    // 2. 判断Alt键是否按下（Windows/Linux/macOS的Option键）
    if (!HardwareKeyboard.instance.isAltPressed) {
      return null;
    }
    // 3. 防止其他修饰符干扰
    if (HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return null;
    }
    // 4. 执行返回主页逻辑
    handleHomeShortcutAction();
    return KeyEventResult.handled;
  }

  // 执行返回主页操作
  static void handleHomeShortcutAction() {
    // 清理播放器资源（如果存在）
    final plCtr = PlPlayerController.instance;
    if (plCtr != null) {
      plCtr
        ..isCloseAll = true
        ..dispose();
    }
    // 返回主页
    Get.until((route) => route.isFirst);
  }

  // 处理设置快捷键
  static void handleSettingsShortcut() {
    // 打开设置页面
    Get.toNamed('/setting', preventDuplicates: false);
  }
}

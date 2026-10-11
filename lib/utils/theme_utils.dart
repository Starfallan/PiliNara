import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/miuix/miuix_colors.dart';
import 'package:PiliPlus/utils/miuix/miuix_theme.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:material_ui/material_ui.dart';

/// 应用主题。
///
/// PiliNara 的主题就是 miuix 主题：配色是 miuix 的角色（[MiuixColors]），几何是 miuix 的
/// 圆角与高度（`MiuixShapes`），字阶是 miuix 的十四个槽位（`miuixTextTheme`）。取色方式也
/// 与 miuix 一致——动态取色或种子色先算出 Material 配色，再翻译成 miuix 的角色；选择
/// 「MIUI 蓝」时则直接使用 miuix 的固定配色。
abstract final class ThemeUtils {
  static late ThemeData lightTheme;

  static late ThemeData darkTheme;

  static late ThemeMode themeMode;

  static ThemeData get theme {
    if (themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            PlatformDispatcher.instance.platformBrightness == Brightness.dark)) {
      return darkTheme;
    }
    return lightTheme;
  }

  static bool get isDarkMode => theme.isDark;

  static String themeUrl(bool isDark) =>
      'native.theme=${isDark ? 2 : 1}&night=${isDark ? 1 : 0}';

  /// 用一份 Material 配色构造 miuix 主题。
  ///
  /// [miuixColors] 给出 miuix 令牌，省略时把 [colorScheme] 翻译成 miuix 的取色方式
  /// （动态取色与种子色走的就是这条路）。传 [MiuixColors.light] / [MiuixColors.dark] 则得到
  /// miuix 的固定配色，也就是 MIUI 经典主题。
  static ThemeData getThemeData({
    required ColorScheme colorScheme,
    bool isDark = false,
    MiuixColors? miuixColors,
  }) {
    final theme = MiuixTheme.getThemeData(
      colors: miuixColors ?? MiuixColors.fromColorScheme(colorScheme),
      fontFamily: Pref.appFont,
      fontWeight: Pref.appFontWeight,
    );
    if (isDark && Pref.isPureBlackTheme) {
      return darkenTheme(theme);
    }
    return theme;
  }

  /// 纯黑模式：把画布与顶层表面压成纯黑，其余角色交给 miuix 的调色板。
  ///
  /// miuix 的"抬升"不是 Material 那套 elevation 着色，而是靠调色板自己的层次：深色下
  /// `surface` 纯黑、`surfaceContainer` `#242424`、`surfaceContainerHigh` `#242424`、
  /// `surfaceContainerHighest` `#2D2D2D`。所以这里只把页面级表面（画布、顶栏、底栏轨道）
  /// 固定成纯黑，不再把容器角色按比例压暗——那会把 miuix 的层次压平。
  static ThemeData darkenTheme(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return theme.copyWith(
      canvasColor: Colors.black,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      navigationBarTheme: theme.navigationBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      navigationRailTheme: theme.navigationRailTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      // 调色板本身已经是「纯黑页面 + #242424 / #2D2D2D 容器」这套 miuix 层次，这里只把
      // 页面级表面钉成纯黑，容器角色保持不动。
      colorScheme: colorScheme.copyWith(surface: Colors.black),
    );
  }
}

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
    required bool isDynamic,
    bool isDark = false,
    MiuixColors? miuixColors,
  }) {
    final theme = MiuixTheme.getThemeData(
      colors: miuixColors ?? MiuixColors.fromColorScheme(colorScheme),
      fontFamily: Pref.appFont,
      fontWeight: Pref.appFontWeight,
      isDynamic: isDynamic,
    ).copyWith(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: Pref.enablePredictiveBack
              ? const PredictiveBackPageTransitionsBuilder()
              : const ZoomPageTransitionsBuilder(),
        },
      ),
    );
    if (isDark && Pref.isPureBlackTheme) {
      return darkenTheme(theme);
    }
    return theme;
  }

  /// 纯黑模式：画布与顶层表面压成纯黑，各层容器按 miuix 的层次继续压暗，主色与次要色
  /// 也略微向黑色靠拢，保证在纯黑画布上的对比度。
  static ThemeData darkenTheme(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final color = colorScheme.surfaceContainerHighest.darken(0.7);
    return theme.copyWith(
      canvasColor: Colors.black,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      cardTheme: theme.cardTheme.copyWith(
        color: colorScheme.surfaceContainer.darken(0.75),
      ),
      dialogTheme: theme.dialogTheme.copyWith(backgroundColor: color),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: color,
      ),
      bottomNavigationBarTheme: theme.bottomNavigationBarTheme.copyWith(
        backgroundColor: color,
      ),
      navigationBarTheme: theme.navigationBarTheme.copyWith(
        backgroundColor: color,
      ),
      navigationRailTheme: theme.navigationRailTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      popupMenuTheme: theme.popupMenuTheme.copyWith(color: color),
      colorScheme: colorScheme.copyWith(
        primary: colorScheme.primary.darken(0.1),
        onPrimary: colorScheme.onPrimary.darken(0.1),
        primaryContainer: colorScheme.primaryContainer.darken(0.1),
        onPrimaryContainer: colorScheme.onPrimaryContainer.darken(0.1),
        inversePrimary: colorScheme.inversePrimary.darken(0.1),
        secondary: colorScheme.secondary.darken(0.05),
        onSecondary: colorScheme.onSecondary.darken(0.05),
        secondaryContainer: colorScheme.secondaryContainer.darken(0.05),
        onSecondaryContainer: colorScheme.onSecondaryContainer.darken(0.05),
        error: colorScheme.error.darken(0.05),
        surface: Colors.black,
        onSurface: colorScheme.onSurface.darken(0.15),
        surfaceTint: colorScheme.surfaceTint.darken(),
        inverseSurface: colorScheme.inverseSurface.darken(),
        onInverseSurface: colorScheme.onInverseSurface.darken(),
        surfaceContainer: colorScheme.surfaceContainer.darken(),
        surfaceContainerHigh: colorScheme.surfaceContainerHigh.darken(),
        surfaceContainerHighest: colorScheme.surfaceContainerHighest.darken(
          0.4,
        ),
      ),
    );
  }
}

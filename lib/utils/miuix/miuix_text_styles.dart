import 'package:material_ui/material_ui.dart';

/// miuix 的字阶，映射到 Material 的 [TextTheme]。
///
/// miuix 的 TextStyles 声明了十四个槽位（main、paragraph、body1/2、button、footnote1/2、
/// headline1/2、subtitle、title1 ~ title4），Material 的 [TextTheme] 声明了十五个角色，
/// 两套字阶并非一一对应，映射规则如下（左为 Material 角色，右为 miuix 槽位与字号）：
///
/// | Material | miuix |
/// |----------|-------|
/// | `displayLarge` / `headlineLarge` | `title1` 32 |
/// | `displayMedium` / `headlineMedium` / `headlineSmall` | `title2` 24 |
/// | `displaySmall` / `titleLarge` | `title3` 20 |
/// | `titleMedium` | `headline1` 17 |
/// | `titleSmall` | `headline2` 16 |
/// | `bodyLarge` | `main`（`paragraph`、`body1` 归并到这里）17 |
/// | `bodyMedium` | `body2` 14 |
/// | `bodySmall` | `footnote1` 13 |
/// | `labelLarge` | `button` 17 |
/// | `labelMedium` | `subtitle` 14、加粗 |
/// | `labelSmall` | `footnote2` 11 |
///
/// miuix 只给 `paragraph` 指定了行高（1.2 em），其余槽位都用字体自身的行高，因此这里不写
/// 死行高；字重默认与 miuix 一致（除 `subtitle` 加粗外都是常规字重）。PiliNara 的字体重
/// 与字体族偏好会覆盖到全部角色上，这与其原本的行为一致。
///
/// miuix 的 `title4`（18）、`paragraph`、`body1` 在这套映射里没有独立角色，它们的字号分别
/// 落在 `titleMedium`、`bodyLarge` 与 `bodyLarge` 附近。
TextTheme miuixTextTheme({String? fontFamily, FontWeight? fontWeight}) {
  TextStyle style(double fontSize, [FontWeight? weight]) => TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight ?? weight,
    fontFamily: fontFamily,
  );

  return TextTheme(
    displayLarge: style(32),
    displayMedium: style(24),
    displaySmall: style(20),
    headlineLarge: style(32),
    headlineMedium: style(24),
    headlineSmall: style(24),
    titleLarge: style(20),
    titleMedium: style(17),
    titleSmall: style(16),
    bodyLarge: style(17),
    bodyMedium: style(14),
    bodySmall: style(13),
    labelLarge: style(17),
    labelMedium: style(14, FontWeight.bold),
    labelSmall: style(11),
  );
}

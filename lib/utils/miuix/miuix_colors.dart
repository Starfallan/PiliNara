import 'package:material_ui/material_ui.dart';

/// MIUI（miuix）配色令牌。
///
/// 这是 miuix 的 `top.yukonga.miuix.kmp.theme.Colors` 在 Dart 侧的等价物：同样的角色、
/// 同样的默认值，取自 `lightColorScheme()` 与 `darkColorScheme()`。角色的语义与 miuix
/// 的组件一一对应，例如
///
/// * `primary` 用于 Switch、Button、Slider 的选中态；
/// * `primaryVariant` 是 Card 的主色变体；
/// * `secondary` 是中性填充色（Monet 取色时它就是 `outlineVariant`）；
/// * `surface` 是 Scaffold 与 TopAppBar 的底色，`surfaceContainer` 是 Card 的底色；
/// * `surfaceContainerHighest` 是弹出菜单、导航栏这类浮层的底色；
/// * `windowDimming` 是对话框、下拉、底部弹层的遮罩色；
/// * `dividerLine` 是分隔线色。
///
/// PiliNara 是一个 Material 应用，它的控件读取 [ColorScheme]，因此 [toColorScheme] 会把
/// 这些令牌映射到 [ColorScheme] 的角色上（映射表见该方法），[fromColorScheme] 则做反向的
/// 事：把动态取色或种子色算出来的 Material 配色翻译成 miuix 令牌。
class MiuixColors {
  const MiuixColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryVariant,
    required this.onPrimaryVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.disabledPrimary,
    required this.disabledOnPrimary,
    required this.disabledPrimaryButton,
    required this.disabledOnPrimaryButton,
    required this.disabledPrimarySlider,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryVariant,
    required this.onSecondaryVariant,
    required this.disabledSecondary,
    required this.disabledOnSecondary,
    required this.disabledSecondaryVariant,
    required this.disabledOnSecondaryVariant,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.secondaryContainerVariant,
    required this.onSecondaryContainerVariant,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.tertiaryContainerVariant,
    required this.background,
    required this.onBackground,
    required this.onBackgroundVariant,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceSecondary,
    required this.onSurfaceVariantSummary,
    required this.onSurfaceVariantActions,
    required this.disabledOnSurface,
    required this.surfaceContainer,
    required this.onSurfaceContainer,
    required this.onSurfaceContainerVariant,
    required this.surfaceContainerHigh,
    required this.onSurfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurfaceContainerHighest,
    required this.outline,
    required this.dividerLine,
    required this.windowDimming,
    required this.sliderKeyPoint,
    required this.sliderKeyPointForeground,
    required this.sliderBackground,
  });

  /// MIUI 经典主色，也就是 miuix `lightColorScheme()` 的默认 `primary`。
  ///
  /// 选择这个颜色意味着使用 miuix 的固定配色（[light] / [dark]），而不是由它推导出来的
  /// 动态配色，这与 miuix 自身的默认主题行为一致。
  static const Color classicKeyColor = Color(0xFF3482FF);

  /// 明暗模式。miuix 的 `Colors` 没有这个字段，它由所选的静态配色或取色模式决定，
  /// 这里保留一份以便 [toColorScheme] 与需要区分的组件主题使用。
  final Brightness brightness;

  final Color primary;
  final Color onPrimary;
  final Color primaryVariant;
  final Color onPrimaryVariant;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color disabledPrimary;
  final Color disabledOnPrimary;
  final Color disabledPrimaryButton;
  final Color disabledOnPrimaryButton;
  final Color disabledPrimarySlider;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryVariant;
  final Color onSecondaryVariant;
  final Color disabledSecondary;
  final Color disabledOnSecondary;
  final Color disabledSecondaryVariant;
  final Color disabledOnSecondaryVariant;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryContainerVariant;
  final Color onSecondaryContainerVariant;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryContainerVariant;
  final Color background;
  final Color onBackground;
  final Color onBackgroundVariant;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color onSurfaceSecondary;
  final Color onSurfaceVariantSummary;
  final Color onSurfaceVariantActions;
  final Color disabledOnSurface;
  final Color surfaceContainer;
  final Color onSurfaceContainer;
  final Color onSurfaceContainerVariant;
  final Color surfaceContainerHigh;
  final Color onSurfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurfaceContainerHighest;
  final Color outline;
  final Color dividerLine;
  final Color windowDimming;
  final Color sliderKeyPoint;
  final Color sliderKeyPointForeground;
  final Color sliderBackground;

  /// miuix 的浅色配色，逐项取自 `lightColorScheme()` 的默认值。
  static const MiuixColors light = MiuixColors(
    brightness: Brightness.light,
    primary: Color(0xFF3482FF),
    onPrimary: Color(0xFFFFFFFF),
    primaryVariant: Color(0xFF3482FF),
    onPrimaryVariant: Color(0xFFAECDFF),
    error: Color(0xFFE94634),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDF6F4),
    onErrorContainer: Color(0xFF410002),
    disabledPrimary: Color(0xFFC2D9FF),
    disabledOnPrimary: Color(0xFFF3F8FF),
    disabledPrimaryButton: Color(0xFFC2D9FF),
    disabledOnPrimaryButton: Color(0xFFFFFFFF),
    disabledPrimarySlider: Color(0xFFB8CFF5),
    primaryContainer: Color(0xFF5D9BFF),
    onPrimaryContainer: Color(0xFFFFFFFF),
    secondary: Color(0xFFE6E6E6),
    onSecondary: Color(0xFFFFFFFF),
    secondaryVariant: Color(0xFFF0F0F0),
    onSecondaryVariant: Color(0xFF303030),
    disabledSecondary: Color(0xFFF0F0F0),
    disabledOnSecondary: Color(0xFFFCFCFC),
    disabledSecondaryVariant: Color(0xFFF2F2F2),
    disabledOnSecondaryVariant: Color(0xFFB2B2B2),
    secondaryContainer: Color(0xFFF0F0F0),
    onSecondaryContainer: Color(0xFFA9A9A9),
    secondaryContainerVariant: Color(0xFFF0F0F0),
    onSecondaryContainerVariant: Color(0xFFA8A8A8),
    tertiaryContainer: Color(0xFFEAF2FF),
    onTertiaryContainer: Color(0xFF3482FF),
    tertiaryContainerVariant: Color(0xFFEAF2FF),
    background: Color(0xFFFFFFFF),
    onBackground: Color(0xFF000000),
    onBackgroundVariant: Color(0xFF8C93B0),
    surface: Color(0xFFF7F7F7),
    onSurface: Color(0xFF000000),
    surfaceVariant: Color(0xFFFFFFFF),
    onSurfaceSecondary: Color(0xCC000000),
    onSurfaceVariantSummary: Color(0x99000000),
    onSurfaceVariantActions: Color(0x66000000),
    disabledOnSurface: Color(0xFFB2B2B2),
    surfaceContainer: Color(0xFFFFFFFF),
    onSurfaceContainer: Color(0xFF000000),
    onSurfaceContainerVariant: Color(0xFF959595),
    surfaceContainerHigh: Color(0xFFE8E8E8),
    onSurfaceContainerHigh: Color(0xFFA2A2A2),
    surfaceContainerHighest: Color(0xFFE8E8E8),
    onSurfaceContainerHighest: Color(0xFF000000),
    outline: Color(0xFFD9D9D9),
    dividerLine: Color(0xFFE0E0E0),
    windowDimming: Color(0x4D000000),
    sliderKeyPoint: Color(0x4DA3B3CD),
    sliderKeyPointForeground: Color(0xFF6EB5FF),
    sliderBackground: Color(0x0F000000),
  );

  /// miuix 的深色配色，逐项取自 `darkColorScheme()` 的默认值。
  static const MiuixColors dark = MiuixColors(
    brightness: Brightness.dark,
    primary: Color(0xFF277AF7),
    onPrimary: Color(0xFFFFFFFF),
    primaryVariant: Color(0xFF0073DD),
    onPrimaryVariant: Color(0xFF99C7F1),
    error: Color(0xFFF12522),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF2E0603),
    onErrorContainer: Color(0xFFFFDAD6),
    disabledPrimary: Color(0xFF253E64),
    disabledOnPrimary: Color(0xFF677993),
    disabledPrimaryButton: Color(0xFF253E64),
    disabledOnPrimaryButton: Color(0xFF677893),
    disabledPrimarySlider: Color(0xFF44587C),
    primaryContainer: Color(0xFF338FE4),
    onPrimaryContainer: Color(0xFFFFFFFF),
    secondary: Color(0xFF505050),
    onSecondary: Color(0xFFFFFFFF),
    secondaryVariant: Color(0xFF434343),
    onSecondaryVariant: Color(0xFFD9D9D9),
    disabledSecondary: Color(0xFF3F3F3F),
    disabledOnSecondary: Color(0xFF797979),
    disabledSecondaryVariant: Color(0xFF404040),
    disabledOnSecondaryVariant: Color(0xFF707170),
    secondaryContainer: Color(0xFF434343),
    onSecondaryContainer: Color(0xFF7C7C7C),
    secondaryContainerVariant: Color(0xFF4F4F4F),
    onSecondaryContainerVariant: Color(0xFF959595),
    tertiaryContainer: Color(0xFF2B3B54),
    onTertiaryContainer: Color(0xFF4788FF),
    tertiaryContainerVariant: Color(0xFF505050),
    background: Color(0xFF242424),
    onBackground: Color(0xE6FFFFFF),
    onBackgroundVariant: Color(0xFF787E96),
    surface: Color(0xFF000000),
    onSurface: Color(0xFFF2F2F2),
    surfaceVariant: Color(0xFF242424),
    onSurfaceSecondary: Color(0xCCFFFFFF),
    onSurfaceVariantSummary: Color(0x80FFFFFF),
    onSurfaceVariantActions: Color(0x66FFFFFF),
    disabledOnSurface: Color(0xFF666666),
    surfaceContainer: Color(0xFF242424),
    onSurfaceContainer: Color(0xE6FFFFFF),
    onSurfaceContainerVariant: Color(0xFF737373),
    surfaceContainerHigh: Color(0xFF242424),
    onSurfaceContainerHigh: Color(0xFF666666),
    surfaceContainerHighest: Color(0xFF2D2D2D),
    onSurfaceContainerHighest: Color(0xFFE9E9E9),
    outline: Color(0xFF404040),
    dividerLine: Color(0xFF393939),
    windowDimming: Color(0x99000000),
    sliderKeyPoint: Color(0x4D7A8AA6),
    sliderKeyPointForeground: Color(0xFF5DAAFF),
    sliderBackground: Color(0x26FFFFFF),
  );

  /// 当前明暗模式下的 Static 配色。
  static MiuixColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// 返回当前配色在另一个明暗模式下的对应配色。
  MiuixColors get reverse =>
      brightness == Brightness.dark ? light : dark;

  /// 把 miuix 令牌映射到 Material 的 [ColorScheme]。
  ///
  /// Miuix 的角色比 Material 少，也不叫同样的名字，映射规则如下（左为 Material，右为 miuix）：
  ///
  /// | Material | miuix |
  /// |----------|-------|
  /// | `primary` / `onPrimary` | `primary` / `onPrimary` |
  /// | `primaryContainer` / `onPrimaryContainer` | `primaryContainer` / `onPrimaryContainer` |
  /// | `primaryFixed` / `onPrimaryFixed` | `primaryVariant` / `onPrimaryVariant` |
  /// | `secondary` / `onSecondary` | `secondary` / `onSecondary` |
  /// | `secondaryContainer` / `onSecondaryContainer` | `secondaryContainer` / `onSecondaryVariant` |
  /// | `tertiary` / `tertiaryContainer` | `tertiaryContainer` |
  /// | `surface` / `onSurface` | `surface` / `onSurface` |
  /// | `surfaceContainer` … `Highest` | 同名令牌 |
  /// | `surfaceContainerLowest` / `Low` | `surfaceVariant` / `secondaryVariant` |
  /// | `surfaceDim` / `surfaceBright` | `surfaceContainerHigh` / `surfaceContainer` |
  /// | `onSurfaceVariant` / `outline` | `onSurfaceVariantSummary` |
  /// | `outlineVariant` | `dividerLine` |
  /// | `scrim` | `windowDimming` |
  /// | `inverseSurface` / `onInverseSurface` | `onSecondaryVariant` / `secondaryVariant` |
  /// | `surfaceTint` | `Colors.transparent`（MIUI 表面是平的，不做高程着色） |
  ///
  /// 两处偏离 miuix 自身配对的说明：
  ///
  /// * PiliNara 一直把 `outline` 当作次级文字色使用，所以它落在 miuix 的摘要文字色
  ///   `onSurfaceVariantSummary` 上，真正的分隔线则由 `outlineVariant` / `dividerLine` 承担。
  /// * PiliNara 在 `secondaryContainer` 上画的是图标与文字，而 miuix 的 `onSecondaryContainer`
  ///   是占位符灰（浅色模式 `#A9A9A9`），压在 `#F0F0F0` 上几乎看不清。miuix 给自己的灰色填充
  ///   配的前景色是 `onSecondaryVariant`（浅色模式 `#303030`），这里跟随它。
  ColorScheme toColorScheme() => ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    primaryFixed: primaryVariant,
    primaryFixedDim: primaryVariant,
    onPrimaryFixed: onPrimaryVariant,
    onPrimaryFixedVariant: onPrimaryVariant,
    inversePrimary: primaryVariant,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryVariant,
    secondaryFixed: secondaryVariant,
    secondaryFixedDim: secondaryVariant,
    onSecondaryFixed: onSecondaryVariant,
    onSecondaryFixedVariant: onSecondaryContainerVariant,
    tertiary: tertiaryContainer,
    onTertiary: onTertiaryContainer,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    tertiaryFixed: tertiaryContainerVariant,
    tertiaryFixedDim: tertiaryContainerVariant,
    onTertiaryFixed: onTertiaryContainer,
    onTertiaryFixedVariant: tertiaryContainerVariant,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceDim: surfaceContainerHigh,
    surfaceBright: surfaceContainer,
    surfaceContainerLowest: surfaceVariant,
    surfaceContainerLow: secondaryVariant,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurfaceVariant: onSurfaceVariantSummary,
    outline: onSurfaceVariantSummary,
    outlineVariant: dividerLine,
    shadow: Colors.black,
    scrim: windowDimming,
    surfaceTint: Colors.transparent,
    inverseSurface: onSecondaryVariant,
    onInverseSurface: secondaryVariant,
  );

  /// 用 miuix 的角色体系描述一个已经算好的 Material 配色。
  ///
  /// 这是 miuix `mapMd3RolesToMiuixColorsCommon` 的逆过程，用于动态取色（Monet）与用户
  /// 挑选的种子色：配色依然由 Material 的颜色工具生成，但角色被翻译成 MIUI 的语义，
  /// 于是应用的填充、选中态与次级文字色都符合 miuix 的取色方式。miuix 会把带透明度的
  /// 前景色（禁用态、滑轨背景、次级文字）压在不透明底色上，这里照做。
  factory MiuixColors.fromColorScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final baseSurface = scheme.surface;
    final baseSurfaceContainerHigh = scheme.surfaceContainerHigh;

    final disabledPrimary = _opaqueOver(
      scheme.primary.withValues(alpha: 0.38),
      baseSurface,
    );
    final disabledOnPrimary = _opaqueOver(
      scheme.onPrimary.withValues(alpha: 0.38),
      disabledPrimary,
    );
    final disabledPrimaryButton = _opaqueOver(
      scheme.primary.withValues(alpha: 0.38),
      baseSurface,
    );
    final disabledOnPrimaryButton = _opaqueOver(
      scheme.onPrimary.withValues(alpha: 0.6),
      disabledPrimaryButton,
    );
    final disabledSecondary = _opaqueOver(
      scheme.outlineVariant.withValues(alpha: 0.5),
      baseSurface,
    );
    final disabledOnSecondary = _opaqueOver(
      scheme.onSurface.withValues(alpha: 0.38),
      disabledSecondary,
    );
    final disabledSecondaryVariant = _opaqueOver(
      scheme.surfaceContainerHigh.withValues(alpha: 0.6),
      baseSurface,
    );
    final disabledOnSecondaryVariant = _opaqueOver(
      scheme.onSurface.withValues(alpha: 0.38),
      disabledSecondaryVariant,
    );

    return MiuixColors(
      brightness: scheme.brightness,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      primaryVariant: scheme.primaryFixed,
      onPrimaryVariant: scheme.onPrimaryFixed,
      error: scheme.error,
      onError: scheme.onError,
      errorContainer: scheme.errorContainer,
      onErrorContainer: scheme.onErrorContainer,
      disabledPrimary: disabledPrimary,
      disabledOnPrimary: disabledOnPrimary,
      disabledPrimaryButton: disabledPrimaryButton,
      disabledOnPrimaryButton: disabledOnPrimaryButton,
      disabledPrimarySlider: disabledPrimary,
      primaryContainer: scheme.primaryContainer,
      onPrimaryContainer: scheme.onPrimaryContainer,
      secondary: scheme.outlineVariant,
      onSecondary: scheme.outline,
      secondaryVariant: scheme.surfaceContainerHigh,
      onSecondaryVariant: scheme.onSurface,
      disabledSecondary: disabledSecondary,
      disabledOnSecondary: disabledOnSecondary,
      disabledSecondaryVariant: disabledSecondaryVariant,
      disabledOnSecondaryVariant: disabledOnSecondaryVariant,
      secondaryContainer: scheme.secondaryContainer,
      onSecondaryContainer: scheme.onSecondaryContainer,
      secondaryContainerVariant: scheme.surfaceContainerHighest,
      onSecondaryContainerVariant: scheme.onSurfaceVariant,
      tertiaryContainer: scheme.tertiaryContainer,
      onTertiaryContainer: scheme.onTertiaryContainer,
      tertiaryContainerVariant: scheme.onTertiaryContainer,
      // Material 的 ColorScheme 没有 background / surfaceVariant 角色了，miuix 的语义
      // 由 surface 与 surfaceContainer 承担。
      background: scheme.surface,
      onBackground: scheme.onSurface,
      onBackgroundVariant: scheme.primary,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      surfaceVariant: scheme.surfaceContainer,
      onSurfaceSecondary: _opaqueOver(
        scheme.onSurface.withValues(alpha: 0.8),
        baseSurface,
      ),
      onSurfaceVariantSummary: scheme.onSurfaceVariant,
      onSurfaceVariantActions: scheme.onSurfaceVariant,
      disabledOnSurface: scheme.onSurface,
      surfaceContainer: scheme.surfaceContainer,
      onSurfaceContainer: scheme.onSurface,
      onSurfaceContainerVariant: scheme.onSurfaceVariant,
      surfaceContainerHigh: scheme.surfaceContainerHigh,
      onSurfaceContainerHigh: _opaqueOver(
        scheme.onSurface.withValues(alpha: 0.8),
        baseSurfaceContainerHigh,
      ),
      surfaceContainerHighest: scheme.surfaceContainerHighest,
      onSurfaceContainerHighest: scheme.onSurface,
      outline: scheme.outline,
      dividerLine: scheme.outlineVariant,
      windowDimming: dark
          ? const Color(0x99000000)
          : const Color(0x4D000000),
      sliderKeyPoint: scheme.primary,
      sliderKeyPointForeground: scheme.surfaceContainerHigh,
      sliderBackground: _opaqueOver(
        scheme.primary.withValues(alpha: 0.2),
        baseSurface,
      ),
    );
  }
}

/// 把 [foreground] 压在 [background] 上，返回不透明的结果，等价于 miuix 的
/// `ensureOpaqueOver`。
Color _opaqueOver(Color foreground, Color background) =>
    Color.alphaBlend(foreground, background);

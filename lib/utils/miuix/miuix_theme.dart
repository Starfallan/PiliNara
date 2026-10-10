import 'package:PiliPlus/utils/miuix/miuix_colors.dart';
import 'package:PiliPlus/utils/miuix/miuix_indication.dart';
import 'package:PiliPlus/utils/miuix/miuix_shapes.dart';
import 'package:PiliPlus/utils/miuix/miuix_squircle.dart';
import 'package:PiliPlus/utils/miuix/miuix_text_styles.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoThemeData;
import 'package:material_ui/material_ui.dart';

/// 用 miuix 的令牌构造 PiliNara 的 [ThemeData]。
///
/// 配色来自 [MiuixColors]，几何来自 [MiuixShapes]，字阶来自 [miuixTextTheme]；组件主题按
/// miuix 各组件的默认值书写，例如
///
/// * Card 用 `surfaceContainer` 且圆角 16、无阴影（miuix 的 Card 是平的）；
/// * 对话框底色用 `background`、圆角 32；
/// * 底部弹层底色用 `background`、上方两角 28；
/// * 弹出菜单用 `surfaceContainer`、圆角 16；
/// * 顶部栏高 52、底色用 `surface`；
/// * Snackbar 底色用 `onSecondaryVariant`（即深色条 + 浅色文字）、圆角 16；
/// * 提示气泡用 `surfaceContainer`、圆角 12；
/// * 开关/滑块的选中态用 `primary`，未选中的填充与轨道用 `secondary`、`sliderBackground`。
///
/// 除了配色与几何，这里还把 miuix 的几项界面特性接进主题：
///
/// * 连续圆角（squircle）：卡片、对话框、弹层、菜单、按钮与导航项都用 [MiuixSquircleBorder]，
///   也就是 MIUI / HyperOS 的"连续圆角"，而不是普通圆弧；
/// * 按压反馈换成 miuix 的整块淡入（[MiuixIndication]），替换掉 Material 的水波纹；
/// * 输入框是 MIUI 的填充样式：`secondaryContainer` 底色、16 连续圆角、无描边。
abstract final class MiuixTheme {
  /// 构造 miuix 主题。
  ///
  /// [fontFamily] 与 [fontWeight] 来自应用的字体偏好，会覆盖到全部文字样式上；
  /// [isDynamic] 表示当前配色由动态取色得到，miuix 在这个模式下对开关的未选中滑块用
  /// `onSurface` 的 38% 透明度（否则用 `onSecondary`）。
  static ThemeData getThemeData({
    required MiuixColors colors,
    String? fontFamily,
    FontWeight? fontWeight,
    bool isDynamic = false,
  }) {
    final scheme = colors.toColorScheme();
    final textTheme = miuixTextTheme(
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      // 组件（ListTile、Card、对话框标题等）从 TextTheme 的角色里取字色，Miui 的白字
      // 必须写进去，否则深色模式下会按黑色渲染。
      color: colors.onSurface,
    );
    final uncheckedThumbColor = isDynamic
        ? colors.onSurface.withValues(alpha: 0.38)
        : colors.onSecondary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: MiuixShapes.topBarHeight,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
          color: colors.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.surfaceContainer,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: colors.onSurfaceContainer),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: fontWeight,
            fontFamily: fontFamily,
            color: colors.onSurfaceContainer,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.surfaceContainer,
        indicatorShape: const MiuixSquircleBorder(
          cornerRadius: MiuixShapes.navigationItemCornerRadius,
        ),
      ),
      splashFactory: MiuixIndication(colors.onSurface),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: const MiuixSquircleBorder(
          cornerRadius: MiuixShapes.snackbarCornerRadius,
        ),
        actionTextColor: colors.primary,
        closeIconColor: colors.primary,
        backgroundColor: colors.onSecondaryVariant,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          fontSize: 14,
          color: colors.secondaryVariant,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainer,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const MiuixSquircleBorder(
          cornerRadius: MiuixShapes.menuCornerRadius,
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: colors.onSurfaceContainer,
            fontSize: 14,
            letterSpacing: 0.1,
            fontWeight: FontWeight.w500,
            fontFamily: fontFamily,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const MiuixSquircleBorder(
          cornerRadius: MiuixShapes.navigationItemCornerRadius,
        ),
        controlAffinity: ListTileControlAffinity.leading,
        iconColor: colors.onSurfaceVariantSummary,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surfaceContainer,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const MiuixSquircleBorder(
          cornerRadius: MiuixShapes.cardCornerRadius,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        // ignore: deprecated_member_use
        year2023: false,
        color: colors.primary,
        linearTrackColor: colors.secondaryContainer,
        circularTrackColor: colors.secondaryContainer,
        refreshBackgroundColor: colors.secondaryVariant,
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
          color: colors.onBackground,
        ),
        backgroundColor: colors.background,
        shape: const MiuixSquircleBorder(
          cornerRadius: MiuixShapes.dialogCornerRadius,
        ),
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        modalBackgroundColor: colors.background,
        elevation: 0,
        modalElevation: 0,
        shape: const MiuixSquircleBorder(
          cornerRadius: MiuixShapes.bottomSheetCornerRadius,
          topOnly: true,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        overlayColor: Colors.transparent,
        thumbColor: colors.onPrimary,
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.sliderBackground,
        disabledThumbColor: colors.disabledOnPrimary,
        disabledActiveTrackColor: colors.disabledPrimarySlider,
        disabledInactiveTrackColor: colors.disabledSecondary,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: TextStyle(
          fontSize: 14,
          color: colors.onSurfaceContainer,
          fontFamily: fontFamily,
          fontWeight: fontWeight,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: MiuixShapes.tooltipRadius,
        ),
      ),
      switchTheme: SwitchThemeData(
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return states.contains(WidgetState.selected)
                ? colors.disabledPrimary
                : colors.disabledSecondary;
          }
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.secondary;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return states.contains(WidgetState.selected)
                ? colors.disabledOnPrimary
                : colors.disabledOnSecondary;
          }
          return states.contains(WidgetState.selected)
              ? colors.onPrimary
              : uncheckedThumbColor;
        }),
        thumbIcon: const WidgetStateProperty<Icon?>.fromMap(
          <WidgetStatesConstraint, Icon?>{
            WidgetState.selected: Icon(Icons.done),
            WidgetState.any: null,
          },
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? colors.disabledPrimaryButton
                : colors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? colors.disabledOnPrimaryButton
                : colors.onPrimary;
          }),
          shape: const WidgetStatePropertyAll(
            MiuixSquircleBorder(cornerRadius: MiuixShapes.buttonCornerRadius),
          ),
        ),
      ),
      // MIUI 的输入框：填充式、16 连续圆角、平时不描边，聚焦或报错时才出现细边。
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.secondaryContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: const MiuixSquircleInputBorder(),
        enabledBorder: const MiuixSquircleInputBorder(),
        focusedBorder: MiuixSquircleInputBorder(
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: MiuixSquircleInputBorder(
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        focusedErrorBorder: MiuixSquircleInputBorder(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          fontSize: 14,
          color: colors.onSurfaceVariantSummary,
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        selectionHandleColor: colors.primary,
      ),
    );
  }
}

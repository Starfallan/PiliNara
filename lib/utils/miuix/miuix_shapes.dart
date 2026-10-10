import 'package:material_ui/material_ui.dart';

/// miuix 的几何令牌。
///
/// 数值取自 miuix 各组件的 Defaults 常量：MIUI 的形状语言很统一，圆角集中在 16 一档，
/// 只有对话框（32）、底部弹层（28）与浮起工具条（50，即半高、胶囊形）例外。
///
/// miuix 在 Android 上默认使用连续圆角（squircle），Flutter 的 [BorderRadius] 只支持普通
/// 圆角，这里就地取同样的半径，形状在视觉上接近但不完全等同。
abstract final class MiuixShapes {
  /// ButtonDefaults.CornerRadius
  static const double buttonCornerRadius = 16;

  /// CardDefaults.CornerRadius
  static const double cardCornerRadius = 16;

  /// DialogDefaults.CornerRadius
  static const double dialogCornerRadius = 32;

  /// CascadingPopupCornerRadius，用于弹出菜单。
  static const double menuCornerRadius = 16;

  /// TextFieldDefaults.CornerRadius
  static const double textFieldCornerRadius = 16;

  /// NavigationRailDefaults.ExpandedItemCornerRadius，用于导航项的高亮。
  static const double navigationItemCornerRadius = 16;

  /// SnackbarDefaults.CornerRadius
  static const double snackbarCornerRadius = 16;

  /// SnackbarDefaults.ActionCornerRadius
  static const double snackbarActionCornerRadius = 50;

  /// TooltipDefaults.PlainTooltipCornerRadius
  static const double tooltipCornerRadius = 12;

  /// TooltipDefaults.RichTooltipCornerRadius
  static const double richTooltipCornerRadius = 16;

  /// FloatingToolbarDefaults.CornerRadius，浮起导航栏与工具条用胶囊形。
  static const double floatingBarCornerRadius = 50;

  /// BottomSheetContentLayoutDefaults.cornerRadius
  static const double bottomSheetCornerRadius = 28;

  /// BottomSheetContentLayoutDefaults.maxWidth
  static const double bottomSheetMaxWidth = 640;

  /// BottomSheetContentLayoutDefaults.insideMargin 的水平内边距。
  static const double bottomSheetInsideMargin = 24;

  /// TopAppBarDefaults.CollapsedHeight
  static const double topBarHeight = 52;

  /// TopAppBarDefaults.TitlePadding
  static const double topBarTitlePadding = 26;

  /// TopAppBarDefaults.NavigationIconPadding
  static const double topBarIconPadding = 16;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(cardCornerRadius),
  );

  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(buttonCornerRadius),
  );

  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(dialogCornerRadius),
  );

  static const BorderRadius menuRadius = BorderRadius.all(
    Radius.circular(menuCornerRadius),
  );

  static const BorderRadius navigationItemRadius = BorderRadius.all(
    Radius.circular(navigationItemCornerRadius),
  );

  static const BorderRadius snackbarRadius = BorderRadius.all(
    Radius.circular(snackbarCornerRadius),
  );

  static const BorderRadius tooltipRadius = BorderRadius.all(
    Radius.circular(tooltipCornerRadius),
  );

  /// 底部弹层只圆上面两个角。
  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(bottomSheetCornerRadius),
  );
}

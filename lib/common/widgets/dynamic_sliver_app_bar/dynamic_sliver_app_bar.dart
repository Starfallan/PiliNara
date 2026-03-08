/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliPlus.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/dynamic_sliver_app_bar/rendering/sliver_persistent_header.dart';
import 'package:PiliPlus/common/widgets/dynamic_sliver_app_bar/sliver_persistent_header.dart';
import 'package:PiliPlus/common/widgets/only_layout_widget.dart'
    show LayoutCallback;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    hide SliverPersistentHeader, SliverPersistentHeaderDelegate;
import 'package:flutter/services.dart';

/// ref [SliverAppBar]
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.leading,
    required this.automaticallyImplyLeading,
    required this.title,
    required this.actions,
    required this.automaticallyImplyActions,
    required this.flexibleSpace,
    required this.bottom,
    required this.elevation,
    required this.scrolledUnderElevation,
    required this.shadowColor,
    required this.surfaceTintColor,
    required this.forceElevated,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconTheme,
    required this.actionsIconTheme,
    required this.primary,
    required this.centerTitle,
    required this.excludeHeaderSemantics,
    required this.titleSpacing,
    required this.collapsedHeight,
    required this.topPadding,
    required this.shape,
    required this.toolbarHeight,
    required this.leadingWidth,
    required this.toolbarTextStyle,
    required this.titleTextStyle,
    required this.systemOverlayStyle,
    required this.forceMaterialTransparency,
    required this.useDefaultSemanticsOrder,
    required this.clipBehavior,
    required this.actionsPadding,
  }) : assert(primary || topPadding == 0.0),
       _bottomHeight = bottom?.preferredSize.height ?? 0.0;

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget title;
  final List<Widget>? actions;
  final bool automaticallyImplyActions;
  final Widget flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final double? scrolledUnderElevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final bool forceElevated;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final bool primary;
  final bool? centerTitle;
  final bool excludeHeaderSemantics;
  final double? titleSpacing;
  final double collapsedHeight;
  final double topPadding;
  final ShapeBorder? shape;
  final double? toolbarHeight;
  final double? leadingWidth;
  final TextStyle? toolbarTextStyle;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final double _bottomHeight;
  final bool forceMaterialTransparency;
  final bool useDefaultSemanticsOrder;
  final Clip? clipBehavior;
  final EdgeInsetsGeometry? actionsPadding;

  @override
  double get minExtent => collapsedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
    double? maxExtent,
  ) {
    maxExtent ??= double.infinity;
    final bool isScrolledUnder =
        overlapsContent ||
        forceElevated ||
        (shrinkOffset > maxExtent - minExtent);
    final effectiveTitle = AnimatedOpacity(
      opacity: isScrolledUnder ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
      child: title,
    );

    return FlexibleSpaceBar.createSettings(
      minExtent: minExtent,
      maxExtent: maxExtent,
      currentExtent: math.max(minExtent, maxExtent - shrinkOffset),
      isScrolledUnder: isScrolledUnder,
      hasLeading: leading != null || automaticallyImplyLeading,
      child: AppBar(
        clipBehavior: clipBehavior,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        title: effectiveTitle,
        actions: actions,
        automaticallyImplyActions: automaticallyImplyActions,
        flexibleSpace: maxExtent == .infinity
            ? flexibleSpace
            : IgnorePointer(
                ignoring: isScrolledUnder,
                child: FlexibleSpaceBar(background: flexibleSpace),
              ),
        bottom: bottom,
        elevation: isScrolledUnder ? elevation : 0.0,
        scrolledUnderElevation: scrolledUnderElevation,
        shadowColor: shadowColor,
        surfaceTintColor: surfaceTintColor,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        iconTheme: iconTheme,
        actionsIconTheme: actionsIconTheme,
        primary: primary,
        centerTitle: centerTitle,
        excludeHeaderSemantics: excludeHeaderSemantics,
        titleSpacing: titleSpacing,
        shape: shape,
        toolbarHeight: toolbarHeight,
        leadingWidth: leadingWidth,
        toolbarTextStyle: toolbarTextStyle,
        titleTextStyle: titleTextStyle,
        systemOverlayStyle: systemOverlayStyle,
        forceMaterialTransparency: forceMaterialTransparency,
        useDefaultSemanticsOrder: useDefaultSemanticsOrder,
        actionsPadding: actionsPadding,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return leading != oldDelegate.leading ||
        automaticallyImplyLeading != oldDelegate.automaticallyImplyLeading ||
        title != oldDelegate.title ||
        actions != oldDelegate.actions ||
        automaticallyImplyActions != oldDelegate.automaticallyImplyActions ||
        flexibleSpace != oldDelegate.flexibleSpace ||
        bottom != oldDelegate.bottom ||
        _bottomHeight != oldDelegate._bottomHeight ||
        elevation != oldDelegate.elevation ||
        shadowColor != oldDelegate.shadowColor ||
        backgroundColor != oldDelegate.backgroundColor ||
        foregroundColor != oldDelegate.foregroundColor ||
        iconTheme != oldDelegate.iconTheme ||
        actionsIconTheme != oldDelegate.actionsIconTheme ||
        primary != oldDelegate.primary ||
        centerTitle != oldDelegate.centerTitle ||
        titleSpacing != oldDelegate.titleSpacing ||
        topPadding != oldDelegate.topPadding ||
        forceElevated != oldDelegate.forceElevated ||
        toolbarHeight != oldDelegate.toolbarHeight ||
        leadingWidth != oldDelegate.leadingWidth ||
        toolbarTextStyle != oldDelegate.toolbarTextStyle ||
        titleTextStyle != oldDelegate.titleTextStyle ||
        systemOverlayStyle != oldDelegate.systemOverlayStyle ||
        forceMaterialTransparency != oldDelegate.forceMaterialTransparency ||
        useDefaultSemanticsOrder != oldDelegate.useDefaultSemanticsOrder ||
        actionsPadding != oldDelegate.actionsPadding;
  }

  @override
  String toString() {
    return '${describeIdentity(this)}(topPadding: ${topPadding.toStringAsFixed(1)}, bottomHeight: ${_bottomHeight.toStringAsFixed(1)}, ...)';
  }
}

class DynamicSliverAppBar extends StatefulWidget {
  const DynamicSliverAppBar.medium({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    required this.title,
    this.actions,
    this.automaticallyImplyActions = true,
    required this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.forceElevated = false,
    this.backgroundColor,
    this.foregroundColor,
    this.iconTheme,
    this.actionsIconTheme,
    this.primary = true,
    this.centerTitle,
    this.excludeHeaderSemantics = false,
    this.titleSpacing,
    this.shape,
    this.leadingWidth,
    this.toolbarTextStyle,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.forceMaterialTransparency = false,
    this.useDefaultSemanticsOrder = true,
    this.clipBehavior,
    this.actionsPadding,
    this.onPerformLayout,
  });

  final LayoutCallback? onPerformLayout;

  final Widget? leading;

  final bool automaticallyImplyLeading;

  final Widget title;

  final List<Widget>? actions;

  final bool automaticallyImplyActions;

  final Widget flexibleSpace;

  final PreferredSizeWidget? bottom;

  final double? elevation;

  final double? scrolledUnderElevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final bool forceElevated;

  final Color? backgroundColor;

  final Color? foregroundColor;

  final IconThemeData? iconTheme;

  final IconThemeData? actionsIconTheme;

  final bool primary;

  final bool? centerTitle;

  final bool excludeHeaderSemantics;

  final double? titleSpacing;

  final ShapeBorder? shape;

  final double? leadingWidth;

  final TextStyle? toolbarTextStyle;

  final TextStyle? titleTextStyle;

  final SystemUiOverlayStyle? systemOverlayStyle;

  final bool forceMaterialTransparency;

  final bool useDefaultSemanticsOrder;

  final Clip? clipBehavior;

  final EdgeInsetsGeometry? actionsPadding;

  @override
  State<DynamicSliverAppBar> createState() => _DynamicSliverAppBarState();
}

class _DynamicSliverAppBarState extends State<DynamicSliverAppBar> {
  @override
  Widget build(BuildContext context) {
    final double bottomHeight = widget.bottom?.preferredSize.height ?? 0.0;
    final double topPadding = widget.primary
        ? MediaQuery.viewPaddingOf(context).top
        : 0.0;
    final double effectiveCollapsedHeight =
        topPadding + kToolbarHeight + bottomHeight + 1;

    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: SliverPinnedHeader(
        onPerformLayout: widget.onPerformLayout,
        delegate: _SliverAppBarDelegate(
          leading: widget.leading,
          automaticallyImplyLeading: widget.automaticallyImplyLeading,
          title: widget.title,
          actions: widget.actions,
          automaticallyImplyActions: widget.automaticallyImplyActions,
          flexibleSpace: widget.flexibleSpace,
          bottom: widget.bottom,
          elevation: widget.elevation,
          scrolledUnderElevation: widget.scrolledUnderElevation,
          shadowColor: widget.shadowColor,
          surfaceTintColor: widget.surfaceTintColor,
          forceElevated: widget.forceElevated,
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          iconTheme: widget.iconTheme,
          actionsIconTheme: widget.actionsIconTheme,
          primary: widget.primary,
          centerTitle: widget.centerTitle,
          excludeHeaderSemantics: widget.excludeHeaderSemantics,
          titleSpacing: widget.titleSpacing,
          collapsedHeight: effectiveCollapsedHeight,
          topPadding: topPadding,
          shape: widget.shape,
          toolbarHeight: kToolbarHeight,
          leadingWidth: widget.leadingWidth,
          toolbarTextStyle: widget.toolbarTextStyle,
          titleTextStyle: widget.titleTextStyle,
          systemOverlayStyle: widget.systemOverlayStyle,
          forceMaterialTransparency: widget.forceMaterialTransparency,
          useDefaultSemanticsOrder: widget.useDefaultSemanticsOrder,
          clipBehavior: widget.clipBehavior,
          actionsPadding: widget.actionsPadding,
        ),
      ),
    );
  }
}

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

import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/models/common/image_preview_type.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/gestures.dart'
    show TapGestureRecognizer, LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        ContainerRenderObjectMixin,
        RenderBoxContainerDefaultsMixin,
        MultiChildLayoutParentData,
        BoxHitTestResult,
        BoxHitTestEntry;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';

class ImageModel {
  ImageModel({
    required num? width,
    required num? height,
    required this.url,
    this.liveUrl,
  }) {
    this.width = width == null || width == 0 ? 1 : width;
    this.height = height == null || height == 0 ? 1 : height;
  }

  late num width;
  late num height;
  String url;
  String? liveUrl;
  bool? _isLongPic;
  bool? _isLivePhoto;

  bool get isLongPic =>
      _isLongPic ??= (height / width) > StyleString.imgMaxRatio;
  bool get isLivePhoto =>
      _isLivePhoto ??= enableLivePhoto && liveUrl?.isNotEmpty == true;

  static bool enableLivePhoto = Pref.enableLivePhoto;
}

class CustomGridView extends StatelessWidget {
  const CustomGridView({
    super.key,
    this.space = 5,
    required this.maxWidth,
    required this.picArr,
    this.onViewImage,
    this.fullScreen = false,
  });

  final double maxWidth;
  final double space;
  final List<ImageModel> picArr;
  final VoidCallback? onViewImage;
  final bool fullScreen;

  static bool horizontalPreview = Pref.horizontalPreview;
  static const _routes = ['/videoV', '/dynamicDetail'];

  void onTap(BuildContext context, int index) {
    final imgList = picArr.map(
      (item) {
        bool isLive = item.isLivePhoto;
        return SourceModel(
          sourceType: isLive ? SourceType.livePhoto : SourceType.networkImage,
          url: item.url,
          liveUrl: isLive ? item.liveUrl : null,
          width: isLive ? item.width.toInt() : null,
          height: isLive ? item.height.toInt() : null,
          isLongPic: item.isLongPic,
        );
      },
    ).toList();
    if (horizontalPreview &&
        !fullScreen &&
        _routes.contains(Get.currentRoute) &&
        !context.mediaQuerySize.isPortrait) {
      final scaffoldState = Scaffold.maybeOf(context);
      if (scaffoldState != null) {
        onViewImage?.call();
        PageUtils.onHorizontalPreviewState(
          scaffoldState,
          imgList,
          index,
        );
        return;
      }
    }
    PageUtils.imageView(
      initialPage: index,
      imgList: imgList,
    );
  }

  static BorderRadius _borderRadius(
    int col,
    int length,
    int index, {
    Radius r = StyleString.imgRadius,
  }) {
    if (length == 1) return StyleString.mdRadius;

    final bool hasUp = index - col >= 0;
    final bool hasDown = index + col < length;

    final bool isRowStart = (index % col) == 0;
    final bool isRowEnd = (index % col) == col - 1 || index == length - 1;

    final bool hasLeft = !isRowStart;
    final bool hasRight = !isRowEnd && (index + 1) < length;

    return BorderRadius.only(
      topLeft: !hasUp && !hasLeft ? r : Radius.zero,
      topRight: !hasUp && !hasRight ? r : Radius.zero,
      bottomLeft: !hasDown && !hasLeft ? r : Radius.zero,
      bottomRight: !hasDown && !hasRight ? r : Radius.zero,
    );
  }

  static bool enableImgMenu = Pref.enableImgMenu;

  void _showMenu(BuildContext context, int index, Offset offset) {
    HapticFeedback.mediumImpact();
    final item = picArr[index];
    showMenu(
      context: context,
      position: PageUtils.menuPosition(offset),
      items: [
        if (PlatformUtils.isMobile)
          PopupMenuItem(
            height: 42,
            onTap: () => ImageUtils.onShareImg(item.url),
            child: const Text('分享', style: TextStyle(fontSize: 14)),
          ),
        PopupMenuItem(
          height: 42,
          onTap: () => ImageUtils.downloadImg([item.url]),
          child: const Text('保存图片', style: TextStyle(fontSize: 14)),
        ),
        if (PlatformUtils.isDesktop)
          PopupMenuItem(
            height: 42,
            onTap: () => PageUtils.launchURL(item.url),
            child: const Text('网页打开', style: TextStyle(fontSize: 14)),
          )
        else if (picArr.length > 1)
          PopupMenuItem(
            height: 42,
            onTap: () =>
                ImageUtils.downloadImg(picArr.map((item) => item.url).toList()),
            child: const Text('保存全部', style: TextStyle(fontSize: 14)),
          ),
        if (item.isLivePhoto)
          PopupMenuItem(
            height: 42,
            onTap: () => ImageUtils.downloadLivePhoto(
              url: item.url,
              liveUrl: item.liveUrl!,
              width: item.width.toInt(),
              height: item.height.toInt(),
            ),
            child: Text(
              '保存${Platform.isIOS ? '实况' : '视频'}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double imageWidth;
    double imageHeight;
    final length = picArr.length;
    final isSingle = length == 1;
    final isFour = length == 4;
    if (length == 2) {
      imageWidth = imageHeight = (maxWidth - space) / 2;
    } else {
      imageHeight = imageWidth = (maxWidth - 2 * space) / 3;
      if (isSingle) {
        final img = picArr.first;
        final width = img.width;
        final height = img.height;
        final ratioWH = width / height;
        final ratioHW = height / width;
        imageWidth = ratioWH > 1.5
            ? maxWidth
            : (ratioWH >= 1 || (height > width && ratioHW < 1.5))
            ? 2 * imageWidth
            : 1.5 * imageWidth;
        if (width != 1) {
          imageWidth = min(imageWidth, width.toDouble());
        }
        imageHeight = imageWidth * min(ratioHW, StyleString.imgMaxRatio);
      }
    }

    final int column = isFour ? 2 : 3;
    final int row = isFour ? 2 : (length / 3).ceil();
    late final placeHolder = Container(
      width: imageWidth,
      height: imageHeight,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.onInverseSurface.withValues(alpha: 0.4),
      ),
      child: Image.asset(
        'assets/images/loading.png',
        width: imageWidth,
        height: imageHeight,
        cacheWidth: imageWidth.cacheSize(context),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: maxWidth,
        height: imageHeight * row + space * (row - 1),
        child: ImageGrid(
          space: space,
          column: column,
          width: imageWidth,
          height: imageHeight,
          onTap: (index) => onTap(context, index),
          onSecondaryTapUp: enableImgMenu && PlatformUtils.isDesktop
              ? (index, offset) => _showMenu(context, index, offset)
              : null,
          onLongPressStart: enableImgMenu && PlatformUtils.isMobile
              ? (index, offset) => _showMenu(context, index, offset)
              : null,
          children: List.generate(length, (index) {
            final item = picArr[index];
            final borderRadius = _borderRadius(column, length, index);
            Widget child = Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                NetworkImgLayer(
                  src: item.url,
                  width: imageWidth,
                  height: imageHeight,
                  borderRadius: borderRadius,
                  alignment: item.isLongPic ? .topCenter : .center,
                  cacheWidth: item.width <= item.height,
                  getPlaceHolder: () => placeHolder,
                ),
                if (item.isLivePhoto)
                  const PBadge(
                    text: 'Live',
                    right: 8,
                    bottom: 8,
                    type: PBadgeType.gray,
                  )
                else if (item.isLongPic)
                  const PBadge(
                    text: '长图',
                    right: 8,
                    bottom: 8,
                  ),
              ],
            );
            if (!item.isLongPic) {
              child = Hero(
                tag: item.url,
                child: child,
              );
            }
            return LayoutId(
              id: index,
              child: child,
            );
          }),
        ),
      ),
    );
  }
}

class ImageGrid extends MultiChildRenderObjectWidget {
  const ImageGrid({
    super.key,
    super.children,
    required this.space,
    required this.column,
    required this.width,
    required this.height,
    required this.onTap,
    required this.onSecondaryTapUp,
    required this.onLongPressStart,
  });

  final double space;
  final int column;
  final double width;
  final double height;
  final ValueChanged<int> onTap;
  final OnShowMenu? onSecondaryTapUp;
  final OnShowMenu? onLongPressStart;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderImageGrid(
      space: space,
      column: column,
      width: width,
      height: height,
      onTap: onTap,
      onSecondaryTapUp: onSecondaryTapUp,
      onLongPressStart: onLongPressStart,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderImageGrid renderObject) {
    renderObject
      ..space = space
      ..column = column
      ..width = width
      ..height = height
      ..onTap = onTap
      ..onSecondaryTapUp = onSecondaryTapUp
      ..onLongPressStart = onLongPressStart;
  }
}

typedef OnShowMenu = Function(int index, Offset offset);

class RenderImageGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  RenderImageGrid({
    required double space,
    required int column,
    required double width,
    required double height,
    required ValueChanged<int> onTap,
    required OnShowMenu? onSecondaryTapUp,
    required OnShowMenu? onLongPressStart,
  }) : _space = space,
       _column = column,
       _width = width,
       _height = height,
       _onTap = onTap,
       _onSecondaryTapUp = onSecondaryTapUp,
       _onLongPressStart = onLongPressStart {
    _tapGestureRecognizer = TapGestureRecognizer()..onTap = _handleOnTap;
    if (onSecondaryTapUp != null) {
      _tapGestureRecognizer.onSecondaryTapUp = _handleSecondaryTapUp;
    }
    if (onLongPressStart != null) {
      _longPressGestureRecognizer = LongPressGestureRecognizer()
        ..onLongPressStart = _handleLongPressStart;
    }
  }

  ValueChanged<int> _onTap;
  set onTap(ValueChanged<int> value) {
    _onTap = value;
  }

  OnShowMenu? _onSecondaryTapUp;
  set onSecondaryTapUp(OnShowMenu? value) {
    _onSecondaryTapUp = value;
  }

  OnShowMenu? _onLongPressStart;
  set onLongPressStart(OnShowMenu? value) {
    _onLongPressStart = value;
  }

  int? _index;

  void _handleOnTap() {
    _onTap(_index!);
  }

  void _handleSecondaryTapUp(TapUpDetails details) {
    _onSecondaryTapUp!(_index!, details.globalPosition);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _onLongPressStart!(_index!, details.globalPosition);
  }

  double _space;
  double get space => _space;
  set space(double value) {
    if (_space == value) return;
    _space = value;
    markNeedsLayout();
  }

  int _column;
  int get column => _column;
  set column(int value) {
    if (_column == value) return;
    _column = value;
    markNeedsLayout();
  }

  double _width;
  double get width => _width;
  set width(double value) {
    if (_width == value) return;
    _width = value;
    markNeedsLayout();
  }

  double _height;
  double get height => _height;
  set height(double value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.constrain(constraints.biggest);

    final itemConstraints = BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: height,
      maxHeight: height,
    );
    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as MultiChildLayoutParentData;
      final index = childParentData.id as int;
      child.layout(itemConstraints);
      childParentData.offset = Offset(
        (space + width) * (index % column),
        (space + height) * (index ~/ column),
      );
      child = childParentData.nextSibling;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final childParentData = child.parentData as MultiChildLayoutParentData;
      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          if (child!.size.contains(transformed)) {
            result.add(BoxHitTestEntry(child, transformed));
            return true;
          }
          return false;
        },
      );
      if (isHit) {
        _index = childParentData.id as int;
        return true;
      }
      child = childParentData.previousSibling;
    }
    _index = null;
    return false;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _tapGestureRecognizer.addPointer(event);
      _longPressGestureRecognizer?.addPointer(event);
    }
  }

  late final TapGestureRecognizer _tapGestureRecognizer;
  LongPressGestureRecognizer? _longPressGestureRecognizer;

  @override
  void dispose() {
    _tapGestureRecognizer
      ..onTap = null
      ..onSecondaryTapUp = null
      ..dispose();
    _longPressGestureRecognizer
      ?..onLongPressStart = null
      ..dispose();
    _longPressGestureRecognizer = null;
    _onSecondaryTapUp = null;
    _onLongPressStart = null;
    super.dispose();
  }

  @override
  bool get isRepaintBoundary => true; // gif repaint
}

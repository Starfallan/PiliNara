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

import 'package:PiliPlus/common/widgets/dynamic_sliver_app_bar/redering/sliver_persistent_header.dart';
import 'package:flutter/widgets.dart';

/// ref [SliverPersistentHeader]

abstract class SliverPersistentHeaderDelegate {
  const SliverPersistentHeaderDelegate();

  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
    double? maxExtent,
  );

  double get minExtent;

  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate);
}

class SliverPersistentHeaderElement extends RenderObjectElement {
  SliverPersistentHeaderElement(
    SliverPinnedHeader super.widget,
  );

  @override
  RenderSliverPinnedHeader get renderObject =>
      super.renderObject as RenderSliverPinnedHeader;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject.element = this;
  }

  @override
  void unmount() {
    renderObject.element = null;
    super.unmount();
  }

  @override
  void update(SliverPinnedHeader newWidget) {
    final oldWidget = widget as SliverPinnedHeader;
    super.update(newWidget);
    final SliverPersistentHeaderDelegate newDelegate = newWidget.delegate;
    final SliverPersistentHeaderDelegate oldDelegate = oldWidget.delegate;
    if (newDelegate != oldDelegate &&
        (newDelegate.runtimeType != oldDelegate.runtimeType ||
            newDelegate.shouldRebuild(oldDelegate))) {
      final RenderSliverPinnedHeader renderObject = this.renderObject;
      _updateChild(
        newDelegate,
        renderObject.lastShrinkOffset,
        renderObject.lastOverlapsContent,
        renderObject.maxExtent,
      );
      renderObject.triggerRebuild();
    }
  }

  @override
  void performRebuild() {
    super.performRebuild();
    renderObject.triggerRebuild();
  }

  Element? child;

  void _updateChild(
    SliverPersistentHeaderDelegate delegate,
    double shrinkOffset,
    bool overlapsContent,
    double? maxExtent,
  ) {
    final Widget newWidget = delegate.build(
      this,
      shrinkOffset,
      overlapsContent,
      maxExtent,
    );
    child = updateChild(child, newWidget, null);
  }

  void build(double shrinkOffset, bool overlapsContent, double? maxExtent) {
    owner!.buildScope(this, () {
      final sliverPersistentHeaderRenderObjectWidget =
          widget as SliverPinnedHeader;
      _updateChild(
        sliverPersistentHeaderRenderObjectWidget.delegate,
        shrinkOffset,
        overlapsContent,
        maxExtent,
      );
    });
  }

  @override
  void forgetChild(Element child) {
    assert(child == this.child);
    this.child = null;
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(covariant RenderBox child, Object? slot) {
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
  }

  @override
  void moveRenderObjectChild(
    covariant RenderObject child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(covariant RenderObject child, Object? slot) {
    renderObject.child = null;
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (child != null) {
      visitor(child!);
    }
  }
}

import 'dart:async';

import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/waterfall.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class DynamicsTabPage extends StatefulWidget {
  const DynamicsTabPage({super.key, required this.dynamicsType});

  final DynamicsTabType dynamicsType;

  @override
  State<DynamicsTabPage> createState() => _DynamicsTabPageState();
}

class _DynamicsTabPageState extends State<DynamicsTabPage>
    with AutomaticKeepAliveClientMixin, DynMixin {
  final dynamicsController = Get.putOrFind(DynamicsController.new);
  late final DynamicsTabController controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    controller = Get.putOrFind(
      () => DynamicsTabController(dynamicsType: widget.dynamicsType),
      tag: widget.dynamicsType.name,
    );
    super.initState();
  }

  Future<void> onRefresh() {
    dynamicsController.singleRefresh();
    return controller.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      key: controller.refreshKey,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: controller.scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: buildPage(
              Obx(() => _buildBody(controller.loadingState.value)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LoadingState<List<DynamicItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => dynSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? _buildItems(response)
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget _buildItems(List<DynamicItemModel> items) {
    final supportsVisibility =
        widget.dynamicsType == DynamicsTabType.all ||
        widget.dynamicsType == DynamicsTabType.up;
    final hideText = supportsVisibility && Pref.hideTextDyn;
    final hideImage = supportsVisibility && Pref.hideImageDyn;

    bool isHidden(DynamicItemModel item) =>
        (hideText || hideImage) &&
        item.visible != false &&
        item.modules.moduleFold == null &&
        switch (item.contentType) {
          DynamicContentType.text => hideText,
          DynamicContentType.image => hideImage,
          null => false,
        };

    final lastIndex = items.length - 1;
    final hiddenTail = isHidden(items.last);
    final allHidden = items.every(isHidden);

    Widget itemBuilder(BuildContext context, int index) {
      final item = items[index];
      final isLast = index == lastIndex;
      if (isLast && !hiddenTail) controller.onLoadMore();
      return DynamicPanel(
        item: item,
        hidden: isHidden(item),
        onRemove: (idStr) => controller.onRemove(index, idStr),
        onBlock: () => controller.onBlock(index),
        onUnfold: () => controller.onUnfold(item, index),
        onUpdate: (newItem) {
          items[index] = newItem;
          controller.loadingState.refresh();
        },
      );
    }

    final list = GlobalData().dynamicsWaterfallFlow
        ? SliverMasonryGrid(
            crossAxisSpacing: 4,
            gridDelegate: dynGridDelegate,
            delegate: SliverChildBuilderDelegate(
              itemBuilder,
              childCount: items.length,
            ),
          )
        : SliverList.builder(itemBuilder: itemBuilder, itemCount: items.length);

    if (!hiddenTail) return list;
    final canLoadMore =
        !controller.isEnd && controller.offset?.isNotEmpty == true;
    return SliverMainAxisGroup(
      slivers: [
        list,
        SliverToBoxAdapter(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allHidden)
                  const Text(
                    '\u5f53\u524d\u9875\u9762\u52a8\u6001\u5747\u5df2\u9690\u85cf',
                  ),
                if (canLoadMore)
                  TextButton(
                    onPressed: () async {
                      await controller.onLoadMore();
                      if (mounted &&
                          (controller.isEnd ||
                              controller.offset?.isNotEmpty != true)) {
                        setState(() {});
                      }
                    },
                    child: const Text('\u52a0\u8f7d\u66f4\u591a'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

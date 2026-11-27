import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPlus/pages/member_dynamics/controller.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:PiliPlus/utils/waterfall.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MemberDynamicsPage extends StatefulWidget {
  const MemberDynamicsPage({super.key, this.mid});

  final int? mid;

  @override
  State<MemberDynamicsPage> createState() => _MemberDynamicsPageState();
}

class _MemberDynamicsPageState extends State<MemberDynamicsPage>
    with AutomaticKeepAliveClientMixin, DynMixin {
  late MemberDynamicsController _memberDynamicController;
  late int mid;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    mid = widget.mid ?? int.parse(Get.parameters['mid']!);
    final String heroTag = Utils.makeHeroTag(mid);
    _memberDynamicController = Get.put(
      MemberDynamicsController(mid),
      tag: heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final padding = MediaQuery.viewPaddingOf(context);
    return widget.mid == null
        ? SimpleScaffold(
            appBar: AppBar(title: const Text('我的动态')),
            body: Padding(
              padding: EdgeInsets.only(
                left: padding.left,
                right: padding.right,
              ),
              child: _buildBody(padding),
            ),
          )
        : _buildBody(padding);
  }

  Widget _buildBody(EdgeInsets padding) => refreshIndicator(
    isClampingScrollPhysics: widget.mid != null,
    onRefresh: _memberDynamicController.onRefresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(bottom: padding.bottom + 100),
          sliver: buildPage(
            Obx(
              () => _buildContent(_memberDynamicController.loadingState.value),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildContent(LoadingState<List<DynamicItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => dynSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? _buildItems(response)
            : HttpError(onReload: _memberDynamicController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _memberDynamicController.onReload,
      ),
    };
  }

  Widget _buildItems(List<DynamicItemModel> items) {
    final hideText = Pref.hideTextDyn;
    final hideImage = Pref.hideImageDyn;

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
      if (isLast && !hiddenTail) _memberDynamicController.onLoadMore();
      return DynamicPanel(
        item: item,
        hidden: isHidden(item),
        onRemove: _memberDynamicController.onRemove,
        onSetTop: _memberDynamicController.onSetTop,
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
        !_memberDynamicController.isEnd &&
        _memberDynamicController.offset != '-1';
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
                      await _memberDynamicController.onLoadMore();
                      if (mounted &&
                          (_memberDynamicController.isEnd ||
                              _memberDynamicController.offset == '-1')) {
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

import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

abstract class CommonSearchPanel extends StatefulWidget {
  const CommonSearchPanel({
    super.key,
    required this.keyword,
    required this.searchType,
    required this.tag,
  });

  final String keyword;
  final SearchType searchType;
  final String tag;
}

abstract class CommonSearchPanelState<
  S extends CommonSearchPanel,
  R extends SearchNumData<T>,
  T
>
    extends State<S>
    with AutomaticKeepAliveClientMixin {
  SearchPanelController<R, T> get controller;

  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    controller.cancelListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return refreshIndicator(
      onRefresh: controller.onRefresh,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ?buildHeader(theme),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
            ),
            sliver: Obx(() => _buildBody(theme, controller.loadingState.value)),
          ),
        ],
      ),
    );
  }

  Widget get buildLoading;

  Widget _buildBody(ThemeData theme, LoadingState<List<T>?> loadingState) {
    return switch (loadingState) {
      Loading() => buildLoading,
      Success(:final response) when response != null && response.isNotEmpty =>
        () {
          final filtered = controller.filterKeywords(response, getTitle);
          if (filtered.isEmpty) {
            return _buildFilteredOut(theme);
          }
          final showLoadMore = controller.hasKeywordFilter &&
              filtered.length <= 5;
          if (!showLoadMore) return buildList(theme, filtered);
          return SliverMainAxisGroup(
            slivers: [
              buildList(theme, filtered),
              _buildInlineLoadMore(theme),
            ],
          );
        }(),
      Success() => HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Future<void> _onLoadMoreWithCooldown() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      await controller.onLoadMore();
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Widget _buildFilteredOut(ThemeData theme) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_off,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                '当前页结果已被关键词过滤',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '可以继续加载更多结果，直到找到符合条件的内容',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed:
                    _isLoadingMore ? null : _onLoadMoreWithCooldown,
                icon: _isLoadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.keyboard_double_arrow_down, size: 18),
                label: Text(_isLoadingMore ? '加载中...' : '继续加载'),
              ),
              const SizedBox(height: 8),
              Text(
                '加载完成后方可进行下次加载，避免触发频率限制',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? buildHeader(ThemeData theme) => null;

  Widget _buildInlineLoadMore(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: FilledButton.tonalIcon(
            onPressed:
                _isLoadingMore ? null : _onLoadMoreWithCooldown,
            icon: _isLoadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.keyboard_double_arrow_down, size: 18),
            label: Text(_isLoadingMore ? '加载中...' : '继续加载'),
          ),
        ),
      ),
    );
  }

  String? getTitle(T item) => null;

  Widget buildList(ThemeData theme, List<T> list);
}

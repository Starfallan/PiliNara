import 'dart:async';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/bubble/dyn_list.dart';
import 'package:PiliPlus/pages/bubble/controller.dart';
import 'package:PiliPlus/services/bubble_read_service.dart';
import 'package:PiliPlus/utils/bili_colors.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:collection/collection.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide ListTile, SliverGridDelegateWithMaxCrossAxisExtent;

class BubblePage extends StatefulWidget {
  const BubblePage({super.key, this.categoryId});

  final String? categoryId;

  @override
  State<BubblePage> createState() => _BubblePageState();
}

class _BubblePageState extends State<BubblePage>
    with AutomaticKeepAliveClientMixin {
  late final BubbleController _controller;

  /// 小站页面令牌，用于单次模式在所有小站页退出后清空已读
  late final int _pageToken;

  @override
  void initState() {
    super.initState();
    _pageToken = BubbleReadService.enterPage();
    _controller = Get.put(
      BubbleController(widget.categoryId),
      tag: widget.categoryId ?? 'all',
    );
  }

  @override
  void dispose() {
    BubbleReadService.leavePage(_pageToken);
    super.dispose();
  }

  BubbleController currCtr([int? index]) {
    try {
      index ??= _controller.tabController!.index;
      if (index != 0) {
        return Get.find<BubbleController>(
          tag: _controller.tabs.value![index].id.toString(),
        );
      }
    } catch (_) {}
    return _controller;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final padding = MediaQuery.viewPaddingOf(context);
    Widget child = refreshIndicator(
      onRefresh: _controller.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _controller.scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(bottom: padding.bottom + 100),
            sliver: Obx(
              () => _buildBody(context, _controller.loadingState.value),
            ),
          ),
        ],
      ),
    );
    if (widget.categoryId != null) {
      return child;
    } else {
      child = ScaffoldLayout(
        body: child,
        fab: Padding(
          padding: .only(
            right: kFloatingActionButtonMargin,
            bottom: kFloatingActionButtonMargin + padding.bottom,
          ),
          child: Obx(
            () {
              final sortInfo = _controller.sortInfo.value;
              if (sortInfo == null || sortInfo.showSort != true) {
                return const SizedBox.shrink();
              }
              final item = sortInfo.sortItems?.firstWhereOrNull(
                (e) => e.sortType == sortInfo.curSortType,
              );
              if (item != null) {
                return FloatingActionButton.extended(
                  tooltip: '排序',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => SimpleDialog(
                      clipBehavior: .hardEdge,
                      contentPadding: const .symmetric(vertical: 12),
                      children: sortInfo.sortItems!.map(
                        (e) {
                          final isSelected = item.sortType == e.sortType;
                          return ListTile(
                            dense: true,
                            enabled: !isSelected,
                            onTap: () {
                              Get.back();
                              if (!isSelected) {
                                _controller.onSort(e.sortType);
                              }
                            },
                            title: Text(
                              e.text!,
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: isSelected
                                ? const Icon(size: 22, Icons.check)
                                : null,
                          );
                        },
                      ).toList(),
                    ),
                  ),
                  icon: const Icon(Icons.sort, size: 20),
                  label: Text(item.text!),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }
    return SimpleScaffold(
      appBar: AppBar(
        title: Obx(() {
          final tribeName = _controller.tribeName.value;
          if (tribeName == null) {
            return const SizedBox.shrink();
          }
          return Text('$tribeName小站');
        }),
      ),
      body: Padding(
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        child: Obx(() {
          final tabs = _controller.tabs.value;
          if (tabs == null || tabs.isEmpty) {
            return child;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                isScrollable: true,
                tabAlignment: .start,
                controller: _controller.tabController,
                onTap: (index) {
                  if (!_controller.tabController!.indexIsChanging) {
                    currCtr().scrollController.animToTop();
                  }
                },
                tabs: tabs.map((item) => Tab(text: item.name!)).toList(),
              ),
              Expanded(
                child: tabBarView(
                  controller: _controller.tabController,
                  children: [
                    KeepAliveWrapper(child: child),
                    ...tabs
                        .skip(1)
                        .map((item) => BubblePage(categoryId: item.id)),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// 打开帖子。停留满设置里的秒数才记为已读，提前返回不算。
  Future<void> _openPost(DynList item) async {
    final id = item.dynId;
    if (id == null) {
      return;
    }
    final delay = Pref.bubbleReadDelay;
    final marked = Pref.bubbleReadEnable;
    Timer? timer;
    if (marked) {
      timer = Timer(Duration(seconds: delay), () {
        BubbleReadService.markRead(id);
        if (mounted) {
          setState(() {});
        }
      });
    }
    await Get.toNamed(
      '/articlePage',
      parameters: {'id': id, 'type': 'opus'},
    );
    timer?.cancel();
  }

  late final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    mainAxisExtent: 56,
    maxCrossAxisExtent: 2 * Grid.smallCardWidth,
  );

  /// 置顶标。箭头在 web 端是 rotate(180deg)，这里用 RotatedBox 对应。
  Widget _topTag(ThemeData theme) => Container(
    width: 18,
    height: 18,
    margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
    ),
    alignment: Alignment.center,
    child: RotatedBox(
      quarterTurns: 2,
      child: SvgPicture.asset(
        Assets.bubbleTop,
        width: 12,
        height: 12,
        colorFilter: ColorFilter.mode(
          theme.colorScheme.onSurfaceVariant,
          BlendMode.srcIn,
        ),
      ),
    ),
  );

  /// 精品标。SVG 内是粉色底加白字，染色会让字消失，所以不加 colorFilter。
  Widget _featuredTag() => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: SvgPicture.asset(Assets.bubbleFeatured, width: 15, height: 17),
  );

  Widget? _trailing(DynList item, ThemeData theme) {
    final replyCount = item.meta?.replyIcon?.text ?? item.meta?.replyCount;
    final timeText = item.meta?.timeText;
    if (replyCount == null && timeText == null) {
      return null;
    }
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyCount != null)
          _replyCount(
            replyCount,
            _parseColor(item.meta?.replyIcon?.color) ??
                theme.colorScheme.onSurfaceVariant,
            theme,
          ),
        if (timeText != null) ...[
          if (replyCount != null) const SizedBox(width: 8),
          Text(
            timeText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
    // 已读帖子整体弱化，连同评论数气泡一起
    return item.read ? Opacity(opacity: 0.5, child: row) : row;
  }

  /// 评论数。气泡配色接口已按评论数分好档，直接用它给的色值。
  Widget _replyCount(String count, Color color, ThemeData theme) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset(
        Assets.bubbleReply,
        width: 16,
        height: 16,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
      const SizedBox(width: 2),
      Text(count, style: theme.textTheme.labelSmall?.copyWith(color: color)),
    ],
  );

  /// 解析接口给的 '#RRGGBB' 或 'var(--Xxx)'，无法识别时返回 null 由调用方回落语义色
  static Color? _parseColor(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final named = BiliColors.bubbleReplyColorVars[raw];
    if (named != null) {
      return named;
    }
    if (raw.length != 7 || raw[0] != '#') {
      return null;
    }
    final value = int.tryParse(raw.substring(1), radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  Widget _buildBody(
    BuildContext context,
    LoadingState<List<DynList>?> loadingState,
  ) {
    switch (loadingState) {
      case Loading():
        return const SliverFillRemaining(child: m3eLoading);
      case Success(:final response):
        if (response != null && response.isNotEmpty) {
          final theme = Theme.of(context);
          return SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemBuilder: (context, index) {
              if (index == response.length - 1) {
                _controller.onLoadMore();
              }
              final item = response[index];
              return Material(
                type: .transparency,
                child: ListTile(
                  safeArea: false,
                  visualDensity: .standard,
                  // PageUtils.pushDynFromId(id: item.dynId);
                  onTap: () => _openPost(item),
                  title: Row(
                    children: [
                      if (item.isTop) _topTag(theme),
                      Flexible(
                        child: Text(
                          item.title!,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            // 已读帖子标题降低对比度
                            color: item.read
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      if (item.isFeatured) _featuredTag(),
                    ],
                  ),
                  trailing: _trailing(item, theme),
                ),
              );
            },
            itemCount: response.length,
          );
        }
        return HttpError(onReload: _controller.onReload);
      case Error(:final errMsg):
        return HttpError(
          errMsg: errMsg,
          onReload: _controller.onReload,
        );
    }
  }

  @override
  bool get wantKeepAlive => widget.categoryId != null;
}

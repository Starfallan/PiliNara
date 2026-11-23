import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dm_block_type.dart';
import 'package:PiliPlus/models/user/danmaku_block.dart';
import 'package:PiliPlus/models/user/danmaku_rule.dart';
import 'package:PiliPlus/pages/danmaku_block/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class DanmakuBlockPage extends StatefulWidget {
  const DanmakuBlockPage({super.key});

  @override
  State<DanmakuBlockPage> createState() => _DanmakuBlockPageState();
}

class _DanmakuBlockPageState extends State<DanmakuBlockPage> {
  final DanmakuBlockController _controller = Get.put(DanmakuBlockController());
  late PlPlayerController plPlayerController;
  late EdgeInsets padding;

  @override
  void initState() {
    super.initState();
    plPlayerController = Get.arguments as PlPlayerController;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  @override
  void dispose() {
    DanmakuOptions.saveFilterEnabled();
    if (_controller.hasLoadedRules) {
      final ruleFilter = RuleFilter.fromRuleTypeEntries(_controller.rules);
      if (!plPlayerController.filters.hasSameRules(ruleFilter)) {
        plPlayerController.filters = ruleFilter;
        GStorage.localCache.put(LocalCacheKey.danmakuFilterRules, ruleFilter);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterEnabled = DanmakuOptions.danmakuFilterEnabled;
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('弹幕屏蔽'),
        actions: [
          IconButton(
            tooltip: '导入/导出',
            icon: const Icon(Icons.import_export),
            onPressed: () {
              if (!_controller.ensureRulesLoaded()) return;
              showImportExportDialog<List<dynamic>>(
                context,
                title: '弹幕屏蔽规则',
                onExport: () => Utils.jsonEncoder.convert(_controller.exportRules()),
                onImport: _controller.importDanmakuFilter,
                localFileName: () => 'danmaku_block',
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 12),
            child: Tooltip(
              message: '启用个人屏蔽规则',
              excludeFromSemantics: true,
              child: Semantics(
                label: '个人屏蔽规则',
                child: Switch(
                  value: filterEnabled,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  padding: EdgeInsets.zero,
                  onChanged: (value) => setState(() {
                    DanmakuOptions.danmakuFilterEnabled = value;
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _controller.tabController,
            tabs: DmBlockType.values
                .map(
                  (e) => Obx(
                    () => Tab(
                      text: _controller.hasLoadedRules
                          ? '${e.label}(${_controller.rules[e.index].length})'
                          : e.label,
                    ),
                  ),
                )
                .toList(),
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: filterEnabled
                ? const SizedBox(width: double.infinity)
                : Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.pause_circle_outline,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '个人屏蔽已暂停，当前规则暂不生效',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: tabBarView(
              controller: _controller.tabController,
              children: DmBlockType.values
                  .map(
                    (e) => KeepAliveWrapper(
                      child: Obx(() => switch (_controller.syncState.value) {
                        Loading() => m3eLoading,
                        Error(:final errMsg) => scrollErrorWidget(
                          errMsg: errMsg,
                          onReload: _controller.queryDanmakuFilter,
                        ),
                        Success() => tabViewBuilder(e.index, _controller.rules[e.index]),
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      fab: Padding(
        padding: .only(
          right: kFloatingActionButtonMargin + padding.right,
          bottom: kFloatingActionButtonMargin + padding.bottom,
        ),
        child: FloatingActionButton(
          tooltip: '添加',
          onPressed: () => _showAddDialog(
            DmBlockType.values[_controller.tabController.index],
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget tabViewBuilder(int tabIndex, List<SimpleRule> list) {
    if (list.isEmpty) {
      return scrollableError;
    }
    return ListView.builder(
      itemCount: list.length,
      padding: .only(bottom: padding.bottom + 100),
      itemBuilder: (context, itemIndex) {
        final SimpleRule item = list[itemIndex];
        final child = iconButton(
          iconSize: 20,
          tooltip: '删除',
          icon: const Icon(Icons.delete_outlined),
          onPressed: () => showConfirmDialog(
            context: context,
            title: const Text('确定删除该规则？'),
            onConfirm: () => _controller.danmakuFilterDel(
              tabIndex,
              itemIndex,
              item.id,
            ),
          ),
        );
        return ListTile(
          title: Text(
            item.filter,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: tabIndex == 2
              ? child
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconButton(
                      iconSize: 20,
                      tooltip: '编辑',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showAddDialog(
                        DmBlockType.values[_controller.tabController.index],
                        initFilter: item.filter,
                        itemIndex: itemIndex,
                        itemId: item.id,
                      ),
                    ),
                    child,
                  ],
                ),
        );
      },
    );
  }

  void _showAddDialog(
    DmBlockType type, {
    String initFilter = '',
    int? itemIndex,
    int? itemId,
  }) {
    if (!_controller.ensureRulesLoaded()) return;
    assert((itemIndex == null) == (itemId == null));
    String filter = initFilter;
    final hintText = switch (type) {
      DmBlockType.keyword => '输入过滤的关键词，其它类别请切换标签页后添加',
      DmBlockType.regex => '输入//之间的正则表达式，无需包含头尾的"/"',
      DmBlockType.uid => '输入用户UID',
    };
    final isUid = type == DmBlockType.uid;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${itemId != null ? "编辑" : "添加新的"}${type.label}规则'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hintText),
            TextFormField(
              autofocus: true,
              initialValue: filter,
              onChanged: (value) => filter = value,
              keyboardType: isUid ? TextInputType.number : null,
              inputFormatters: isUid
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            child: const Text('确定'),
            onPressed: () async {
              if (filter != initFilter) {
                Get.back();
                if (itemId != null) {
                  await _controller.danmakuFilterDel(
                    type.index,
                    itemIndex!,
                    itemId,
                  );
                }
                await _controller.danmakuFilterAdd(
                  filter: filter,
                  type: type.index,
                );
              } else {
                SmartDialog.showToast(
                  '输入内容${filter.isEmpty ? "不能为空" : "与上次相同"}',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

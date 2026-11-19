import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/reply_settings.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class ReplySetting extends StatefulWidget {
  const ReplySetting({
    super.key,
    this.showAppBar = true,
    this.autoOpenKeywordFilter = false,
  });

  final bool showAppBar;
  final bool autoOpenKeywordFilter;

  @override
  State<ReplySetting> createState() => _ReplySettingState();
}

class _ReplySettingState extends State<ReplySetting> {
  final list = replySettings;
  int _level = Pref.replyMinLevel;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenKeywordFilter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        // 关键词过滤不一定在首位（上游分栏后首项是「显示视频评论」），按标题定位
        for (final item in list) {
          if (item is NormalModel && item.effectiveTitle == '评论关键词过滤') {
            item.onTap?.call(context, () {
              if (mounted) {
                setState(() {});
              }
            });
            break;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final padding = MediaQuery.viewPaddingOf(context);
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: showAppBar ? AppBar(title: const Text('评论设置')) : null,
      body: ListView(
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        children: [
          ...list.map((item) => item.widget),
          _buildLevelSlider(theme),
          ListTile(
            dense: true,
            subtitle: Text(
              '* 屏蔽用户后，该用户发布的评论将不会显示。\n'
              '* 评论区屏蔽用户优先于白名单生效。\n'
              '* 白名单用户与动态流/推荐流共享，白名单优先于带货屏蔽和常规过滤。\n'
              '* 每行一个关键词，每行都是一条独立的正则表达式，忽略大小写，命中任一即过滤。\n'
              '* 评论关键词匹配正文，用户名称关键词匹配评论作者的原始昵称，不匹配本地备注。\n'
              '* 正文和名称关键词过滤均受白名单及已开启的 UP 主相关保留设置豁免。\n'
              '* 等级过滤：屏蔽低于所设等级的用户发布的评论，0 为关闭。\n'
              '* 设置立即生效，刷新评论区即可看到过滤结果。',
              style: theme.textTheme.labelSmall!.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('屏蔽低等级用户评论'),
          subtitle: Text(
            _level == 0 ? '已关闭' : '屏蔽 Lv${_level - 1} 及以下的评论',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('Lv0'),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 6,
                  divisions: 6,
                  value: _level.toDouble(),
                  label: _level == 0 ? '关闭' : 'Lv$_level',
                  onChanged: (v) {
                    final level = v.round();
                    setState(() => _level = level);
                    Pref.replyMinLevel = level;
                    ReplyGrpc.replyMinLevel = level;
                  },
                ),
              ),
              const Text('Lv6'),
            ],
          ),
        ),
      ],
    );
  }
}

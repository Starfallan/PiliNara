import 'package:PiliPlus/pages/ai_chat/controller.dart';
import 'package:PiliPlus/pages/ai_chat/models.dart';
import 'package:PiliPlus/pages/common/slide/common_slide_page.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/services/ai_chat/ai_chat_service.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class AiChatPage extends CommonSlidePage {
  const AiChatPage({super.key, required this.heroTag});

  final String heroTag;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage>
    with SingleTickerProviderStateMixin, CommonSlideMixin {
  late final AiChatController chatCtl;
  final _inputCtl = TextEditingController();
  final _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
  final _scrollCtl = ScrollController();
  late List<AiPromptTemplate> _templates;
  int _selectedPromptIndex = 0;
  bool _isAtBottom = true;
  double _lastScrollOffset = 0;

  /// Hard keyboard: Enter sends, Shift+Enter inserts newline
  static KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final state = node.context?.findAncestorStateOfType<_AiChatPageState>();
      if (state != null && !state.chatCtl.isAnalyzing.value) {
        state._sendCustomPrompt();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    chatCtl = Get.find<AiChatController>(tag: widget.heroTag);
    _templates = AiChatService.getTemplates();
    _scrollCtl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputCtl.dispose();
    _focusNode.dispose();
    _scrollCtl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtl.hasClients) return;
    final pos = _scrollCtl.position;
    final offset = pos.pixels;
    if (offset < _lastScrollOffset) {
      if (_isAtBottom) setState(() => _isAtBottom = false);
    } else if (offset > _lastScrollOffset) {
      if (!_isAtBottom && pos.maxScrollExtent - offset <= 100) {
        setState(() => _isAtBottom = true);
      }
    }
    _lastScrollOffset = offset;
  }

  void _scrollToBottom() {
    if (!_isAtBottom || !_scrollCtl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients && _isAtBottom) {
        _scrollCtl.animateTo(
          _scrollCtl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendSelectedPrompt() {
    if (_templates.isEmpty) return;
    if (_selectedPromptIndex >= 0 && _selectedPromptIndex < _templates.length) {
      final t = _templates[_selectedPromptIndex];
      chatCtl.startAnalysis(t.prompt, templateName: t.name);
    }
  }

  void _sendCustomPrompt() {
    final text = _inputCtl.text.trim();
    if (text.isEmpty) return;
    _inputCtl.clear();
    chatCtl.sendFollowUp(text);
  }

  void _copyToClipboard() {
    final msgs = chatCtl.messages;
    if (msgs.isEmpty) return;
    ChatMessage? lastAssistant;
    for (final m in msgs.reversed) {
      if (m.role == 'assistant' && m.content.isNotEmpty) {
        lastAssistant = m;
        break;
      }
    }
    if (lastAssistant == null) return;
    Clipboard.setData(ClipboardData(text: lastAssistant.content));
    SmartDialog.showToast('已复制到剪贴板');
  }

  @override
  Widget buildPage(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Drag handle
          GestureDetector(
            onTap: Get.back,
            child: SizedBox(
              height: 35,
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ),

          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'AI 视频助手',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Obx(() {
                  if (chatCtl.messages.isNotEmpty) {
                    return TextButton.icon(
                      onPressed: chatCtl.clearMessages,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重置'),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Prompt selector + analyze button
          _buildPromptBar(theme),
          Divider(height: 1, color: colorScheme.outlineVariant),

          // Warning banner
          Obx(() {
            if (!chatCtl.subtitleWarning.value) {
              return const SizedBox.shrink();
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: colorScheme.errorContainer,
              child: Text(
                '字幕文本较长，分析结果可能不够完整',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            );
          }),

          // Content area (slideable)
          Expanded(
            child: enableSlide ? slideList(theme) : buildList(theme),
          ),

          // Input bar
          _buildInputBar(theme),
        ],
      ),
    );
  }

  @override
  Widget buildList(ThemeData theme) {
    return _buildContent(theme);
  }

  Widget _buildPromptBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _templates.isEmpty
                ? Text(
                    '暂无模板，请在设置中添加',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.outline,
                    ),
                  )
                : DropdownButtonFormField<int>(
                    initialValue: _selectedPromptIndex < _templates.length
                        ? _selectedPromptIndex
                        : 0,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    items: _templates.asMap().entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPromptIndex = value);
                      }
                    },
                  ),
          ),
          const SizedBox(width: 12),
          Obx(() {
            final analyzing = chatCtl.isAnalyzing.value;
            final noSubtitle = !chatCtl.hasSubtitles;
            return FilledButton.icon(
              onPressed: (analyzing || noSubtitle) ? null : _sendSelectedPrompt,
              icon: analyzing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 20),
              label: const Text('分析'),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Obx(() {
      final msgs = chatCtl.messages;

      // Empty state
      if (msgs.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  chatCtl.hasSubtitles
                      ? '选择提示词后点击「分析」开始'
                      : '输入问题开始对话',
                  style: TextStyle(color: colorScheme.outline),
                ),
              ],
            ),
          ),
        );
      }

      _scrollToBottom();

      return ListView.builder(
        controller: _scrollCtl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: msgs.length,
        itemBuilder: (context, index) {
          final msg = msgs[index];
          if (msg.role == 'user') {
            final displayText = msg.templateName != null
                ? '/${msg.templateName}'
                : msg.content;
            return _buildUserMessage(displayText, theme);
          }
          return _buildAssistantMessage(msg, theme);
        },
      );
    });
  }

  Widget _buildUserMessage(String content, ThemeData theme) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantMessage(ChatMessage msg, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: msg.content.isEmpty && msg.isStreaming
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI 正在思考...',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  )
                : SelectionArea(
                    child: MarkdownBody(
                      data: _preprocessTimestamps(msg.content),
                      blockSyntaxes: [LatexBlockSyntax()],
                      inlineSyntaxes: [LatexInlineSyntax()],
                      builders: {
                        'latex': LatexElementBuilder(),
                      },
                      onTapLink: (text, href, title) {
                        if (href != null &&
                            href.startsWith('timestamp://')) {
                          _seekToTimestamp(href);
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        a: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.none,
                        ),
                        p: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        h1: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          height: 1.5,
                        ),
                        h2: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          height: 1.5,
                        ),
                        h3: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          height: 1.4,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        blockquotePadding: const EdgeInsets.only(left: 12),
                        code: TextStyle(
                          fontSize: 13,
                          color: colorScheme.primary,
                          backgroundColor: colorScheme.surfaceContainerHigh,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        codeblockPadding: const EdgeInsets.all(12),
                        listBullet: TextStyle(
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
          ),
          // Copy button at bottom-right of bubble, after streaming ends
          if (!msg.isStreaming && msg.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Material(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                elevation: 2,
                child: InkWell(
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static final _timestampReg =
      RegExp(r'\[(\d{1,2}:\d{2}(?::\d{2})?)(?:-\d{1,2}:\d{2}(?::\d{2})?)?\]');

  String _preprocessTimestamps(String text) {
    return text.replaceAllMapped(_timestampReg, (match) {
      final ts = match.group(1)!;
      final seconds = DurationUtils.parseDuration(ts);
      return '[$ts](timestamp://$seconds)';
    });
  }

  void _seekToTimestamp(String href) {
    final seconds = int.tryParse(href.replaceFirst('timestamp://', ''));
    if (seconds == null) return;
    try {
      final videoCtl = Get.find<VideoDetailController>(tag: widget.heroTag);
      final duration = videoCtl.plPlayerController.duration.value;
      if (duration.inSeconds > 0 && seconds > duration.inSeconds) return;
      videoCtl.plPlayerController.seekTo(
        Duration(seconds: seconds),
        isSeek: false,
      );
    } catch (_) {}
  }

  Widget _buildInputBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        8,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtl,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '输入问题继续对话...',
                hintStyle: TextStyle(color: colorScheme.outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(() => IconButton.filled(
                onPressed: chatCtl.isAnalyzing.value ? null : _sendCustomPrompt,
                icon: const Icon(Icons.send),
              )),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/ai_chat/models.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/services/ai_chat/ai_chat_service.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class AiChatController extends GetxController {
  final messages = <ChatMessage>[].obs;
  final isRequesting = false.obs;
  final subtitleWarning = false.obs;
  final hasVideoContext = false.obs;

  final String heroTag;
  late final VideoDetailController _videoCtl;

  AiChatController({required this.heroTag});

  // --- Dynamic system prompts ---
  static const _systemPromptA =
      '你是一个智能问答助手。当前对话尚未关联任何视频内容。请使用你的通用知识库回答用户的问题。'
      '如果用户的提问明确指向某个特定视频的内容（如"视频里说了什么"），'
      '请委婉地提示用户：『抱歉，您还没有载入视频信息，请先点击【载入上下文】按钮补充上下文。』';

  static const _systemPromptB =
      '你是一个视频内容分析与互动学习助手。当前对话已成功关联视频上下文。请严格基于注入的视频内容解答用户的疑问。\n'
      '要求：\n'
      '1. 回复语言为中文，使用 Markdown 格式。\n'
      '2. 只要输出内容涉及到具体的视频时间点，必须统一使用 [mm:ss] 或 [hh:mm:ss] 格式。'
      '时间戳前后必须保留一个空格。时间段请使用 [开始] - [结束] 格式。'
      '严禁用代码块或反引号包裹时间戳（如 `[03:12]` 是错误的）。\n'
      '3. 如果用户询问的概念超出了视频本身的信息范围，请勿提示无法分析，'
      '而是主动调用通用知识补充解答，并在该段落前明确声明：'
      '『*视频中未提及此概念，为您补充相关背景知识：*』\n'
      '4. 【无字幕兜底策略】：如果你发现系统注入的"字幕"数据缺失（标记为"【警告：当前视频未提供字幕数据】"），'
      '请仅基于"标题"和"简介"进行分析，并在回复开头醒目地提示用户：'
      '『⚠️ 当前视频未提取到字幕，以下分析仅基于视频标题与简介：』。'
      '切勿捏造或猜测视频内部的画面与台词。';

  // --- Cached video context for system message injection ---
  String? _cachedVideoContext;
  int _contextLoadIndex = -1;
  CancelToken? _requestToken;
  ChatMessage? _responseMessage;

  // --- 思考耗时计时器（约 100ms 刷新，正文首字或流结束时冻结）---
  Timer? _reasoningTimer;
  ChatMessage? _reasoningTimerMsg;

  @override
  void onInit() {
    super.onInit();
    _videoCtl = Get.find<VideoDetailController>(tag: heroTag);
  }

  @override
  void onClose() {
    cancelRequest();
    _stopReasoningTimer();
    super.onClose();
  }

  bool get hasSubtitles => _videoCtl.subtitles.isNotEmpty;

  String _buildVideoInfo() {
    String info = '';
    try {
      final videoDetail =
          Get.find<UgcIntroController>(tag: heroTag).videoDetail.value;
      final title = videoDetail.title;
      final desc = videoDetail.desc;
      if (title != null && title.isNotEmpty) {
        info = '视频标题：$title\n';
      }
      if (desc != null && desc.isNotEmpty) {
        info += '视频简介：$desc\n';
      }
      if (info.isNotEmpty) info += '\n';
    } catch (_) {}
    return info;
  }

  /// 只载入上下文，不请求 AI；字幕下载与分析请求共用取消入口。
  Future<void> loadVideoContext() async {
    if (hasVideoContext.value) return;
    await _runRequest(loadContext: true, errorPrefix: '载入失败');
  }

  Future<void> _loadVideoContext(CancelToken token) async {
    final videoInfo = _buildVideoInfo();
    final hasSubs = hasSubtitles;
    String? subtitleText;

    if (hasSubs) {
      final subtitle = _videoCtl.subtitles.first;
      final body = await VideoHttp.fetchSubtitleBody(
        subtitle.subtitleUrl!,
        cancelToken: token,
      );
      if (!_isCurrentRequest(token)) return;
      if (body == null || body.isEmpty) {
        SmartDialog.showToast('获取字幕数据失败');
        return;
      }
      final processed = VideoHttp.preprocessSubtitlesForAi(body);
      subtitleText = processed.text;
      subtitleWarning.value = processed.isTooLong;
    }

    if (!_isCurrentRequest(token)) return;
    _cachedVideoContext = _assembleVideoContext(videoInfo, subtitleText);
    hasVideoContext.value = true;

    _contextLoadIndex = messages.length;
    messages.add(ChatMessage(role: 'system', content: '', isDivider: true));
    if (!hasSubs) {
      messages.add(ChatMessage(
        role: 'assistant',
        content: '⚠️ 已载入视频标题与简介。由于未获取到字幕，AI 分析深度可能受限，请提问。',
      ));
    }
  }

  /// Assemble the video context string for system message injection.
  String _assembleVideoContext(String videoInfo, String? subtitleText) {
    final sb = StringBuffer();
    if (videoInfo.isNotEmpty) sb.write(videoInfo);
    if (subtitleText != null && subtitleText.isNotEmpty) {
      sb
        ..writeln('## 字幕内容')
        ..writeln(subtitleText);
    } else {
      sb.writeln('## 字幕内容\n【警告：当前视频未提供字幕数据】');
    }
    return sb.toString();
  }

  /// Start analysis with a template prompt.
  Future<void> startAnalysis(String templatePrompt, {String? templateName}) =>
      _runRequest(
        prompt: templatePrompt,
        templateName: templateName,
        loadContext: true,
        errorPrefix: '分析失败',
      );

  /// Send a follow-up message.
  Future<void> sendFollowUp(String text) async {
    if (text.trim().isEmpty) return;
    await _runRequest(prompt: text.trim(), errorPrefix: '请求失败');
  }

  bool _isCurrentRequest(CancelToken token) =>
      identical(_requestToken, token) && !token.isCancelled && !isClosed;

  Future<void> _runRequest({
    String? prompt,
    String? templateName,
    bool loadContext = false,
    required String errorPrefix,
  }) async {
    if (_requestToken != null || isClosed) return;
    final token = CancelToken();
    _requestToken = token;
    isRequesting.value = true;
    var removeEmpty = false;

    try {
      if (loadContext && !hasVideoContext.value) {
        await _loadVideoContext(token);
        if (!_isCurrentRequest(token) || !hasVideoContext.value) return;
      }
      if (prompt == null || !_isCurrentRequest(token)) return;

      final response = ChatMessage(role: 'assistant', content: '', isStreaming: true);
      _responseMessage = response;
      messages.addAll([
        ChatMessage(
          role: 'user',
          content: prompt,
          templateName: templateName,
        ),
        response,
      ]);

      await _streamResponse(token, response);
    } catch (e) {
      if (_isCurrentRequest(token)) {
        removeEmpty = true;
        if (e is! DioException || !CancelToken.isCancel(e)) {
          SmartDialog.showToast('$errorPrefix: $e');
        }
      }
    } finally {
      _finishRequest(token, removeEmpty: removeEmpty);
    }
  }

  void cancelRequest() {
    final token = _requestToken;
    if (token == null) return;
    token.cancel('用户停止请求');
    _finishRequest(token, removeEmpty: true);
  }

  void _finishRequest(CancelToken token, {bool removeEmpty = false}) {
    // 停止后可以立即重发，旧请求的 finally 不能结束新请求。
    if (!identical(_requestToken, token)) return;
    final response = _responseMessage;
    _requestToken = null;
    _responseMessage = null;
    if (response != null) {
      response.isStreaming = false;
      _freezeReasoningDuration(response);
      if (removeEmpty && response.content.isEmpty && !response.hasReasoning) {
        messages.remove(response);
      } else {
        messages.refresh();
      }
    }
    isRequesting.value = false;
  }

  Future<void> _streamResponse(CancelToken token, ChatMessage response) async {
    subtitleWarning.value = false;

    final chatMessages = <Map<String, String>>[
      {
        'role': 'system',
        'content': hasVideoContext.value
            ? _systemPromptB
            : _systemPromptA,
      },
    ];

    // Inject cached video context as system message (for prefix caching)
    if (hasVideoContext.value && _cachedVideoContext != null) {
      chatMessages.add({
        'role': 'system',
        'content': _cachedVideoContext!,
      });
    }

    // Add conversation history, truncating at context load boundary.
    // 思考内容只保留在本地供 UI 展示，出站历史只用 role + 正文；
    // 正文为空的助手消息整条跳过（失败留下的思考卡片、流结束无正文的
    // 卡片、正在流式且尚无正文的占位都不发送空 content）
    final startIdx = _contextLoadIndex >= 0 ? _contextLoadIndex : 0;
    for (final m in messages.skip(startIdx)) {
      if (m.isDivider) continue;
      if (m.role == 'assistant' && m.content.isEmpty) continue;
      chatMessages.add({'role': m.role, 'content': m.content});
    }

    await for (final delta in AiChatService.streamChat(
      messages: chatMessages,
      reasoningEffort: Pref.aiReasoningEffort,
      cancelToken: token,
    )) {
      if (!_isCurrentRequest(token)) return;
      if (delta.reasoningDelta.isNotEmpty) {
        _appendReasoningDelta(response, delta.reasoningDelta);
      }
      if (delta.contentDelta.isNotEmpty) {
        _appendContentDelta(response, delta.contentDelta);
      }
    }
  }

  /// 追加思考增量。首次非空增量记录起始时刻，正文仍空时默认展开为限高卡片
  void _appendReasoningDelta(ChatMessage msg, String delta) {
    if (msg.reasoningStartedAt == null) {
      msg.reasoningStartedAt = DateTime.now();
      if (msg.content.isEmpty) {
        msg
          ..isReasoningExpanded = true
          ..isReasoningFullHeight = false;
      }
      _startReasoningTimer(msg);
    }
    msg.appendReasoningContent(delta);
    messages.refresh();
  }

  /// 追加正文增量。第一个正文字符到达时强制收成胶囊并冻结思考耗时
  void _appendContentDelta(ChatMessage msg, String delta) {
    if (msg.content.isEmpty) {
      _freezeReasoningDuration(msg);
      msg.isReasoningExpanded = false;
    }
    msg.appendContent(delta);
    messages.refresh();
  }

  /// 进行中的秒数由 [ChatMessage.reasoningSeconds] 实时计算，
  /// 这里只负责约每 100ms 触发一次刷新
  void _startReasoningTimer(ChatMessage msg) {
    _stopReasoningTimer();
    _reasoningTimerMsg = msg;
    _reasoningTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final target = _reasoningTimerMsg;
      if (target == null || target.reasoningDurationSeconds != null) {
        _stopReasoningTimer();
        return;
      }
      messages.refresh();
    });
  }

  void _stopReasoningTimer() {
    _reasoningTimer?.cancel();
    _reasoningTimer = null;
    _reasoningTimerMsg = null;
  }

  /// 按当前时刻冻结思考耗时：第一个正文字符到达或流结束时调用
  void _freezeReasoningDuration(ChatMessage msg) {
    if (msg.reasoningStartedAt != null) {
      msg.reasoningDurationSeconds = msg.reasoningSeconds;
    }
    if (identical(_reasoningTimerMsg, msg)) _stopReasoningTimer();
  }

  void clearMessages() {
    cancelRequest();
    _stopReasoningTimer();
    messages.clear();
    subtitleWarning.value = false;
    hasVideoContext.value = false;
    _cachedVideoContext = null;
    _contextLoadIndex = -1;
  }
}

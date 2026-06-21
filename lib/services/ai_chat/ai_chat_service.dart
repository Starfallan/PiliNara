import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class AiPromptTemplate {
  String name;
  String prompt;

  AiPromptTemplate({required this.name, required this.prompt});

  Map<String, dynamic> toJson() => {'name': name, 'prompt': prompt};

  factory AiPromptTemplate.fromJson(Map<String, dynamic> json) =>
      AiPromptTemplate(name: json['name'] ?? '', prompt: json['prompt'] ?? '');
}

class AiChatService {
  static Options _options({Duration? receiveTimeout}) {
    final apiKey = Pref.aiApiKey;
    return Options(
      headers: {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 60),
    );
  }

  static String _baseUrl() {
    var url = Pref.aiApiUrl.trimRight();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/v1')) url = url.substring(0, url.length - 3);
    return url;
  }

  /// Fetch model list from /v1/models
  static Future<List<String>> fetchModels() async {
    final baseUrl = _baseUrl();
    if (baseUrl.isEmpty) throw Exception('请先配置 API 地址');
    final res = await Dio().get(
      '$baseUrl/v1/models',
      options: _options(receiveTimeout: const Duration(seconds: 30)),
    );
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => e['id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Stream chat completion from /v1/chat/completions
  /// Returns a stream of content strings (each token/chunk)
  static Stream<String> streamChat({
    required List<Map<String, String>> messages,
    String? model,
  }) async* {
    final baseUrl = _baseUrl();
    if (baseUrl.isEmpty) throw Exception('请先配置 API 地址');
    final useModel = model ?? Pref.aiModel;
    if (useModel.isEmpty) throw Exception('请先选择模型');

    final opts = _options(receiveTimeout: const Duration(minutes: 10))
      ..responseType = ResponseType.stream;
    final response = await Dio().post<ResponseBody>(
      '$baseUrl/v1/chat/completions',
      data: jsonEncode({
        'model': useModel,
        'messages': messages,
        'stream': true,
      }),
      options: opts,
    );

    final stream = response.data!.stream;

    await for (final line in stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
      final data = trimmed.replaceFirst('data:', '').trim();
      if (data == '[DONE]') return;
      if (data.isEmpty) continue;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null) {
            yield content;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('SSE parse error: $e');
      }
    }
  }

  // --- Template CRUD ---

  static final List<AiPromptTemplate> defaultTemplates = [
    AiPromptTemplate(
      name: '概貌总结',
      prompt: '请对这个视频内容进行概貌总结。考虑到视频可能较长，请避免过度省略。\n'
          '要求：\n'
          '1. 【核心主旨】用 1-2 句话精准概括视频的核心价值与主题。\n'
          '2. 【高光时刻】列出 3-5 个最具争议、最有趣或最重要的核心观点。\n'
          '3. 【时间线速览】按时间顺序，提供一个简明的目录式大纲，每个条目必须以时间戳 `[mm:ss]` 开头。\n'
          '4. 结构必须极其清晰，便于用户在 10 秒内判断是否值得观看全片。',
    ),
    AiPromptTemplate(
      name: '详细分析',
      prompt: '请对这个视频进行极具深度的拆解分析。请克服长文本的省略倾向，尽可能保留具体细节、案例和逻辑推演。\n'
          '要求：\n'
          '1. 【结构脉络】根据视频的话题转换，将其划分为几个清晰的章节，每个章节必须标明时间跨度（如 `[01:00] - [15:30]`）。\n'
          '2. 【深度提取】在每个章节下，详细阐述其核心观点、使用的论据（如有案例请务必写出）。\n'
          '3. 【内在逻辑】分析各章节之间的关联，说明主讲人是如何一步步推导结论的。\n'
          '4. 【精粹总结】在末尾给出该视频的最终结论或可执行的启示。\n'
          '注意：全程必须高频使用 `[mm:ss]` 时间戳进行锚定，以便我随时点击溯源。',
    ),
  ];

  static List<AiPromptTemplate> getTemplates() {
    final raw = Pref.aiPromptTemplates;
    if (raw.isEmpty) return defaultTemplates;
    try {
      final list = jsonDecode(raw) as List;
      var templates = list
          .map((e) => AiPromptTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      var changed = false;
      // Remove deprecated templates
      final beforeRemove = templates.length;
      templates.removeWhere((t) => t.name == '准备问答');
      if (templates.length != beforeRemove) changed = true;
      // Sync default templates: add missing, update changed content
      final defaultMap = {for (final t in defaultTemplates) t.name: t};
      for (var i = 0; i < templates.length; i++) {
        final defaultT = defaultMap[templates[i].name];
        if (defaultT != null && templates[i].prompt != defaultT.prompt) {
          templates[i] = defaultT;
          changed = true;
        }
      }
      final existingNames = templates.map((e) => e.name).toSet();
      for (final t in defaultTemplates) {
        if (!existingNames.contains(t.name)) {
          templates.add(t);
          changed = true;
        }
      }
      if (changed) saveTemplates(templates);
      return templates;
    } catch (_) {
      return defaultTemplates;
    }
  }

  static void saveTemplates(List<AiPromptTemplate> templates) {
    Pref.aiPromptTemplates = jsonEncode(templates.map((e) => e.toJson()).toList());
  }
}

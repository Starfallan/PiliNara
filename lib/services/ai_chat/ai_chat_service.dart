import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';

class AiPromptTemplate {
  String name;
  String prompt;

  AiPromptTemplate({required this.name, required this.prompt});

  Map<String, dynamic> toJson() => {'name': name, 'prompt': prompt};

  factory AiPromptTemplate.fromJson(Map<String, dynamic> json) =>
      AiPromptTemplate(name: json['name'] ?? '', prompt: json['prompt'] ?? '');
}

class AiChatService {
  static void resetClient() {}

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
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk));
      final lines = buffer.toString().split('\n');
      // Keep the last incomplete line in the buffer
      buffer
        ..clear()
        ..write(lines.removeLast());
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') return;
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
        } catch (_) {
          // skip malformed chunks
        }
      }
    }
  }

  // --- Template CRUD ---

  static final List<AiPromptTemplate> defaultTemplates = [
    AiPromptTemplate(
      name: '概貌总结',
      prompt: '请对这个视频内容进行概貌总结，要求：\n'
          '1. 用1-2句话概括视频主题\n'
          '2. 列出3-5个核心要点，每条用时间戳标注对应位置\n'
          '3. 结构简洁，便于快速浏览',
    ),
    AiPromptTemplate(
      name: '详细分析',
      prompt: '请对这个视频内容进行详细分析，要求：\n'
          '1. 梳理视频的结构脉络和章节划分\n'
          '2. 提取关键观点及支撑论据\n'
          '3. 分析各部分内容之间的逻辑关系\n'
          '4. 总结结论或启示\n'
          '5. 在各部分标注对应时间戳',
    ),
  ];

  static List<AiPromptTemplate> getTemplates() {
    final raw = Pref.aiPromptTemplates;
    if (raw.isEmpty) return defaultTemplates;
    try {
      final list = jsonDecode(raw) as List;
      final templates = list
          .map((e) => AiPromptTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      // Merge in missing default templates
      final existingNames = templates.map((e) => e.name).toSet();
      final missing = defaultTemplates
          .where((t) => !existingNames.contains(t.name))
          .toList();
      if (missing.isNotEmpty) {
        templates.insertAll(0, missing);
        saveTemplates(templates);
      }
      return templates;
    } catch (_) {
      return defaultTemplates;
    }
  }

  static void saveTemplates(List<AiPromptTemplate> templates) {
    Pref.aiPromptTemplates = jsonEncode(templates.map((e) => e.toJson()).toList());
  }
}

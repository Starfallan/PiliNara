// Adapted from pakku.js (https://github.com/xmcp/pakku.js)
// Uses a copied dictionary derived from
// pakkujs/similarity/repo-cpp/src/pinyin_dict.txt.

import 'dart:collection';

import 'package:flutter/services.dart' show rootBundle;

class DanmakuPinyinEncoder {
  DanmakuPinyinEncoder._();

  static final DanmakuPinyinEncoder instance = DanmakuPinyinEncoder._();

  static const String _assetPath = 'assets/danmaku_merge/pinyin_dict.txt';
  static const int _tokenBase = 0xE000;

  final Map<String, List<int>> _cache = <String, List<int>>{};
  final Map<int, List<int>> _dict = HashMap<int, List<int>>();
  Future<void>? _loading;

  Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<List<int>> encode(String text) async {
    await ensureLoaded();
    return _cache.putIfAbsent(text, () {
      // Adapted from pakku's pinyin token strategy: map Hanzi to lightweight
      // private-use tokens and lowercase ASCII for mixed-language matching.
      final tokens = <int>[];
      for (final rune in text.runes) {
        final mapped = _dict[rune];
        if (mapped != null) {
          tokens.addAll(mapped);
        } else {
          if (rune >= 0x41 && rune <= 0x5A) {
            tokens.add(rune + 32);
          } else {
            tokens.add(rune);
          }
        }
      }
      return List<int>.unmodifiable(tokens);
    });
  }

  Future<void> _load() async {
    final content = await rootBundle.loadString(_assetPath);
    final lineRe = RegExp(r'^\{0x([0-9a-fA-F]+), \{(\d+), (\d+)\}\},?$');
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final match = lineRe.firstMatch(line);
      if (match == null) {
        continue;
      }
      final codePoint = int.parse(match.group(1)!, radix: 16);
      final primary = int.parse(match.group(2)!);
      final secondary = int.parse(match.group(3)!);
      final tokens = <int>[_tokenBase + primary];
      if (secondary != 0) {
        tokens.add(_tokenBase + secondary);
      }
      _dict[codePoint] = List<int>.unmodifiable(tokens);
    }
  }
}

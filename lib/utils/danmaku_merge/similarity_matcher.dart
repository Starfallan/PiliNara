// Inspired by pakku.js (https://github.com/xmcp/pakku.js)
// Reference: pakkujs/similarity/repo-cpp/src/main.cpp

import 'dart:collection';
import 'dart:math' show max;

import 'package:PiliPlus/utils/danmaku_merge/models.dart';
import 'package:PiliPlus/utils/danmaku_merge/pinyin_encoder.dart';

class DanmakuSimilarityMatcher {
  static const int _hashMod = 1007;

  DanmakuSimilarityMatcher({
    required this.config,
    required this.pinyinEncoder,
  });

  final DanmakuMergeConfig config;
  final DanmakuPinyinEncoder pinyinEncoder;
  final Map<String, List<int>> _pinyinCache = <String, List<int>>{};

  Future<DanmakuSimilarityMatchResult?> match(
    DanmakuMergeCandidate source,
    DanmakuMergeCandidate target,
  ) async {
    if (!config.crossMode && source.mode != target.mode) {
      return null;
    }

    if (source.normalizedText == target.normalizedText) {
      return const DanmakuSimilarityMatchResult(
        reason: DanmakuMergeReason.exact,
        distance: 0,
      );
    }

    final charDistance = _matchDistance(source.charTokens, target.charTokens);
    if (charDistance != null) {
      return DanmakuSimilarityMatchResult(
        reason: DanmakuMergeReason.charDistance,
        distance: charDistance,
      );
    }

    final sourcePinyin = await _getPinyinTokens(source.normalizedText);
    final targetPinyin = await _getPinyinTokens(target.normalizedText);
    final pinyinDistance = _matchDistance(sourcePinyin, targetPinyin);
    if (pinyinDistance != null) {
      return DanmakuSimilarityMatchResult(
        reason: DanmakuMergeReason.pinyinDistance,
        distance: pinyinDistance,
      );
    }

    final cosineSimilarity = _cosineSimilarity(
      source.gramTokens,
      target.gramTokens,
    );
    if (_canUseCosine(source, target, charDistance, cosineSimilarity)) {
      return DanmakuSimilarityMatchResult(
        reason: DanmakuMergeReason.cosineDistance,
        distance: cosineSimilarity,
      );
    }

    return null;
  }

  static List<int> buildGramTokens(String text) {
    if (text.isEmpty) {
      return const <int>[];
    }

    final runes = text.runes.toList(growable: false);
    final grams = <int>[];
    var previous = runes.last % _hashMod;
    for (final rune in runes) {
      final current = rune % _hashMod;
      grams.add(previous * _hashMod + current);
      previous = current;
    }
    return List<int>.unmodifiable(grams);
  }

  int charDistance(List<int> source, List<int> target) {
    return _bagDistance(source, target);
  }

  Future<int> pinyinDistance(String source, String target) async {
    final sourcePinyin = await _getPinyinTokens(source);
    final targetPinyin = await _getPinyinTokens(target);
    return _bagDistance(sourcePinyin, targetPinyin);
  }

  int cosineSimilarity(List<int> source, List<int> target) {
    return _cosineSimilarity(source, target);
  }

  Future<List<int>> _getPinyinTokens(String text) async {
    final cached = _pinyinCache[text];
    if (cached != null) {
      return cached;
    }
    final tokens = await pinyinEncoder.encode(text);
    _pinyinCache[text] = tokens;
    return tokens;
  }

  int? _matchDistance(List<int> source, List<int> target) {
    if ((source.length - target.length).abs() > config.maxDistance) {
      return null;
    }

    // Adapted from pakku's O(n) bag-distance approximation instead of using a
    // textbook edit distance, to keep matching fast in danmaku-heavy segments.
    final distance = _bagDistance(source, target);
    final lenSum = source.length + target.length;
    final minDanmakuSize = max(1, config.maxDistance * 2);
    final matched = lenSum < minDanmakuSize
        ? distance < config.maxDistance * lenSum / minDanmakuSize
        : distance <= config.maxDistance;
    return matched ? distance : null;
  }

  bool _canUseCosine(
    DanmakuMergeCandidate source,
    DanmakuMergeCandidate target,
    int? matchedCharDistance,
    int cosineSimilarity,
  ) {
    if (config.maxCosine > 100) {
      return false;
    }

    final charLengthDiff = (source.charTokens.length - target.charTokens.length)
        .abs();
    final charDistance =
        matchedCharDistance ??
        (charLengthDiff <= config.maxDistance
            ? _bagDistance(source.charTokens, target.charTokens)
            : null);
    final lenSum = source.charTokens.length + target.charTokens.length;
    final noCommonChar = charDistance != null && charDistance >= lenSum;
    if (noCommonChar) {
      return false;
    }
    return cosineSimilarity >= config.maxCosine;
  }

  int _bagDistance(List<int> source, List<int> target) {
    final diff = HashMap<int, int>();
    for (final token in source) {
      diff[token] = (diff[token] ?? 0) + 1;
    }
    for (final token in target) {
      diff[token] = (diff[token] ?? 0) - 1;
    }

    var distance = 0;
    for (final value in diff.values) {
      distance += value.abs();
    }
    return distance;
  }

  int _cosineSimilarity(List<int> source, List<int> target) {
    if (source.isEmpty || target.isEmpty) {
      return 0;
    }

    final sourceCounts = HashMap<int, int>();
    final targetCounts = HashMap<int, int>();
    for (final token in source) {
      sourceCounts[token] = (sourceCounts[token] ?? 0) + 1;
    }
    for (final token in target) {
      targetCounts[token] = (targetCounts[token] ?? 0) + 1;
    }

    var x = 0;
    var y = 0;
    for (final entry in sourceCounts.entries) {
      final sourceValue = entry.value;
      final targetValue = targetCounts[entry.key] ?? 0;
      x += sourceValue * targetValue;
      y += sourceValue * sourceValue;
    }

    var z = 0;
    for (final targetValue in targetCounts.values) {
      z += targetValue * targetValue;
    }

    if (x == 0 || y == 0 || z == 0) {
      return 0;
    }

    final score = (100 * x * x) / (y * z);
    return score.floor();
  }
}

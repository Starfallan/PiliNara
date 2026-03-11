// Inspired by pakku.js (https://github.com/xmcp/pakku.js)
// References:
// - pakkujs/core/combine_worker.ts
// - pakkujs/core/scheduler.ts

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/utils/danmaku_merge/models.dart';
import 'package:PiliPlus/utils/danmaku_merge/normalizer.dart';
import 'package:PiliPlus/utils/danmaku_merge/pinyin_encoder.dart';
import 'package:PiliPlus/utils/danmaku_merge/similarity_matcher.dart';

class DanmakuClusterer {
  DanmakuClusterer({
    required this.config,
    required DanmakuPinyinEncoder pinyinEncoder,
  }) : _matcher = DanmakuSimilarityMatcher(
         config: config,
         pinyinEncoder: pinyinEncoder,
       );

  final DanmakuMergeConfig config;
  final DanmakuSimilarityMatcher _matcher;

  Future<List<DanmakuElem>> mergeSegment({
    required int segmentIndex,
    required List<DanmakuElem> currentSegment,
    required List<DanmakuElem> nextSegmentPrefix,
  }) async {
    if (!config.enabled || currentSegment.isEmpty) {
      return currentSegment;
    }

    final current = List<DanmakuElem>.from(currentSegment)
      ..sort((a, b) => a.progress.compareTo(b.progress));
    final next = List<DanmakuElem>.from(nextSegmentPrefix)
      ..sort((a, b) => a.progress.compareTo(b.progress));

    final output = <DanmakuElem>[];
    final activeClusters = <DanmakuMergeCluster>[];

    // Inspired by pakku's active-cluster queue: clusters are emitted once they
    // are outside the configured merge window.
    Future<void> flushExpired(int currentProgress) async {
      while (activeClusters.isNotEmpty &&
          currentProgress - activeClusters.first.progress > config.windowMs) {
        output.add(_buildRepresentative(activeClusters.removeAt(0)));
      }
    }

    for (final element in current) {
      await flushExpired(element.progress);
      if (!_isMergeable(element)) {
        output.add(element);
        continue;
      }

      final candidate = _toCandidate(element, segmentIndex);
      var matched = false;
      for (final cluster in activeClusters) {
        final result = await _matcher.match(candidate, cluster.root);
        if (result != null) {
          cluster.add(candidate);
          matched = true;
          break;
        }
      }

      if (!matched) {
        activeClusters.add(DanmakuMergeCluster(candidate));
      }
    }

    // Adapted from pakku's next-chunk prefix matching to reduce segment-edge
    // misses without requiring a full multi-segment scheduler.
    for (final element in next) {
      await flushExpired(element.progress);
      if (!_isMergeable(element)) {
        continue;
      }
      final candidate = _toCandidate(element, segmentIndex + 1);
      for (final cluster in activeClusters) {
        final result = await _matcher.match(candidate, cluster.root);
        if (result != null) {
          cluster.add(candidate);
          break;
        }
      }
    }

    output
      ..addAll(activeClusters.map(_buildRepresentative))
      ..sort((a, b) => a.progress.compareTo(b.progress));
    return output;
  }

  bool _isMergeable(DanmakuElem element) {
    if (element.isSelf) {
      return false;
    }
    if (element.mode == 8 || element.mode == 9) {
      return false;
    }
    if (config.skipSubtitle && element.pool == 1) {
      return false;
    }
    if (config.skipAdvanced && element.mode == 7) {
      return false;
    }
    if (config.skipBottom && element.mode == 4) {
      return false;
    }
    return true;
  }

  DanmakuMergeCandidate _toCandidate(DanmakuElem element, int segmentIndex) {
    final normalizedText = DanmakuNormalizer.normalize(element.content);
    return DanmakuMergeCandidate(
      element: element,
      segmentIndex: segmentIndex,
      normalizedText: normalizedText,
      charTokens: normalizedText.runes.toList(growable: false),
      gramTokens: DanmakuSimilarityMatcher.buildGramTokens(normalizedText),
    );
  }

  DanmakuElem _buildRepresentative(DanmakuMergeCluster cluster) {
    final chosenText = _chooseText(cluster);
    final representative = cluster.root.element.deepCopy()
      ..content = chosenText
      ..count = cluster.peers.length;
    return representative;
  }

  String _chooseText(DanmakuMergeCluster cluster) {
    if (cluster.peers.length == 1) {
      return cluster.root.element.content;
    }

    final textCounts = <String, int>{};
    var bestCount = 0;
    var bestTexts = <String>[];
    for (final peer in cluster.peers) {
      final count = (textCounts[peer.normalizedText] ?? 0) + 1;
      textCounts[peer.normalizedText] = count;
      if (count > bestCount) {
        bestCount = count;
        bestTexts = <String>[peer.element.content];
      } else if (count == bestCount) {
        bestTexts.add(peer.element.content);
      }
    }

    bestTexts.sort((a, b) => a.length.compareTo(b.length));
    return bestTexts[bestTexts.length ~/ 2];
  }
}

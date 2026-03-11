// Inspired by pakku.js (https://github.com/xmcp/pakku.js)
// This file defines internal merge models used by the danmaku merge pipeline.

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';

enum DanmakuMergeReason {
  exact,
  charDistance,
  pinyinDistance,
  cosineDistance,
}

class DanmakuMergeConfig {
  const DanmakuMergeConfig({
    required this.enabled,
    required this.windowMs,
    required this.maxDistance,
    required this.maxCosine,
    required this.crossMode,
    required this.skipSubtitle,
    required this.skipAdvanced,
    required this.skipBottom,
  });

  final bool enabled;
  final int windowMs;
  final int maxDistance;
  final int maxCosine;
  final bool crossMode;
  final bool skipSubtitle;
  final bool skipAdvanced;
  final bool skipBottom;
}

class DanmakuMergeCandidate {
  const DanmakuMergeCandidate({
    required this.element,
    required this.segmentIndex,
    required this.normalizedText,
    required this.charTokens,
    required this.gramTokens,
  });

  final DanmakuElem element;
  final int segmentIndex;
  final String normalizedText;
  final List<int> charTokens;
  final List<int> gramTokens;

  int get mode => element.mode;
  int get progress => element.progress;
}

class DanmakuSimilarityMatchResult {
  const DanmakuSimilarityMatchResult({
    required this.reason,
    required this.distance,
  });

  final DanmakuMergeReason reason;
  final int distance;
}

class DanmakuMergeCluster {
  DanmakuMergeCluster(this.root) : peers = <DanmakuMergeCandidate>[root];

  final DanmakuMergeCandidate root;
  final List<DanmakuMergeCandidate> peers;

  int get progress => root.progress;

  void add(DanmakuMergeCandidate candidate) {
    peers.add(candidate);
  }
}

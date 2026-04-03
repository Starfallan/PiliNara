import 'dart:async' show unawaited;
import 'dart:collection';
import 'dart:io' show File;
import 'dart:math' show log;

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/grpc/dm.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/danmaku_merge/models.dart';
import 'package:PiliPlus/utils/danmaku_merge/worker_client.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;

class PlDanmakuController {
  PlDanmakuController(
    this._cid,
    this._plPlayerController,
    this._isFileSource,
  ) : _mergeDanmaku = _plPlayerController.mergeDanmaku {
    if (kDebugMode) {
      debugPrint(
        '[PlDanmakuController] create instance=${identityHashCode(this)} '
        'cid=$_cid fileSource=$_isFileSource merge=$_mergeDanmaku',
      );
    }
  }

  final int _cid;
  final PlPlayerController _plPlayerController;
  final bool _mergeDanmaku;
  final bool _isFileSource;

  late final _isLogin = Accounts.main.isLogin;

  final Map<int, List<DanmakuElem>> _dmSegMap = HashMap();
  final Map<int, List<DanmakuElem>> _rawDmSegMap = HashMap();
  final Map<int, int> _prefetchRetryAtMs = HashMap();
  final Map<int, int> _prefetchFailureCount = HashMap();
  final Set<int> _missingSeg = HashSet();
  // 已请求的段落标记
  late final Set<int> _requestedSeg = HashSet();
  late final Set<int> _queuedSeg = HashSet();
  late final Set<int> _mergedSeg = HashSet();
  final ListQueue<_QueuedDanmakuRequest> _downloadQueue = ListQueue();
  bool _downloadLoopRunning = false;
  bool _disposed = false;

  static const int segmentLength = 60 * 6 * 1000;
  static const int _prefetchRetryCooldownMs = 5000;
  static const int _prefetchLeadMs = 30000;
  static const int _maxPrefetchFailures = 5;

  // Default font size for standard danmaku (base before user scaling)
  // This matches the base size used in view.dart: 15 * scale
  static const int _defaultFontSize = 15;
  late final DanmakuMergeWorkerClient _mergeWorker = DanmakuMergeWorkerClient(
    dictionaryLoader: rootBundle.loadString,
  );

  /// Get the current enlarge threshold from settings
  /// Can be configured by user in danmaku settings
  int get _enlargeThreshold => Pref.danmakuEnlargeThreshold;

  int get _mergeWindowMs => Pref.mergeDanmakuWindowSeconds * 1000;

  DanmakuMergeConfig get _mergeConfig => DanmakuMergeConfig(
    enabled: _mergeDanmaku,
    windowMs: _mergeWindowMs,
    maxDistance: Pref.mergeDanmakuMaxDistance,
    maxCosine: Pref.mergeDanmakuMaxCosine,
    usePinyin: Pref.mergeDanmakuUsePinyin,
    crossMode: Pref.mergeDanmakuCrossMode,
    skipSubtitle: Pref.mergeDanmakuSkipSubtitle,
    skipAdvanced: Pref.mergeDanmakuSkipAdvanced,
    skipBottom: Pref.mergeDanmakuSkipBottom,
  );

  /// Get the current log base from settings
  /// Can be configured by user in danmaku settings
  int get _logBase => Pref.danmakuEnlargeLogBase;

  /// Get precomputed log value for the current base
  double get _logBaseValue => log(_logBase.toDouble());

  void dispose() {
    if (kDebugMode) {
      debugPrint(
        '[PlDanmakuController] dispose instance=${identityHashCode(this)} '
        'cid=$_cid requested=${_requestedSeg.length} merged=${_mergedSeg.length}',
      );
    }
    _disposed = true;
    _mergeWorker.dispose();
    _dmSegMap.clear();
    _rawDmSegMap.clear();
    _prefetchRetryAtMs.clear();
    _prefetchFailureCount.clear();
    _missingSeg.clear();
    _requestedSeg.clear();
    _queuedSeg.clear();
    _mergedSeg.clear();
    _downloadQueue.clear();
  }

  static int calcSegment(int progress) {
    return progress ~/ segmentLength;
  }

  /// Calculate the font size enlargement rate based on the number of merged danmaku
  ///
  /// Formula adapted from Pakku.js for mobile screens:
  /// - count <= threshold: return 1 (no enlargement)
  /// - count > threshold: return log(count) / log(base)
  /// Both threshold and base can be configured in settings
  double _calcEnlargeRate(int count) {
    if (count <= _enlargeThreshold) {
      return 1.0;
    }
    return log(count) / _logBaseValue;
  }

  /// Calculate enlarged font size for merged danmaku
  /// Base font size is typically 15 for standard danmaku
  int _calcEnlargedFontSize(int baseFontSize, int count) {
    return (baseFontSize * _calcEnlargeRate(count)).round();
  }

  Future<void> queryDanmaku(int segmentIndex, {bool isPrefetch = false}) async {
    if (_isFileSource) {
      return;
    }
    if (_requestedSeg.contains(segmentIndex)) {
      if (kDebugMode) {
        debugPrint(
          '[PlDanmakuController] skip duplicate instance=${identityHashCode(this)} '
          'cid=$_cid segment=$segmentIndex requested=${_requestedSeg.length}',
        );
      }
      return;
    }
    if (_missingSeg.contains(segmentIndex)) {
      if (kDebugMode) {
        debugPrint(
          '[PlDanmakuController] skip missing instance=${identityHashCode(this)} '
          'cid=$_cid segment=$segmentIndex',
        );
      }
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (isPrefetch) {
      final retryAtMs = _prefetchRetryAtMs[segmentIndex];
      if (retryAtMs != null && nowMs < retryAtMs) {
        if (kDebugMode) {
          debugPrint(
            '[PlDanmakuController] skip prefetch cooldown '
            'instance=${identityHashCode(this)} cid=$_cid segment=$segmentIndex '
            'retryAfter=${retryAtMs - nowMs}ms',
          );
        }
        return;
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[PlDanmakuController] request instance=${identityHashCode(this)} '
        'cid=$_cid segment=$segmentIndex requestedBefore=${_requestedSeg.length} '
        'prefetch=$isPrefetch',
      );
    }
    _requestedSeg.add(segmentIndex);
    final res = await DmGrpc.dmSegMobile(
      cid: _cid,
      segmentIndex: segmentIndex + 1,
    );

    if (res case Success(:final response)) {
      if (kDebugMode) {
        debugPrint(
          '[PlDanmakuController] response instance=${identityHashCode(this)} '
          'cid=$_cid segment=$segmentIndex elems=${response.elems.length} '
          'prefetch=$isPrefetch',
        );
      }
      _prefetchRetryAtMs.remove(segmentIndex);
      _prefetchFailureCount.remove(segmentIndex);
      if (response.state == 1) {
        _plPlayerController.dmState.add(_cid);
      }
      await handleDanmaku(segmentIndex, response.elems);
      if (_mergeDanmaku) {
        _scheduleSegment(segmentIndex + 1, isPrefetch: true);
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          '[PlDanmakuController] request failed instance=${identityHashCode(this)} '
          'cid=$_cid segment=$segmentIndex prefetch=$isPrefetch',
        );
      }
      if (isPrefetch) {
        final failures = (_prefetchFailureCount[segmentIndex] ?? 0) + 1;
        _prefetchFailureCount[segmentIndex] = failures;
        _prefetchRetryAtMs[segmentIndex] = nowMs + _prefetchRetryCooldownMs;
        if (failures >= _maxPrefetchFailures) {
          _missingSeg.add(segmentIndex);
          if (kDebugMode) {
            debugPrint(
              '[PlDanmakuController] mark missing instance=${identityHashCode(this)} '
              'cid=$_cid segment=$segmentIndex failures=$failures',
            );
          }
        }
        if (segmentIndex > 0) {
          unawaited(_mergeSegment(segmentIndex - 1));
        }
      }
      _requestedSeg.remove(segmentIndex);
    }
  }

  Future<void> handleDanmaku(int segmentIndex, List<DanmakuElem> elems) async {
    if (elems.isEmpty) return;
    // final uniques = HashMap<String, DanmakuElem>();
    // // Track base font sizes for merged danmaku to avoid recalculation
    // final baseFontSizes = HashMap<String, int>();

    final filters = _plPlayerController.filters;
    final danmakuWeight = DanmakuOptions.danmakuWeight;
    final shouldFilter = filters.count != 0;
    for (final element in elems) {
      if (_isLogin) {
        element.isSelf = element.midHash == _plPlayerController.midHash;
      }
    }

    if (!_mergeDanmaku) {
      _storeDanmaku(elems);
      return;
    }

    _rawDmSegMap[segmentIndex] = elems;
    await _tryMergeReadySegments(segmentIndex);
  }

  Future<void> _tryMergeReadySegments(int segmentIndex) async {
    if (segmentIndex > 0) {
      await _mergeSegment(segmentIndex - 1);
    }
    if (_rawDmSegMap.containsKey(segmentIndex + 1) ||
        _isLastSegment(segmentIndex)) {
      await _mergeSegment(segmentIndex);
    }
  }

  Future<void> _mergeSegment(int segmentIndex) async {
    if (_mergedSeg.contains(segmentIndex)) {
      return;
    }
    final currentSegment = _rawDmSegMap[segmentIndex];
    if (currentSegment == null || currentSegment.isEmpty) {
      return;
    }
    if (!_isLastSegment(segmentIndex) &&
        !_rawDmSegMap.containsKey(segmentIndex + 1)) {
      if (kDebugMode) {
        debugPrint(
          '[DanmakuMerge] postpone segment=$segmentIndex waiting for next chunk',
        );
      }
      return;
    }

    final sortedCurrent = List<DanmakuElem>.from(currentSegment)
      ..sort((a, b) => a.progress.compareTo(b.progress));
    final lastProgress = sortedCurrent.last.progress;

    final nextSegment = _rawDmSegMap[segmentIndex + 1];
    final nextSegmentPrefix =
        nextSegment
            ?.where(
              (element) => element.progress < lastProgress + _mergeWindowMs,
            )
            .toList(growable: false) ??
        const <DanmakuElem>[];

    try {
      if (kDebugMode) {
        debugPrint(
          '[DanmakuMerge] start segment=$segmentIndex '
          'current=${sortedCurrent.length} nextPrefix=${nextSegmentPrefix.length} '
          'window=$_mergeWindowMs maxDistance=${_mergeConfig.maxDistance} '
          'maxCosine=${_mergeConfig.maxCosine} usePinyin=${_mergeConfig.usePinyin}',
        );
      }
      final merged = await _mergeWorker.mergeSegment(
        segmentIndex: segmentIndex,
        config: _mergeConfig,
        currentSegment: sortedCurrent,
        nextSegmentPrefix: nextSegmentPrefix,
      );
      if (_disposed) {
        return;
      }
      if (kDebugMode) {
        debugPrint(
          '[DanmakuMerge] merged segment=$segmentIndex '
          'input=${sortedCurrent.length} output=${merged.length}',
        );
      }
      _mergedSeg.add(segmentIndex);
      _storeDanmaku(merged);
    } catch (e, s) {
      Utils.reportError(e, s);
      if (kDebugMode) {
        debugPrint(
          '[DanmakuMerge] fallback segment=$segmentIndex error=$e',
        );
        debugPrintStack(stackTrace: s);
      }
      if (_disposed) {
        return;
      }
      _mergedSeg.add(segmentIndex);
      _storeDanmaku(sortedCurrent);
    }
  }

  void _storeDanmaku(List<DanmakuElem> elems) {
    final shouldFilter = _plPlayerController.filters.count != 0;
    final danmakuWeight = DanmakuOptions.danmakuWeight;
    for (final element in elems) {
      if (!element.isSelf) {
        if (element.weight < danmakuWeight ||
            (shouldFilter && _plPlayerController.filters.remove(element))) {
          continue;
        }
      }

      if (element.count > 1) {
        element.fontsize = _calcEnlargedFontSize(
          _defaultFontSize,
          element.count,
        );
      }

      final pos = element.progress ~/ 100;
      (_dmSegMap[pos] ??= []).add(element);
    }
  }

  List<DanmakuElem>? getCurrentDanmaku(int progress) {
    if (_isFileSource) {
      initFileDmIfNeeded();
    } else {
      final int segmentIndex = calcSegment(progress);
      if (_shouldPrefetchNextSegment(progress, segmentIndex)) {
        if (kDebugMode) {
          debugPrint(
            '[PlDanmakuController] prefetch instance=${identityHashCode(this)} '
            'cid=$_cid progress=$progress currentSegment=$segmentIndex nextSegment=${segmentIndex + 1}',
          );
        }
        _scheduleSegment(segmentIndex + 1, isPrefetch: true);
      }
      if (!_requestedSeg.contains(segmentIndex)) {
        if (kDebugMode) {
          debugPrint(
            '[PlDanmakuController] current miss instance=${identityHashCode(this)} '
            'cid=$_cid progress=$progress segment=$segmentIndex',
          );
        }
        _scheduleSegment(segmentIndex);
        _scheduleSegment(segmentIndex + 1, isPrefetch: true);
        return null;
      }
    }
    return _dmSegMap[progress ~/ 100];
  }

  bool _shouldPrefetchNextSegment(int progress, int segmentIndex) {
    if (!_mergeDanmaku) {
      return false;
    }
    final maxSegmentIndex = _maxSegmentIndex;
    if (maxSegmentIndex == null) {
      return false;
    }
    if (segmentIndex + 1 > maxSegmentIndex) {
      return false;
    }
    final currentSegmentEndMs = (segmentIndex + 1) * segmentLength;
    return currentSegmentEndMs - progress <= _prefetchLeadMs;
  }

  int? get _maxSegmentIndex {
    final totalDurationMs = _plPlayerController.duration.value.inMilliseconds;
    if (totalDurationMs <= 0) {
      return null;
    }
    return (totalDurationMs - 1) ~/ segmentLength;
  }

  bool _isLastSegment(int segmentIndex) {
    final maxSegmentIndex = _maxSegmentIndex;
    return maxSegmentIndex != null && segmentIndex >= maxSegmentIndex;
  }

  void _scheduleSegment(int segmentIndex, {bool isPrefetch = false}) {
    if (_isFileSource || _disposed || segmentIndex < 0) {
      return;
    }
    if (isPrefetch) {
      final maxSegmentIndex = _maxSegmentIndex;
      if (maxSegmentIndex == null || segmentIndex > maxSegmentIndex) {
        return;
      }
    }
    if (_missingSeg.contains(segmentIndex)) {
      return;
    }
    if (_requestedSeg.contains(segmentIndex) ||
        _queuedSeg.contains(segmentIndex)) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (isPrefetch) {
      final retryAtMs = _prefetchRetryAtMs[segmentIndex];
      if (retryAtMs != null && nowMs < retryAtMs) {
        if (kDebugMode) {
          debugPrint(
            '[PlDanmakuController] skip prefetch cooldown '
            'instance=${identityHashCode(this)} cid=$_cid segment=$segmentIndex '
            'retryAfter=${retryAtMs - nowMs}ms',
          );
        }
        return;
      }
    }

    final request = _QueuedDanmakuRequest(
      segmentIndex: segmentIndex,
      isPrefetch: isPrefetch,
    );
    _queuedSeg.add(segmentIndex);
    if (isPrefetch) {
      _downloadQueue.addLast(request);
      if (kDebugMode) {
        debugPrint(
          '[PlDanmakuController] queue prefetch instance=${identityHashCode(this)} '
          'cid=$_cid segment=$segmentIndex queue=${_downloadQueue.length}',
        );
      }
    } else {
      _downloadQueue.addFirst(request);
      if (kDebugMode) {
        debugPrint(
          '[PlDanmakuController] queue current instance=${identityHashCode(this)} '
          'cid=$_cid segment=$segmentIndex queue=${_downloadQueue.length}',
        );
      }
    }
    unawaited(_pumpDownloadQueue());
  }

  Future<void> _pumpDownloadQueue() async {
    if (_downloadLoopRunning || _disposed) {
      return;
    }
    _downloadLoopRunning = true;
    try {
      while (_downloadQueue.isNotEmpty && !_disposed) {
        final request = _downloadQueue.removeFirst();
        _queuedSeg.remove(request.segmentIndex);
        await queryDanmaku(
          request.segmentIndex,
          isPrefetch: request.isPrefetch,
        );
      }
    } finally {
      _downloadLoopRunning = false;
    }
  }

  bool _fileDmLoaded = false;

  void initFileDmIfNeeded() {
    if (_fileDmLoaded) return;
    _fileDmLoaded = true;
    _initFileDm();
  }

  @pragma('vm:notify-debugger-on-exception')
  Future<void> _initFileDm() async {
    try {
      final file = File(
        path.join(
          (_plPlayerController.dataSource as FileSource).dir,
          PathUtils.danmakuName,
        ),
      );
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final elem = DmSegMobileReply.fromBuffer(bytes).elems;
      await handleDanmaku(0, elem);
    } catch (e, s) {
      Utils.reportError(e, s);
    }
  }
}

class _QueuedDanmakuRequest {
  const _QueuedDanmakuRequest({
    required this.segmentIndex,
    required this.isPrefetch,
  });

  final int segmentIndex;
  final bool isPrefetch;
}

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
  // 已请求的段落标记
  late final Set<int> _requestedSeg = HashSet();
  late final Set<int> _mergedSeg = HashSet();
  bool _disposed = false;

  static const int segmentLength = 60 * 6 * 1000;

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
    _requestedSeg.clear();
    _mergedSeg.clear();
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

  Future<void> queryDanmaku(int segmentIndex) async {
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
    if (kDebugMode) {
      debugPrint(
        '[PlDanmakuController] request instance=${identityHashCode(this)} '
        'cid=$_cid segment=$segmentIndex requestedBefore=${_requestedSeg.length}',
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
          'cid=$_cid segment=$segmentIndex elems=${response.elems.length}',
        );
      }
      if (response.state == 1) {
        _plPlayerController.dmState.add(_cid);
      }
      await handleDanmaku(segmentIndex, response.elems);
    } else {
      if (kDebugMode) {
        debugPrint(
          '[PlDanmakuController] request failed instance=${identityHashCode(this)} '
          'cid=$_cid segment=$segmentIndex',
        );
      }
      _requestedSeg.remove(segmentIndex);
    }
  }

  Future<void> handleDanmaku(int segmentIndex, List<DanmakuElem> elems) async {
    if (elems.isEmpty) return;
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
    await _mergeSegment(segmentIndex);
  }

  Future<void> _mergeSegment(int segmentIndex) async {
    if (_mergedSeg.contains(segmentIndex)) {
      return;
    }
    final currentSegment = _rawDmSegMap[segmentIndex];
    if (currentSegment == null || currentSegment.isEmpty) {
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
      if (_mergeDanmaku && !_requestedSeg.contains(segmentIndex + 1)) {
        if (kDebugMode) {
          debugPrint(
            '[PlDanmakuController] prefetch instance=${identityHashCode(this)} '
            'cid=$_cid progress=$progress currentSegment=$segmentIndex nextSegment=${segmentIndex + 1}',
          );
        }
        queryDanmaku(segmentIndex + 1);
      }
      if (!_requestedSeg.contains(segmentIndex)) {
        if (kDebugMode) {
          debugPrint(
            '[PlDanmakuController] current miss instance=${identityHashCode(this)} '
            'cid=$_cid progress=$progress segment=$segmentIndex',
          );
        }
        queryDanmaku(segmentIndex);
        return null;
      }
    }
    return _dmSegMap[progress ~/ 100];
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

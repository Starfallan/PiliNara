import 'dart:collection';
import 'dart:io' show File;
import 'dart:math' show log;

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/grpc/dm.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:path/path.dart' as path;

class PlDanmakuController {
  PlDanmakuController(
    this._cid,
    this._plPlayerController,
    this._isFileSource,
  ) : _mergeDanmaku = _plPlayerController.mergeDanmaku;

  final int _cid;
  final PlPlayerController _plPlayerController;
  final bool _mergeDanmaku;
  final bool _isFileSource;

  late final _isLogin = Accounts.main.isLogin;

  final Map<int, List<DanmakuElem>> _dmSegMap = {};
  // 已请求的段落标记
  late final Set<int> _requestedSeg = {};

  static const int segmentLength = 60 * 6 * 1000;
  
  // Default font size for standard danmaku (base before user scaling)
  // This matches the base size used in view.dart: 15 * scale
  static const int _defaultFontSize = 15;
  
  /// Get the current enlarge threshold from settings
  /// Can be configured by user in danmaku settings
  int get _enlargeThreshold => Pref.danmakuEnlargeThreshold;
  
  /// Get the current log base from settings  
  /// Can be configured by user in danmaku settings
  int get _logBase => Pref.danmakuEnlargeLogBase;
  
  /// Get precomputed log value for the current base
  double get _logBaseValue => log(_logBase.toDouble());

  void dispose() {
    _dmSegMap.clear();
    _requestedSeg.clear();
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

  /// Get the base font size from DanmakuElem, falling back to default if not set
  static int _getBaseFontSize(DanmakuElem element) {
    return element.fontsize != 0 ? element.fontsize : _defaultFontSize;
  }

  Future<void> queryDanmaku(int segmentIndex) async {
    if (_isFileSource) {
      return;
    }
    if (_requestedSeg.contains(segmentIndex)) {
      return;
    }
    _requestedSeg.add(segmentIndex);
    final result = await DmGrpc.dmSegMobile(
      cid: _cid,
      segmentIndex: segmentIndex + 1,
    );

    if (result.isSuccess) {
      final data = result.data;
      if (data.state == 1) {
        _plPlayerController.dmState.add(_cid);
      }
      handleDanmaku(data.elems);
    } else {
      _requestedSeg.remove(segmentIndex);
    }
  }

  void handleDanmaku(List<DanmakuElem> elems) {
    if (elems.isEmpty) return;
    final uniques = HashMap<String, DanmakuElem>();
    // Track base font sizes for merged danmaku to avoid recalculation
    final baseFontSizes = HashMap<String, int>();

    final shouldFilter = _plPlayerController.filters.count != 0;
    final danmakuWeight = _plPlayerController.danmakuWeight;
    for (final element in elems) {
      if (_isLogin) {
        element.isSelf = element.midHash == _plPlayerController.midHash;
      }

      if (!element.isSelf) {
        if (_mergeDanmaku) {
          final elem = uniques[element.content];
          if (elem == null) {
            // First occurrence: initialize count
            // Don't set fontsize yet - only set it when actually merged (count > 1)
            baseFontSizes[element.content] = _defaultFontSize;
            uniques[element.content] = element..count = 1;
          } else {
            // Subsequent occurrence: this is now a merged danmaku
            elem.count++;
            final baseFontSize = baseFontSizes[element.content] ?? _defaultFontSize;
            // Calculate enlarged font size (rate is 1.0 for count <= 5, increases after)
            elem.fontsize = _calcEnlargedFontSize(baseFontSize, elem.count);
            continue;
          }
        }

        if (element.weight < danmakuWeight ||
            (shouldFilter && _plPlayerController.filters.remove(element))) {
          continue;
        }
      }

      final int pos = element.progress ~/ 100; //每0.1秒存储一次
      (_dmSegMap[pos] ??= []).add(element);
    }
  }

  List<DanmakuElem>? getCurrentDanmaku(int progress) {
    if (_isFileSource) {
      initFileDmIfNeeded();
    } else {
      final int segmentIndex = calcSegment(progress);
      if (!_requestedSeg.contains(segmentIndex)) {
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
        path.join(_plPlayerController.dirPath!, PathUtils.danmakuName),
      );
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final elem = DmSegMobileReply.fromBuffer(bytes).elems;
      handleDanmaku(elem);
    } catch (e, s) {
      Utils.reportError(e, s);
    }
  }
}

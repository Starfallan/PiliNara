import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class RecommendFilter {
  static int minDurationForRcmd = Pref.minDurationForRcmd;
  static int minPlayForRcmd = Pref.minPlayForRcmd;
  static int minLikeRatioForRecommend = Pref.minLikeRatioForRecommend;
  static bool exemptFilterForFollowed = Pref.exemptFilterForFollowed;
  static bool applyFilterToRelatedVideos = Pref.applyFilterToRelatedVideos;
  static bool applyFilterToHotVideos = Pref.applyFilterToHotVideos;
  static bool applyFilterToRankVideos = Pref.applyFilterToRankVideos;
  static bool applyFilterToSearch = Pref.applyFilterToSearch;

  static RegExp rcmdRegExp = RegExp(
    Pref.parseBanWordToRegex(Pref.banWordForRecommend),
    caseSensitive: false,
  );
  static bool enableFilter = rcmdRegExp.pattern.isNotEmpty;
  static RegExp rcmdUpNameRegExp = RegExp(
    Pref.parseBanWordToRegex(Pref.banWordForRecommendUpName),
    caseSensitive: false,
  );
  static bool enableUpNameFilter = rcmdUpNameRegExp.pattern.isNotEmpty;
  static Map<int, String> recommendBlockedMids = Pref.recommendBlockedMids;

  static bool isWhitelisted(int? mid) {
    return mid != null && GlobalData().whitelistMids.containsKey(mid);
  }

  // (web/app)rcmd
  static bool filterWithExempt(BaseVideoItemModel videoItem) {
    //由于相关视频中没有已关注标签，只能视为非关注视频
    if (videoItem.isFollowed && exemptFilterForFollowed) {
      return false;
    }
    return filterAll(videoItem);
  }

  /// hot/rank/[filterAll]
  static bool filterLikeRatio(int? like, int? view) {
    if (view != null) {
      return (view > -1 && view < minPlayForRcmd) ||
          (like != null &&
              like > -1 &&
              like * 100 < minLikeRatioForRecommend * view);
    }
    return false;
  }

  /// hot/rank/[filterAll]
  static bool filterTitle(String title) {
    return (enableFilter && rcmdRegExp.hasMatch(title));
  }

  static bool filterUpName(String? name) {
    return enableUpNameFilter &&
        name != null &&
        rcmdUpNameRegExp.hasMatch(name);
  }

  static bool filterUser(int? mid) {
    return recommendBlockedMids.isNotEmpty &&
        mid != null &&
        recommendBlockedMids.containsKey(mid);
  }

  /// [filterAll]
  static bool filterDuration(int duration) {
    return duration > 0 && duration < minDurationForRcmd;
  }

  /// related/[filterWithExempt]
  static bool filterAll(BaseVideoItemModel videoItem) {
    final mid = videoItem.owner.mid;
    if (filterUser(mid)) {
      return true;
    }
    if (isWhitelisted(mid)) {
      return false;
    }
    return filterDuration(videoItem.duration) ||
        filterLikeRatio(videoItem.stat.like, videoItem.stat.view) ||
        filterTitle(videoItem.title) ||
        filterUpName(videoItem.owner.name);
  }

  /// 视频标签关键词过滤（标签黑名单）
  static RegExp videoTagRegExp = RegExp(
    Pref.parseBanWordToRegex(Pref.banWordForVideoTag),
    caseSensitive: false,
  );
  static bool enableVideoTagFilter = videoTagRegExp.pattern.isNotEmpty;

  /// bvid -> 标签名列表（会话内 LRU 缓存，命中后移到表尾）
  static final Map<String, List<String>> _videoTagCache = {};

  /// 正在拉取的 bvid -> Future，同一视频的并发请求只发一次
  static final Map<String, Future<List<String>?>> _videoTagInflight = {};

  static const int _videoTagCacheMax = 1000;
  static const int _videoTagConcurrency = 6;

  /// 单次列表加载最多等待标签预取的时间，超时后剩余请求转入后台完成
  static const Duration _videoTagWaitBudget = Duration(milliseconds: 1200);

  static List<String>? cachedVideoTags(String? bvid) {
    if (bvid == null || bvid.isEmpty) {
      return null;
    }
    final tags = _videoTagCache.remove(bvid);
    if (tags != null) {
      // 命中后移到表尾，实现 LRU 淘汰
      _videoTagCache[bvid] = tags;
    }
    return tags;
  }

  /// 读取（必要时拉取）单个视频的标签，失败返回 null
  static Future<List<String>?> fetchVideoTags(
    String? bvid, {
    bool refresh = false,
  }) {
    if (bvid == null || bvid.isEmpty) {
      return Future.value(null);
    }
    if (!refresh) {
      final cached = cachedVideoTags(bvid);
      if (cached != null) {
        return Future.value(cached);
      }
    }
    return _videoTagInflight[bvid] ??= _fetchVideoTags(bvid);
  }

  static Future<List<String>?> _fetchVideoTags(String bvid) async {
    try {
      final res = await UserHttp.videoTags(bvid: bvid);
      final data = res.dataOrNull;
      if (data == null) {
        return _videoTagCache[bvid];
      }
      final tags = <String>[
        for (final item in data)
          if (item.tagName?.isNotEmpty == true) item.tagName!,
      ];
      if (_videoTagCache.length >= _videoTagCacheMax) {
        // 淘汰最久未访问的一条
        _videoTagCache.remove(_videoTagCache.keys.first);
      }
      _videoTagCache.remove(bvid);
      _videoTagCache[bvid] = tags;
      return tags;
    } catch (_) {
      return _videoTagCache[bvid];
    } finally {
      _videoTagInflight.remove(bvid);
    }
  }

  /// 批量预取标签：仅开启标签过滤时生效；固定并发，最多等待 [budget]，
  /// 超时后剩余请求转入后台继续，下次渲染直接命中缓存
  static Future<void> prefetchVideoTags(
    Iterable<String?>? bvids, {
    Duration budget = _videoTagWaitBudget,
  }) async {
    if (!enableVideoTagFilter || bvids == null) {
      return;
    }
    final pending = <String>{};
    for (final bvid in bvids) {
      if (bvid == null || bvid.isEmpty || cachedVideoTags(bvid) != null) {
        continue;
      }
      pending.add(bvid);
    }
    final list = pending.toList();
    // 固定并发的工作池：任意一条完成立刻取下一条，不必等整批
    var next = 0;
    Future<void> worker() async {
      while (next < list.length) {
        await fetchVideoTags(list[next++]);
      }
    }

    final size = list.length < _videoTagConcurrency
        ? list.length
        : _videoTagConcurrency;
    await Future.wait(<Future<void>>[
      for (var i = 0; i < size; i++) worker(),
    ]).timeout(budget, onTimeout: () => const <void>[]);
  }

  /// 标签命中黑名单则返回 true（调用方据此过滤掉该视频）
  static bool filterVideoTags(String? bvid) {
    if (!enableVideoTagFilter) {
      return false;
    }
    final tags = cachedVideoTags(bvid);
    if (tags == null || tags.isEmpty) {
      return false;
    }
    for (final tag in tags) {
      if (videoTagRegExp.hasMatch(tag)) {
        return true;
      }
    }
    return false;
  }

  static bool searchShouldRemove(int? mid, String title) {
    if (!applyFilterToSearch) return false;
    if (filterUser(mid)) return true;
    if (isWhitelisted(mid)) return false;
    return filterTitle(title);
  }
}

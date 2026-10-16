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

  /// bvid -> 标签名列表（会话内缓存，超出上限按插入顺序淘汰）
  static final Map<String, List<String>> videoTagCache = {};

  /// 正在拉取的 bvid -> Future，同一视频的并发请求只发一次
  static final Map<String, Future<List<String>?>> _videoTagInflight = {};

  static const int _videoTagCacheMax = 1000;
  static const int _videoTagConcurrency = 6;

  static List<String>? cachedVideoTags(String? bvid) =>
      bvid == null || bvid.isEmpty ? null : videoTagCache[bvid];

  /// 读取（必要时拉取）单个视频的标签，失败返回 null
  static Future<List<String>?> fetchVideoTags(
    String? bvid, {
    bool refresh = false,
  }) {
    if (bvid == null || bvid.isEmpty) {
      return Future.value(null);
    }
    if (!refresh && videoTagCache.containsKey(bvid)) {
      return Future.value(videoTagCache[bvid]);
    }
    return _videoTagInflight[bvid] ??= _fetchVideoTags(bvid);
  }

  static Future<List<String>?> _fetchVideoTags(String bvid) async {
    try {
      final res = await UserHttp.videoTags(bvid: bvid);
      final data = res.dataOrNull;
      if (data == null) {
        return videoTagCache[bvid];
      }
      final tags = <String>[];
      for (final item in data) {
        final name = item.tagName;
        if (name != null && name.isNotEmpty) {
          tags.add(name);
        }
      }
      if (videoTagCache.length >= _videoTagCacheMax) {
        videoTagCache.remove(videoTagCache.keys.first);
      }
      videoTagCache[bvid] = tags;
      return tags;
    } catch (_) {
      return videoTagCache[bvid];
    } finally {
      _videoTagInflight.remove(bvid);
    }
  }

  /// 批量预取标签（仅开启标签过滤时生效，限并发，失败静默）
  static Future<void> prefetchVideoTags(Iterable<String?>? bvids) async {
    if (!enableVideoTagFilter || bvids == null) {
      return;
    }
    final pending = <String>{};
    for (final bvid in bvids) {
      if (bvid == null || bvid.isEmpty) {
        continue;
      }
      if (videoTagCache.containsKey(bvid) ||
          _videoTagInflight.containsKey(bvid)) {
        continue;
      }
      pending.add(bvid);
    }
    final list = pending.toList();
    for (var i = 0; i < list.length; i += _videoTagConcurrency) {
      final end = i + _videoTagConcurrency;
      await Future.wait(
        list
            .sublist(i, end > list.length ? list.length : end)
            .map(fetchVideoTags),
      );
    }
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

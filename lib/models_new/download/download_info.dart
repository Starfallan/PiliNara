import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show MultiSelectData;

/// 一个「视频页」：PGC 的一季、UGC 合集里的单个视频、或单P/分P 视频本身。
/// 页内条目按 [sortKey] 排列，即分P 序号或番剧集序号。
class DownloadPageInfo with MultiSelectData {
  final String pageId;
  final String dirPath;
  final String title;
  String cover;
  int sortKey;
  final int? seasonType;
  final List<BiliDownloadEntryInfo> entries;

  DownloadPageInfo({
    required this.pageId,
    required this.dirPath,
    required this.title,
    required this.cover,
    required this.sortKey,
    this.seasonType,
    required this.entries,
  });
}

/// 顶层分组：一个 UGC 合集，或一个 PGC 季，或不属于任何合集的单个视频。
///
/// [seasonInfo] 为空时表示这不是合集成员（PGC 一季或单视频），此时
/// [pageId] 就是分组键（PGC 为 seasonId，UGC 为 avid）。
class DownloadSeasonInfo with MultiSelectData {
  SeasonInfo? seasonInfo;
  final String pageId;
  final List<DownloadPageInfo> pages;

  DownloadSeasonInfo({
    required this.seasonInfo,
    required this.pageId,
    required this.pages,
  });

  /// 跨路由传递的稳定标识：不随成员增删变化，也不与其他分组混淆。
  String get playlistKey =>
      seasonInfo != null ? 'ugc-season:${seasonInfo!.id}' : 'pgc:$pageId';
}

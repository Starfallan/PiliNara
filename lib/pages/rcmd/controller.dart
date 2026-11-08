import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/rcmd_source.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

class RcmdController extends CommonListController<
    List<BaseRcmdVideoItemModel>, BaseRcmdVideoItemModel> {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  List<RcmdSource> rcmdSources = Pref.rcmdSources;
  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  final _sourcePages = <RcmdSource, int>{};
  int _generation = 0;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  Future<LoadingState<List<BaseRcmdVideoItemModel>>> _fetch(
    RcmdSource source,
    int freshIdx,
  ) async {
    try {
      return await switch (source) {
        RcmdSource.app => VideoHttp.rcmdVideoListApp(freshIdx: freshIdx),
        RcmdSource.web => VideoHttp.rcmdVideoList(freshIdx: freshIdx, ps: 20),
        RcmdSource.desktop => VideoHttp.rcmdVideoList(
          freshIdx: freshIdx, ps: 30, desktop: true,
        ),
      };
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<LoadingState<List<BaseRcmdVideoItemModel>>> customGetData() async {
    final generation = _generation;
    final sources = List<RcmdSource>.of(rcmdSources);
    final results = await Future.wait([
      for (final source in sources) _fetch(source, _sourcePages[source] ?? 0),
    ]);
    if (isClosed || generation != _generation) return const Success([]);

    final lists = <List<BaseRcmdVideoItemModel>>[];
    Error? error;
    for (var i = 0; i < results.length; i++) {
      switch (results[i]) {
        case Success(:final response):
          lists.add(response);
          _sourcePages[sources[i]] = (_sourcePages[sources[i]] ?? 0) + 1;
        case Error failure:
          error = failure;
          logger.w('${sources[i].label}推荐获取失败: $failure');
        default:
      }
    }
    if (lists.isEmpty) return error ?? const Error('推荐获取失败');
    if (sources.length == 1) return Success(lists.single);

    final seen = <String>{};
    final merged = <BaseRcmdVideoItemModel>[];
    for (var index = 0; lists.any((list) => index < list.length); index++) {
      for (final list in lists) {
        if (index >= list.length) continue;
        final item = list[index];
        final key = item.aid != null ? 'av${item.aid}' : item.bvid;
        if (key == null || seen.add(key)) merged.add(item);
      }
    }
    return Success(merged);
  }

  @override
  Future<void> queryData([bool isRefresh = true]) async {
    if (isLoading || isClosed) return;
    final generation = _generation;
    isLoading = true;
    try {
      final res = await customGetData();
      if (isClosed || generation != _generation) return;
      if (res case Success(:final response)) {
        final items = List<BaseRcmdVideoItemModel>.of(response);
        if (isRefresh) {
          if (enableSaveLastData) {
            if (loadingState.value case Success(:final response)) {
              if (response != null && response.isNotEmpty) {
                lastRefreshAt = savedRcmdTip ? items.length : null;
                items.addAll(response.length > 200 ? response.take(50) : response);
              }
            }
          }
          loadingState.value = Success(items);
        } else if (loadingState.value case Success(:final response)) {
          response?.addAll(items);
          loadingState.refresh();
        }
        page++;
      } else if (res case Error failure) {
        if (isRefresh && !(enableSaveLastData &&
            loadingState.value is Success<List<BaseRcmdVideoItemModel>?>)) {
          loadingState.value = failure;
        } else {
          failure.toast();
        }
      }
    } finally {
      if (generation == _generation) isLoading = false;
    }
  }

  @override
  Future<void> onRefresh() {
    _generation++;
    _sourcePages.clear();
    page = 0;
    lastRefreshAt = null;
    isLoading = false;
    return queryData();
  }

  Future<void> switchSources(List<RcmdSource> sources) {
    rcmdSources = List.of(sources);
    return onReload();
  }
}

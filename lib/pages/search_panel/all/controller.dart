import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/url_utils.dart';

class SearchAllController
    extends SearchPanelController<SearchAllData, dynamic> {
  SearchAllController({
    required super.keyword,
    required super.searchType,
    required super.tag,
  });

  late bool hasJump2Video = false;

  @override
  void onInit() {
    super.onInit();
    jump2Video();
  }

  @override
  List? getDataList(response) {
    return response.list;
  }

  @override
  bool customHandleResponse(bool isRefresh, Success response) {
    searchResultController?.count[searchType.index] =
        response.response.numResults ?? 0;
    if (searchType == SearchType.video && !hasJump2Video && isRefresh) {
      hasJump2Video = true;
      onPushDetail(response.response.list);
    }
    return false;
  }

  @override
  Future<LoadingState<SearchAllData>> customGetData() => SearchHttp.searchAll(
    keyword: keyword,
    page: page,
    order: order,
    duration: null,
    tids: videoZoneType?.tids,
    orderSort: userOrderType?.value.orderSort,
    userType: userType?.value.index,
    categoryId: articleZoneType?.value.categoryId,
    pubBegin: pubBegin,
    pubEnd: pubEnd,
  );

  void onPushDetail(dynamic resultList) {
    try {
      int? aid = int.tryParse(keyword);
      if (aid != null && resultList.first.aid == aid) {
        PiliScheme.videoPush(aid, null, showDialog: false);
      }
    } catch (_) {}
  }

  static final _b23Regex = RegExp(r'b23\.tv/[A-Za-z0-9]{7}$', caseSensitive: false);

  Future<void> jump2Video() async {
    if (IdUtils.avRegexExact.hasMatch(keyword)) {
      hasJump2Video = true;
      PiliScheme.videoPush(
        int.parse(keyword.substring(2)),
        null,
        showDialog: false,
      );
    } else if (IdUtils.bvRegexExact.hasMatch(keyword)) {
      hasJump2Video = true;
      PiliScheme.videoPush(null, keyword, showDialog: false);
    } else if (_b23Regex.hasMatch(keyword)) {
      hasJump2Video = true;
      final redirectUrl = await UrlUtils.parseRedirectUrl(keyword);
      if (redirectUrl != null) {
        final matchRes = IdUtils.matchAvorBv(input: redirectUrl);
        final aid = matchRes.av;
        String? bvid = matchRes.bv;
        if (aid != null || bvid != null) {
          bvid ??= IdUtils.av2bv(aid!);
          PiliScheme.videoPush(aid, bvid, showDialog: false);
        }
      }
    }
  }
}

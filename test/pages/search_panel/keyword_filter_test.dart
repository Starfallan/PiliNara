import 'dart:io';

import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/models/search/search_esports.dart';
import 'package:PiliPlus/models_new/match/match_info/contest.dart';
import 'package:PiliPlus/models_new/match/match_info/season.dart';
import 'package:PiliPlus/models_new/match/match_info/team.dart';
import 'package:PiliPlus/pages/search_panel/all/controller.dart';
import 'package:PiliPlus/pages/search_panel/all/view.dart';
import 'package:PiliPlus/pages/search_panel/all/widgets/activity.dart';
import 'package:PiliPlus/pages/search_panel/all/widgets/esports.dart';
import 'package:PiliPlus/pages/search_panel/all/widgets/user.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/pages/search_panel/pgc/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/video/controller.dart';
import 'package:PiliPlus/pages/search_panel/video/view.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

class _SearchController extends SearchAllController {
  _SearchController({super.searchType = SearchType.all})
    : super(keyword: 'filter-test', tag: 'test');

  final responses = <LoadingState<SearchVideoData>>[];
  bool loadMoreEnabled = false;
  int requests = 0;

  @override
  Future<LoadingState<SearchVideoData>> customGetData() async {
    requests++;
    return responses.removeAt(0);
  }

  @override
  Future<void> onLoadMore() async {
    if (loadMoreEnabled) await super.onLoadMore();
  }

  void seed(SearchVideoData data) {
    responses.add(Success(data));
  }
}

class _PagingController
    extends SearchPanelController<SearchVideoData, SearchVideoItemModel> {
  _PagingController({required super.searchType})
    : super(keyword: 'filter-test', tag: 'paging');

  final responses = <SearchVideoData>[];
  int requests = 0;

  @override
  Future<LoadingState<SearchVideoData>> customGetData() async {
    requests++;
    return Success(responses.removeAt(0));
  }
}

SearchVideoItemModel _video(String title, [int aid = 1]) =>
    SearchVideoItemModel.fromJson({
      'aid': aid,
      'title': title,
      'mid': 100,
      'author': '作者',
      'duration': '01:00',
      'pubdate': 1700000000,
    });

SearchActivity _activity(String title) => SearchActivity(
  title: title,
  url: 'https://live.bilibili.com/1',
);

SearchUser _user(String name, {List<SearchVideoItemModel>? videos}) => SearchUser(
  mid: 100,
  uname: name,
  level: 1,
  res: videos,
);

SearchPgcItemModel _pgc(String title) => SearchPgcItemModel.fromJson({
  'title': title,
  'season_type_name': '番剧',
});

MatchContest _contest(String title) => MatchContest(
  id: 1,
  season: MatchSeason(title: title),
  homeTeam: MatchTeam(title: '主队'),
  awayTeam: MatchTeam(title: '客队'),
  liveRoom: 1,
);

SearchVideoData _mixedData() => SearchVideoData(
  numResults: 100,
  list: [_video('保留视频'), _video('排除视频', 2)],
)
  ..searchActivity = [_activity('保留活动'), _activity('排除活动')]
  ..searchUser = [_user('保留用户'), _user('排除用户')]
  ..searchMedia = [_pgc('保留番剧'), _pgc('排除番剧')]
  ..searchEsports = SearchEsports(contest: [_contest('保留赛事')]);

Future<void> _pumpPanel(WidgetTester tester, _SearchController controller) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final isAll = controller.searchType == SearchType.all;
  if (isAll) {
    Get.put<SearchAllController>(controller, tag: 'alltest');
  } else {
    Get.put<SearchVideoController>(controller, tag: 'videotest');
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: isAll
            ? const SearchAllPanel(
                keyword: 'filter-test', searchType: SearchType.all, tag: 'test',
              )
            : const SearchVideoPanel(
                keyword: 'filter-test', searchType: SearchType.video, tag: 'test',
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<SearchVideoItemModel> _visibleVideos(WidgetTester tester) => tester
    .widgetList<VideoCardH>(find.byType(VideoCardH))
    .map((card) => card.videoItem as SearchVideoItemModel)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('piliplus-search-test-');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.localCache = await Hive.openBox('localCache');
  });

  late bool previousTestMode;
  late Map<int, String> previousRemarks;

  setUp(() {
    previousTestMode = Get.testMode;
    previousRemarks = GlobalData().remarkMids;
    GlobalData().remarkMids = {};
    Get.testMode = true;
  });

  tearDown(() {
    GlobalData().remarkMids = previousRemarks;
    Get
      ..reset()
      ..testMode = previousTestMode;
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('关键词沿用正则 OR、忽略大小写、排除优先和 null 放行', () {
    final controller = _SearchController();
    addTearDown(controller.onClose);
    final titles = <String?>['CAT', 'dog 2', 'cat ad', 'fish', null];
    expect(controller.filterKeywords(titles, (title) => title), same(titles));
    controller.includeKeywords.addAll(['cat', r'^dog \d$']);
    controller.excludeKeywords.add('ad');
    expect(
      controller.filterKeywords(titles, (title) => title),
      ['CAT', 'dog 2', null],
    );
    expect(titles, ['CAT', 'dog 2', 'cat ad', 'fish', null]);
  });

  testWidgets('各顶层类型过滤，原始结果不变，清空词条恢复', (tester) async {
    final data = _mixedData();
    final controller = _SearchController()..seed(data);
    controller.includeKeywords.add('保留');
    controller.excludeKeywords.add('排除');
    await _pumpPanel(tester, controller);

    expect(controller.requests, 1);
    expect(controller.page, 2);
    expect(controller.isEnd, isFalse);
    expect(controller.pubBeginDate.day, 1);
    expect(controller.pubEndDate.isAfter(controller.pubBeginDate), isTrue);
    expect(_visibleVideos(tester), [data.list!.first]);
    expect(find.byType(SearchActivityItem), findsOneWidget);
    expect(find.byType(SearchAllUserItem), findsOneWidget);
    expect(find.byType(SearchPgcItem), findsOneWidget);
    expect(find.byType(SearchEsportsItem), findsOneWidget);
    expect(data.list, hasLength(2));
    expect(data.searchActivity, hasLength(2));
    expect(data.searchUser, hasLength(2));
    expect(data.searchMedia, hasLength(2));

    controller.includeKeywords.clear();
    controller.excludeKeywords.clear();
    await tester.pumpAndSettle();
    expect(_visibleVideos(tester), data.list);
    expect(find.byType(SearchActivityItem), findsNWidgets(2));
    expect(find.byType(SearchAllUserItem), findsNWidgets(2));
    expect(find.byType(SearchPgcItem), findsNWidgets(2));
    expect(find.text('继续加载'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final videos in <List<SearchVideoItemModel>?>[null, []]) {
    testWidgets('原始视频为 $videos 时仍显示非视频分区', (tester) async {
      final data = _mixedData()..list = videos;
      final controller = _SearchController()..seed(data);
      await _pumpPanel(tester, controller);
      expect(find.byType(SearchActivityItem), findsNWidgets(2));
      expect(find.byType(SearchAllUserItem), findsNWidgets(2));
      expect(find.byType(SearchPgcItem), findsNWidgets(2));
      expect(find.byType(SearchEsportsItem), findsOneWidget);
      expect(find.byType(HttpError), findsNothing);
      expect(find.text('继续加载'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('视频全部过滤时保留其他分区和视频分页入口', (tester) async {
    final data = _mixedData();
    final controller = _SearchController()..seed(data);
    controller.excludeKeywords.add('视频');
    await _pumpPanel(tester, controller);
    expect(find.byType(VideoCardH), findsNothing);
    expect(find.byType(SearchAllUserItem), findsNWidgets(2));
    expect(find.text('当前页结果已被关键词过滤'), findsNothing);
    expect(find.text('继续加载'), findsOneWidget);
  });

  testWidgets('全部类型过滤为空，仍可清除关键词恢复', (tester) async {
    final controller = _SearchController()..seed(_mixedData());
    controller.includeKeywords.add('不匹配');
    await _pumpPanel(tester, controller);
    expect(find.text('当前页结果已被关键词过滤'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
    expect(find.text('继续加载'), findsOneWidget);

    controller.includeKeywords.clear();
    await tester.pumpAndSettle();
    expect(find.byType(SearchEsportsItem), findsOneWidget);
    expect(find.byType(VideoCardH), findsNWidgets(2));
  });

  testWidgets('仅非视频结果也能响应过滤与清除', (tester) async {
    final controller = _SearchController()
      ..seed(SearchVideoData()..searchActivity = [_activity('活动')]);
    await _pumpPanel(tester, controller);
    controller.excludeKeywords.add('活动');
    await tester.pumpAndSettle();
    expect(find.byType(SearchActivityItem), findsNothing);
    expect(find.text('当前页结果已被关键词过滤'), findsOneWidget);
    expect(find.text('没有更多结果，请调整或清除关键词'), findsOneWidget);
    expect(find.text('继续加载'), findsNothing);
    controller.excludeKeywords.clear();
    await tester.pumpAndSettle();
    expect(find.byType(SearchActivityItem), findsOneWidget);
  });

  testWidgets('PGC 跨高亮片段和已解码实体匹配', (tester) async {
    final media = _pgc('猫<em class="keyword">咪</em>&amp;狗');
    final controller = _SearchController()
      ..seed(SearchVideoData()..searchMedia = [media]);
    controller.includeKeywords.add(r'^猫咪&狗$');
    await _pumpPanel(tester, controller);
    expect(find.byType(SearchPgcItem), findsOneWidget);
    controller.excludeKeywords.add('咪&狗');
    await tester.pumpAndSettle();
    expect(find.byType(SearchPgcItem), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('UP 匹配原昵称，不过滤卡片内附带视频', (tester) async {
    final nested = _video('排除视频');
    final user = _user('原昵称', videos: [nested]);
    GlobalData().remarkMids[100] = '本地备注';
    final controller = _SearchController()
      ..seed(SearchVideoData()..searchUser = [user]);
    controller.includeKeywords.add('原昵称');
    controller.excludeKeywords.add('排除');
    await _pumpPanel(tester, controller);
    expect(find.byType(SearchAllUserItem), findsOneWidget);
    expect(find.text('排除视频'), findsOneWidget);
    expect(user.res, [nested]);

    controller.includeKeywords.assignAll(['本地备注']);
    await tester.pumpAndSettle();
    expect(find.byType(SearchAllUserItem), findsNothing);
  });

  testWidgets('赛事仅按原第一场过滤，不改选第二场', (tester) async {
    final esports = SearchEsports(
      contest: [_contest('排除赛事'), _contest('保留赛事')],
    );
    final controller = _SearchController()
      ..seed(SearchVideoData()..searchEsports = esports);
    controller.includeKeywords.add('保留');
    await _pumpPanel(tester, controller);
    expect(find.byType(SearchEsportsItem), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(esports.contest, hasLength(2));

    controller.includeKeywords.clear();
    await tester.pumpAndSettle();
    expect(find.text('排除赛事'), findsOneWidget);
    expect(find.text('保留赛事'), findsNothing);
  });

  testWidgets('空赛事和空分区不生成占位或分隔线', (tester) async {
    final controller = _SearchController()
      ..seed(
        SearchVideoData()
          ..searchEsports = SearchEsports(contest: [])
          ..searchMedia = [],
      );
    await _pumpPanel(tester, controller);
    expect(find.byType(HttpError), findsOneWidget);
    expect(find.byType(SearchEsportsItem), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final type in [SearchType.all, SearchType.video]) {
    testWidgets('$type 过滤后删除实际条目而非原始下标', (tester) async {
      final first = _video('隐藏', 1);
      final second = _video('保留 B', 2);
      final third = _video('保留 C', 3);
      final controller = _SearchController(searchType: type)
        ..seed(SearchVideoData(list: [first, second, third]));
      controller.includeKeywords.add('保留');
      await _pumpPanel(tester, controller);
      expect(_visibleVideos(tester), [second, third]);
      tester.widget<VideoCardH>(find.byType(VideoCardH).first).onRemove!();
      await tester.pumpAndSettle();
      expect(controller.loadingState.value.data, [first, third]);
      expect(_visibleVideos(tester), [third]);
    });
  }

  testWidgets('视频分页保留首屏分区，空尾页通知收起加载入口', (tester) async {
    final activity = _activity('保留活动');
    final controller = _SearchController()
      ..seed(
        SearchVideoData(list: [_video('隐藏视频')])
          ..searchActivity = [activity],
      );
    controller.includeKeywords.add('保留');
    await _pumpPanel(tester, controller);
    expect(find.text('继续加载'), findsOneWidget);
    final nextVideo = _video('保留视频', 2);
    controller.responses.add(Success(SearchVideoData(list: [nextVideo])));
    await controller.queryData(false);
    await tester.pumpAndSettle();
    expect(controller.searchActivity, [activity]);
    expect(_visibleVideos(tester), [nextVideo]);
    expect(controller.page, 3);

    controller.responses.add(Success(SearchVideoData(list: [])));
    await controller.queryData(false);
    await tester.pumpAndSettle();
    expect(controller.isEnd, isTrue);
    expect(controller.page, 3);
    expect(find.text('继续加载'), findsNothing);
    expect(find.byType(SearchActivityItem), findsOneWidget);
    expect(_visibleVideos(tester), [nextVideo]);
    expect(controller.requests, 3);
  });

  for (final type in SearchType.values) {
    test('$type 公共分页未启用关键词时也通知空尾页，不丢数据或重复请求', () async {
      final video = _video('视频');
      final controller = _PagingController(searchType: type);
      addTearDown(controller.onClose);
      controller.responses.addAll([
        SearchVideoData(list: [video]), SearchVideoData(list: []),
      ]);
      await controller.queryData();
      final endStates = <bool>[];
      final subscription = controller.loadingState.listen((_) {
        endStates.add(controller.isEnd);
      });
      addTearDown(subscription.cancel);
      await controller.onLoadMore();
      expect(controller.hasKeywordFilter, isFalse);
      expect(endStates, [true]);
      expect(controller.loadingState.value.data, [video]);
      expect(controller.page, 2);
      await controller.onLoadMore();
      expect(controller.requests, 2);
      expect(endStates, [true]);
    });
  }

  testWidgets('推荐流过滤和关键词叠加，清空关键词不复活推荐屏蔽项', (tester) async {
    final previousApply = RecommendFilter.applyFilterToSearch;
    final previousEnabled = RecommendFilter.enableFilter;
    final previousRegex = RecommendFilter.rcmdRegExp;
    addTearDown(() {
      RecommendFilter.applyFilterToSearch = previousApply;
      RecommendFilter.enableFilter = previousEnabled;
      RecommendFilter.rcmdRegExp = previousRegex;
    });
    RecommendFilter.applyFilterToSearch = true;
    RecommendFilter.enableFilter = true;
    RecommendFilter.rcmdRegExp = RegExp('推荐屏蔽');
    final blocked = _video('保留 推荐屏蔽', 1);
    final shown = _video('保留', 2);
    final keywordHidden = _video('关键词隐藏', 3);
    final data = SearchVideoData(list: [blocked, shown, keywordHidden]);
    final controller = _SearchController()..seed(data);
    controller.includeKeywords.add('保留');
    await _pumpPanel(tester, controller);
    expect(_visibleVideos(tester), [shown]);
    expect(controller.loadingState.value.data, [shown, keywordHidden]);
    controller.includeKeywords.clear();
    await tester.pumpAndSettle();
    expect(_visibleVideos(tester), [shown, keywordHidden]);
  });

  testWidgets('PGC 位于末尾时保留原卡片底边，过滤卡片时同时移除底边', (tester) async {
    final controller = _SearchController()
      ..seed(SearchVideoData()..searchMedia = [_pgc('番剧')]);
    await _pumpPanel(tester, controller);
    expect(find.byType(SearchPgcItem), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    controller.excludeKeywords.add('番剧');
    await tester.pumpAndSettle();
    expect(find.byType(SearchPgcItem), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('过滤空态手动加载到末页后更新提示', (tester) async {
    final controller = _SearchController()
      ..seed(SearchVideoData(list: [_video('隐藏视频')]))
      ..loadMoreEnabled = true;
    controller.includeKeywords.add('不匹配');
    controller.responses.add(Success(SearchVideoData(list: [])));
    await _pumpPanel(tester, controller);
    await tester.tap(find.text('继续加载'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.requests, 2);
    expect(find.text('继续加载'), findsNothing);
    expect(find.text('没有更多结果，请调整或清除关键词'), findsOneWidget);
  });
}

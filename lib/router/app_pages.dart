import 'package:PiliPlus/common/widgets/video_card/video_hero.dart';
import 'package:PiliPlus/pages/about/view.dart';
import 'package:PiliPlus/pages/setting/ai_setting/view.dart';
import 'package:PiliPlus/pages/article/view.dart';
import 'package:PiliPlus/pages/article_list/view.dart';
import 'package:PiliPlus/pages/audio/view.dart';
import 'package:PiliPlus/pages/blacklist/view.dart';
import 'package:PiliPlus/pages/bubble/view.dart';
import 'package:PiliPlus/pages/danmaku_block/view.dart';
import 'package:PiliPlus/pages/dlna/view.dart';
import 'package:PiliPlus/pages/download/view.dart';
import 'package:PiliPlus/pages/dynamics/view.dart';
import 'package:PiliPlus/pages/dynamics_create_vote/view.dart';
import 'package:PiliPlus/pages/dynamics_detail/view.dart';
import 'package:PiliPlus/pages/dynamics_topic/view.dart';
import 'package:PiliPlus/pages/dynamics_topic_rcmd/view.dart';
import 'package:PiliPlus/pages/fan/view.dart';
import 'package:PiliPlus/pages/fav/view.dart';
import 'package:PiliPlus/pages/fav_create/view.dart';
import 'package:PiliPlus/pages/fav_detail/view.dart';
import 'package:PiliPlus/pages/fav_search/view.dart';
import 'package:PiliPlus/pages/follow/view.dart';
import 'package:PiliPlus/pages/follow_search/view.dart';
import 'package:PiliPlus/pages/follow_type/follow_same/view.dart';
import 'package:PiliPlus/pages/follow_type/followed/view.dart';
import 'package:PiliPlus/pages/history/view.dart';
import 'package:PiliPlus/pages/history_search/view.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/hot/view.dart';
import 'package:PiliPlus/pages/later/view.dart';
import 'package:PiliPlus/pages/later_search/view.dart';
import 'package:PiliPlus/pages/live_dm_block/view.dart';
import 'package:PiliPlus/pages/live_room/view.dart';
import 'package:PiliPlus/pages/login/view.dart';
import 'package:PiliPlus/pages/main/view.dart';
import 'package:PiliPlus/pages/main_reply/view.dart';
import 'package:PiliPlus/pages/match_info/view.dart';
import 'package:PiliPlus/pages/member/view.dart';
import 'package:PiliPlus/pages/member_dynamics/view.dart';
import 'package:PiliPlus/pages/member_guard/view.dart';
import 'package:PiliPlus/pages/member_profile/view.dart';
import 'package:PiliPlus/pages/member_search/view.dart';
import 'package:PiliPlus/pages/member_upower_rank/view.dart';
import 'package:PiliPlus/pages/member_video_web/archive/view.dart';
import 'package:PiliPlus/pages/member_video_web/season_series/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/at_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/like_detail/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/like_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/reply_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/sys_msg/view.dart';
import 'package:PiliPlus/pages/music/view.dart';
import 'package:PiliPlus/pages/my_reply/view.dart';
import 'package:PiliPlus/pages/popular_precious/view.dart';
import 'package:PiliPlus/pages/popular_series/view.dart';
import 'package:PiliPlus/pages/search/view.dart';
import 'package:PiliPlus/pages/search_result/view.dart';
import 'package:PiliPlus/pages/search_trending/view.dart';
import 'package:PiliPlus/pages/setting/pages/bar_set.dart';
import 'package:PiliPlus/pages/setting/pages/color_select.dart';
import 'package:PiliPlus/pages/setting/pages/display_mode.dart';
import 'package:PiliPlus/pages/setting/pages/font_setting.dart';
import 'package:PiliPlus/pages/setting/pages/logs.dart';
import 'package:PiliPlus/pages/setting/pages/play_speed_set.dart';
import 'package:PiliPlus/pages/setting/view.dart';
import 'package:PiliPlus/pages/settings_search/view.dart';
import 'package:PiliPlus/pages/space_setting/view.dart';
import 'package:PiliPlus/pages/sponsor_block/view.dart';
import 'package:PiliPlus/pages/subscription/view.dart';
import 'package:PiliPlus/pages/subscription_detail/view.dart';
import 'package:PiliPlus/pages/video/view.dart';
import 'package:PiliPlus/pages/webdav/view.dart';
import 'package:PiliPlus/pages/webview/view.dart';
import 'package:PiliPlus/pages/whisper/view.dart';
import 'package:PiliPlus/pages/whisper_detail/view.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:get/get.dart';

class _VideoDetailPageRoute<T> extends GetPageRoute<T> {
  _VideoDetailPageRoute({
    required GetPageBuilder page,
    required RouteSettings settings,
    Map<String, String>? parameter,
    bool maintainState = true,
    Bindings? binding,
    List<Bindings>? bindings,
    String? routeName,
    List<GetMiddleware>? middlewares,
  }) : super(
         page: page,
         settings: settings,
         parameter: parameter,
         maintainState: maintainState,
         binding: binding,
         bindings: bindings,
         routeName: routeName,
         middlewares: middlewares,
       );

  @override
  Duration get transitionDuration => VideoSpatialTransition.duration;

  @override
  Duration get reverseTransitionDuration => VideoSpatialTransition.duration;

  // Let the source page remain visible underneath the spatial flight. An
  // opaque route hides the originating card and turns the transition into a
  // page replacement, which is especially noticeable on iOS/iPad.
  @override
  bool get opaque =>
      !VideoSpatialTransition.enabled ||
      !VideoSpatialTransition.hasSourceTag(settings.arguments);

  // A route snapshot can freeze the player texture during the flight. Keep
  // the live route tree available so Hero and the poster crossfade remain
  // deterministic on iOS/iPad as well as Android.
  @override
  bool get allowSnapshotting =>
      !VideoSpatialTransition.enabled ||
      !VideoSpatialTransition.hasSourceTag(settings.arguments);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!VideoSpatialTransition.enabled ||
        !VideoSpatialTransition.hasSourceTag(settings.arguments)) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    final spatialTransition = VideoSpatialTransition.routeTransition(
      route: this,
      animation: animation,
      hasSource: true,
      child: child,
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Keep Flutter's public Cupertino back-gesture detector mounted from
      // the first frame. Constant animations neutralize its page slide and
      // shadow; the spatial transition above still follows the real route
      // controller during the gesture.
      return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
        this,
        context,
        kAlwaysCompleteAnimation,
        kAlwaysDismissedAnimation,
        spatialTransition,
      );
    }

    // Android predictive back updates the route controller directly, so the
    // same spatial transition remains interactive without a competing page
    // translation from the platform builder.
    return spatialTransition;
  }
}

class _VideoDetailGetPage extends GetPage<dynamic> {
  _VideoDetailGetPage()
    : super(name: '/videoV', page: () => const VideoDetailPageV());

  @override
  Route<dynamic> createRoute(BuildContext context) {
    return _VideoDetailPageRoute<dynamic>(
      page: page,
      settings: this,
      parameter: parameters,
      maintainState: maintainState,
      binding: binding,
      bindings: bindings,
      routeName: name,
      middlewares: middlewares,
    );
  }
}

class Routes {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final path = Uri.tryParse(settings.name ?? '')?.path;
    if (path == '/videoV') {
      final videoPage = getPages.singleWhere((page) => page.name == path);
      return _VideoDetailPageRoute<dynamic>(
        page: videoPage.page,
        settings: settings,
        parameter: videoPage.parameters,
        maintainState: videoPage.maintainState,
        binding: videoPage.binding,
        bindings: videoPage.bindings,
        routeName: videoPage.name,
        middlewares: videoPage.middlewares,
      );
    }

    // All other routes retain GetX's route-tree matching and middleware
    // behavior. The app registers [getPages] in GetMaterialApp.onInit.
    return PageRedirect(settings: settings).page();
  }

  static final List<GetPage<dynamic>> getPages = [
    GetPage(name: '/', page: () => const MainApp()),
    // 首页(推荐)
    GetPage(name: '/home', page: () => const HomePage()),
    // 热门
    GetPage(name: '/hot', page: () => const HotPage()),
    // 视频详情
    _VideoDetailGetPage(),
    //
    GetPage(name: '/webview', page: () => const WebviewPage()),
    // 设置
    GetPage(name: '/setting', page: () => const SettingPage()),
    //
    GetPage(name: '/fav', page: () => const FavPage()),
    //
    GetPage(name: '/favDetail', page: () => const FavDetailPage()),
    // 稍后再看
    GetPage(name: '/later', page: () => const LaterPage()),
    // 历史记录
    GetPage(name: '/history', page: () => const HistoryPage()),
    // 搜索页面
    GetPage(name: '/search', page: () => const SearchPage()),
    // 搜索结果
    GetPage(name: '/searchResult', page: () => const SearchResultPage()),
    // 动态
    GetPage(name: '/dynamics', page: () => const DynamicsPage()),
    // 动态详情
    GetPage(name: '/dynamicDetail', page: () => const DynamicDetailPage()),
    // 关注
    GetPage(name: '/follow', page: () => const FollowPage()),
    // 粉丝
    GetPage(name: '/fan', page: () => const FansPage()),
    // 直播详情
    GetPage(name: '/liveRoom', page: () => const LiveRoomPage()),
    // 用户中心
    GetPage(name: '/member', page: () => const MemberPage()),
    GetPage(name: '/memberSearch', page: () => const MemberSearchPage()),
    //
    GetPage(name: '/blackListPage', page: () => const BlackListPage()),
    GetPage(name: '/colorSetting', page: () => const ColorSelectPage()),
    GetPage(name: '/fontSetting', page: () => const FontSettingPage()),
    // 屏幕帧率
    GetPage(name: '/displayModeSetting', page: () => const SetDisplayMode()),
    // 关于
    GetPage(name: '/about', page: () => const AboutPage()),
    GetPage(name: '/articlePage', page: () => const ArticlePage()),

    // 历史记录搜索
    GetPage(name: '/playSpeedSet', page: () => const PlaySpeedPage()),
    // 收藏搜索
    GetPage(name: '/favSearch', page: () => const FavSearchPage()),
    GetPage(name: '/historySearch', page: () => const HistorySearchPage()),
    GetPage(name: '/laterSearch', page: () => const LaterSearchPage()),
    GetPage(name: '/followSearch', page: () => const FollowSearchPage()),
    // 消息页面
    GetPage(name: '/whisper', page: () => const WhisperPage()),
    // 私信详情
    GetPage(name: '/whisperDetail', page: () => const WhisperDetailPage()),
    // 回复我的
    GetPage(name: '/replyMe', page: () => const ReplyMePage()),
    // @我的
    GetPage(name: '/atMe', page: () => const AtMePage()),
    // 收到的赞
    GetPage(name: '/likeMe', page: () => const LikeMePage()),
    // 系统消息
    GetPage(name: '/sysMsg', page: () => const SysMsgPage()),
    // 登录页面
    GetPage(name: '/loginPage', page: () => const LoginPage()),
    // 用户动态
    GetPage(name: '/memberDynamics', page: () => const MemberDynamicsPage()),
    // 日志
    GetPage(name: '/logs', page: () => const LogsPage()),
    // 订阅
    GetPage(name: '/subscription', page: () => const SubPage()),
    // 订阅详情
    GetPage(name: '/subDetail', page: () => const SubDetailPage()),
    // 弹幕屏蔽管理
    GetPage(name: '/danmakuBlock', page: () => const DanmakuBlockPage()),
    GetPage(name: '/sponsorBlock', page: () => const SponsorBlockPage()),
    GetPage(name: '/aiSetting', page: () => const AiSettingPage()),
    GetPage(name: '/createFav', page: () => const CreateFavPage()),
    GetPage(name: '/editProfile', page: () => const EditProfilePage()),
    GetPage(name: '/settingsSearch', page: () => const SettingsSearchPage()),
    GetPage(name: '/webdavSetting', page: () => const WebDavSettingPage()),
    GetPage(name: '/searchTrending', page: () => const SearchTrendingPage()),
    GetPage(name: '/dynTopic', page: () => const DynTopicPage()),
    GetPage(name: '/articleList', page: () => const ArticleListPage()),
    GetPage(name: '/barSetting', page: () => const BarSetPage()),
    GetPage(name: '/upowerRank', page: () => const UpowerRankPage()),
    GetPage(name: '/spaceSetting', page: () => const SpaceSettingPage()),
    GetPage(name: '/dynTopicRcmd', page: () => const DynTopicRcmdPage()),
    GetPage(name: '/matchInfo', page: () => const MatchInfoPage()),
    GetPage(name: '/msgLikeDetail', page: () => const LikeDetailPage()),
    GetPage(name: '/liveDmBlockPage', page: () => const LiveDmBlockPage()),
    GetPage(name: '/createVote', page: () => const CreateVotePage()),
    GetPage(name: '/musicDetail', page: () => const MusicDetailPage()),
    GetPage(name: '/popularSeries', page: () => const PopularSeriesPage()),
    GetPage(name: '/popularPrecious', page: () => const PopularPreciousPage()),
    GetPage(name: '/audio', page: () => const AudioPage()),
    GetPage(name: '/mainReply', page: () => const MainReplyPage()),
    GetPage(name: '/followed', page: () => const FollowedPage()),
    GetPage(name: '/sameFollowing', page: () => const FollowSamePage()),
    GetPage(name: '/download', page: () => const DownloadPage()),
    GetPage(name: '/dlna', page: () => const DLNAPage()),
    GetPage(name: '/myReply', page: () => const MyReply()),
    GetPage(name: '/videoWeb', page: () => const MemberVideoWeb()),
    GetPage(name: '/ssWeb', page: () => const MemberSSWeb()),
    GetPage(name: '/memberGuard', page: () => const MemberGuard()),
    GetPage(name: '/bubble', page: () => const BubblePage()),
  ];
}

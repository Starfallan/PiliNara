import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models_new/member_card_info/data.dart';
import 'package:PiliPlus/models_new/relation/data.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/model_result.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models_new/video/video_detail/section.dart';
import 'package:PiliPlus/models_new/video/video_detail/staff.dart';
import 'package:PiliPlus/models_new/video/video_detail/stat_detail.dart';
import 'package:PiliPlus/models_new/video/video_detail/ugc_season.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/dynamics_repost/view.dart';
import 'package:PiliPlus/pages/video/related/controller.dart';
import 'package:PiliPlus/pages/video/reply/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:PiliPlus/utils/share_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class UgcIntroController extends CommonIntroController with ReloadMixin {
  late ExpandableController expandableCtr;

  final RxBool status = true.obs;

  // up主粉丝数
  final Rx<MemberCardInfoData> userStat = MemberCardInfoData().obs;
  // 关注状态 默认未关注
  late final Rx<RelationData> followStatus = Rx(RelationData());
  late final RxMap staffRelations = {}.obs;

  // 是否正在进入应用内小窗
  bool isEnteringPip = false;

  // 是否点踩
  final RxBool hasDislike = false.obs;

  late final showArgueMsg = Pref.showArgueMsg;
  late final enableAi = Pref.enableAi;
  late final horizontalMemberPage = Pref.horizontalMemberPage;

  AiConclusionResult? aiConclusionResult;

  late final Map<int?, bool> seasonFavState = {};

  @override
  void onInit() {
    super.onInit();
    bool alwaysExpandIntroPanel = Pref.alwaysExpandIntroPanel;
    expandableCtr = ExpandableController(
      initialExpanded: alwaysExpandIntroPanel,
    );
    if (!alwaysExpandIntroPanel && Pref.expandIntroPanelH) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!expandableCtr.expanded && !DeviceUtils.size.isPortrait) {
          expandableCtr.toggle();
        }
      });
    }

    videoDetail.value.title = Get.arguments['title'] ?? '';
  }

  // 获取视频简介&分p
  @override
  Future<void> queryVideoIntro() async {
    queryVideoTags();
    final res = await VideoHttp.videoIntro(bvid: bvid);
    if (res case Success(:final response)) {
      if (response.redirectUrl != null &&
          videoDetailCtr.epId == null &&
          videoDetailCtr.seasonId == null) {
        if (!isClosed) {
          PageUtils.viewPgcFromUri(response.redirectUrl!, off: true);
        }
        return;
      }
      videoPlayerServiceHandler?.onVideoDetailChange(
        response,
        cid.value,
        heroTag,
      );
      if (videoDetail.value.ugcSeason?.id == response.ugcSeason?.id) {
        // keep reversed season
        response.ugcSeason = videoDetail.value.ugcSeason;
      }
      if (videoDetail.value.cid == response.cid) {
        // keep reversed pages
        response
          ..pages = videoDetail.value.pages
          ..listOrder = videoDetail.value.listOrder;
      }
      videoDetail.value = response;
      try {
        if (videoDetailCtr.cover.value.isEmpty ||
            (videoDetailCtr.videoUrl.isNullOrEmpty &&
                !videoDetailCtr.isQuerying)) {
          videoDetailCtr.cover.value = response.pic ?? '';
        }
        if (videoDetailCtr.showReply) {
          try {
            Get.find<VideoReplyController>(tag: heroTag).count.value =
                response.stat?.reply ?? 0;
          } catch (_) {}
        }
      } catch (_) {}
      final pages = videoDetail.value.pages;
      if (pages != null && pages.isNotEmpty && cid.value == 0) {
        cid.value = pages.first.cid!;
      }
      queryUserStat(response.staff);
    } else {
      res.toast();
      status.value = false;
    }

    if (isLogin) {
      queryAllStatus();
      queryFollowStatus();
    }
  }

  // 获取up主粉丝数
  Future<void> queryUserStat(List<Staff>? staff) async {
    if (staff != null && staff.isNotEmpty) {
      final res = await Request().get(
        Api.relations,
        queryParameters: {'fids': staff.map((item) => item.mid).join(',')},
      );
      if (res.data['code'] == 0) {
        staffRelations.addAll({'status': true, ...?res.data['data']});
      }
    } else {
      final mid = videoDetail.value.owner?.mid;
      if (mid == null) {
        return;
      }
      final res = await MemberHttp.memberCardInfo(mid: mid);
      if (res case Success(:final response)) {
        userStat.value = response;
      }
    }
  }

  Future<void> queryAllStatus() async {
    final result = await VideoHttp.videoRelation(bvid: bvid);
    if (result case Success(:final response)) {
      late final stat = videoDetail.value.stat;
      if (response.like!) {
        stat?.like = max(1, stat.like);
      }
      if (response.favorite!) {
        stat?.favorite = max(1, stat.favorite);
      }
      hasLike.value = response.like!;
      hasDislike.value = response.dislike!;
      coinNum.value = response.coin!;
      hasFav.value = response.favorite!;
    }
  }

  // 一键三连
  @override
  Future<void> actionTriple() async {
    feedBack();
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    if (hasLike.value && hasCoin && hasFav.value) {
      // 已点赞、投币、收藏
      SmartDialog.showToast('已三连');
      return;
    }
    final result = await VideoHttp.ugcTriple(bvid: bvid);
    if (result case Success(:final response)) {
      late final stat = videoDetail.value.stat;
      if (response.like == true && !hasLike.value) {
        stat?.like++;
        hasLike.value = true;
      }
      if (response.coin == true && !hasCoin) {
        stat?.coin += 2;
        coinNum.value = 2;
        GlobalData().afterCoin(2);
      }
      if (response.fav == true && !hasFav.value) {
        stat?.favorite++;
        hasFav.value = true;
      }
      hasDislike.value = false;
      if (!hasCoin) {
        SmartDialog.showToast('投币失败');
      } else {
        SmartDialog.showToast('三连成功');
      }
    } else {
      result.toast();
    }
  }

  // （取消）点赞
  @override
  Future<void> actionLikeVideo() async {
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    if (videoDetail.value.stat == null) {
      return;
    }
    final newVal = !hasLike.value;
    final result = await VideoHttp.likeVideo(bvid: bvid, type: newVal);
    if (result case Success(:final response)) {
      SmartDialog.showToast(newVal ? response : '取消赞');
      videoDetail.value.stat?.like += newVal ? 1 : -1;
      hasLike.value = newVal;
      if (newVal) {
        hasDislike.value = false;
      }
    } else {
      result.toast();
    }
  }

  Future<void> actionDislikeVideo() async {
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    final res = await VideoHttp.dislikeVideo(
      bvid: bvid,
      type: !hasDislike.value,
    );
    if (res.isSuccess) {
      if (!hasDislike.value) {
        SmartDialog.showToast('点踩成功');
        hasDislike.value = true;
        if (hasLike.value) {
          videoDetail.value.stat?.like--;
          hasLike.value = false;
        }
      } else {
        SmartDialog.showToast('取消踩');
        hasDislike.value = false;
      }
    } else {
      res.toast();
    }
  }

  @override
  int get copyright => videoDetail.value.copyright ?? 1;

  @override
  (Object, int) get getFavRidType => (IdUtils.bv2av(bvid), 2);

  @override
  StatDetail? getStat() => videoDetail.value.stat;

  // 分享视频
  @override
  void actionShareVideo(BuildContext context) {
    final videoDetail = this.videoDetail.value;
    final playedTimePos = videoDetailCtr.playedTimePos;
    String videoUrl = '${HttpString.baseUrl}/video/$bvid';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: const Text(
                '复制链接',
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                Get.back();
                Utils.copyText(videoUrl);
              },
              trailing: playedTimePos.isNotEmpty
                  ? iconButton(
                      tooltip: '精确分享',
                      icon: const Icon(Icons.timer_outlined),
                      onPressed: () {
                        Get.back();
                        Utils.copyText('$videoUrl$playedTimePos');
                      },
                    )
                  : null,
            ),
            ListTile(
              dense: true,
              title: const Text(
                '其它app打开',
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                Get.back();
                PageUtils.launchURL(videoUrl);
              },
            ),
            if (PlatformUtils.isMobile)
              ListTile(
                dense: true,
                title: const Text(
                  '分享视频',
                  style: TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Get.back();
                  ShareUtils.shareText(
                    '${videoDetail.title} '
                    'UP主: ${videoDetail.owner!.name!}'
                    ' - $videoUrl',
                  );
                },
              ),
            ListTile(
              dense: true,
              title: const Text(
                '分享至动态',
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                Get.back();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => RepostPanel(
                    rid: videoDetail.aid,
                    dynType: 8,
                    pic: videoDetail.pic,
                    title: videoDetail.title,
                    uname: videoDetail.owner?.name,
                  ),
                );
              },
            ),
            ListTile(
              dense: true,
              title: const Text(
                '分享至消息',
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                Get.back();
                try {
                  PageUtils.pmShare(
                    context,
                    content: {
                      "id": videoDetail.aid!.toString(),
                      "title": videoDetail.title!,
                      "headline": videoDetail.title!,
                      "source": 5,
                      "thumb": videoDetail.pic!,
                      "author": videoDetail.owner!.name!,
                      "author_id": videoDetail.owner!.mid!.toString(),
                    },
                  );
                } catch (e) {
                  SmartDialog.showToast(e.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 查询关注状态
  Future<void> queryFollowStatus() async {
    final videoDetail = this.videoDetail.value;
    if (videoDetail.owner == null || videoDetail.staff?.isNotEmpty == true) {
      return;
    }
    final res = await UserHttp.userRelation(videoDetail.owner!.mid!);
    if (res case Success(:final response)) {
      if (response.special == 1) response.attribute = -10;
      followStatus.value = response;
    }
  }

  // 关注/取关up
  Future<void> actionRelationMod(BuildContext context) async {
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    final videoDetail = this.videoDetail.value;
    if (videoDetail.staff?.isNotEmpty == true) {
      return;
    }
    int? mid = videoDetail.owner?.mid;
    if (mid == null) {
      return;
    }
    int attr = followStatus.value.attribute ?? 0;
    if (attr == 128) {
      final res = await VideoHttp.relationMod(
        mid: mid,
        act: 6,
        reSrc: 11,
      );
      if (res.isSuccess) {
        followStatus
          ..value.attribute = 0
          ..refresh();
      }
      return;
    } else {
      RequestUtils.actionRelationMod(
        context: context,
        mid: mid,
        isFollow: attr != 0,
        followStatus: followStatus.value,
        afterMod: (attribute) {
          followStatus
            ..value.attribute = attribute
            ..refresh();
          Future.delayed(const Duration(milliseconds: 500), queryFollowStatus);
        },
      );
    }
  }

  // 修改分P或番剧分集
  Future<bool> onChangeEpisode(
    BaseEpisodeItem episode, {
    bool isStein = false,
  }) async {
    try {
      final String bvid = episode.bvid ?? this.bvid;
      final int aid = episode.aid ?? IdUtils.bv2av(bvid);
      int? cid = episode.cid;
      Dimension? dimension;
      if (cid == null) {
        if (await SearchHttp.ab2cWithDimension(aid: aid, bvid: bvid)
            case final res?) {
          cid = res.cid;
          dimension = res.dimension;
        }
      }
      if (cid == null) {
        return false;
      }

      final String? cover = episode.cover;

      // 重新获取视频资源
      if (videoDetailCtr.isPlayAll) {
        if (videoDetailCtr.mediaList.indexWhere((item) => item.bvid == bvid) ==
            -1) {
          if (dimension == null && episode is EpisodeItem) {
            dimension = episode.page?.dimension;
          }
          PageUtils.toVideoPage(
            bvid: bvid,
            cid: cid,
            cover: cover,
            dimension: dimension,
          );
          return false;
        }
      }

      videoDetailCtr
        ..plPlayerController.pause()
        ..makeHeartBeat()
        ..updateMediaListHistory(aid)
        ..onReset(isStein: isStein)
        ..bvid = bvid
        ..aid = aid
        ..cid.value = cid
        ..queryVideoUrl();

      if (kDebugMode) {
        debugPrint('[PROGRESS_LOAD] UgcIntroController - switched to bvid: $bvid, cid: $cid');
      }

      if (this.bvid != bvid) {
        reload = true;
        aiConclusionResult = null;

        if (cover != null && cover.isNotEmpty) {
          videoDetailCtr.cover.value = cover;
        }

        // 重新请求相关视频
        if (videoDetailCtr.plPlayerController.showRelatedVideo) {
          try {
            Get.find<RelatedController>(tag: heroTag)
              ..bvid = bvid
              ..queryData();
          } catch (_) {}
        }

        // 重新请求评论
        if (videoDetailCtr.showReply) {
          try {
            final replyCtr = Get.find<VideoReplyController>(tag: heroTag)
              ..aid = aid;
            if (replyCtr.loadingState.value is! Loading) {
              replyCtr.onReload();
            }
          } catch (_) {}
        }

        hasLater.value = videoDetailCtr.sourceType == SourceType.watchLater;
        this.bvid = bvid;
        queryVideoIntro();
      } else {
        if (episode is Part) {
          final videoDetail = this.videoDetail.value;
          videoPlayerServiceHandler?.onVideoDetailChange(
            episode,
            cid,
            heroTag,
            artist: videoDetail.owner?.name,
            cover: videoDetail.pic,
          );
        }
      }

      this.cid.value = cid;
      queryOnlineTotal();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('ugc onChangeEpisode: $e');
      return false;
    }
  }

  @override
  void onClose() {
    if (kDebugMode) {
      logger.i(
        '[UgcIntroController] onClose() called, isEnteringPip: $isEnteringPip',
      );
    }
    if (isEnteringPip) return;
    expandableCtr.dispose();
    super.onClose();
  }

  bool _isShuffleMode(bool isPart) {
    final videoDetail = this.videoDetail.value;
    if (isPart) return videoDetail.listOrder.isShuffle;
    if (videoDetailCtr.isPlayAll) return videoDetailCtr.listOrder.isShuffle;
    if (videoDetail.ugcSeason != null) {
      return videoDetail
          .ugcSeason!
          .sections![videoDetailCtr.seasonIndex.value]
          .listOrder
          .isShuffle;
    }
    return false;
  }

  /// 播放上一个
  @override
  bool prevPlay([bool skipPart = false]) {
    logger.d('[UgcIntroController] prevPlay 被调用，skipPart: $skipPart, heroTag: $heroTag');
    final List<BaseEpisodeItem> episodes = <BaseEpisodeItem>[];
    bool isPart = false;

    final videoDetail = this.videoDetail.value;
    logger.d('[UgcIntroController] videoDetail.pages?.length: ${videoDetail.pages?.length}, isPlayAll: ${videoDetailCtr.isPlayAll}, ugcSeason: ${videoDetail.ugcSeason != null}');

    if (!skipPart && (videoDetail.pages?.length ?? 0) > 1) {
      isPart = true;
      episodes.addAll(videoDetail.pages!);
      logger.d('[UgcIntroController] 使用 pages，episodes.length: ${episodes.length}');
    } else if (videoDetailCtr.isPlayAll) {
      episodes.addAll(videoDetailCtr.mediaList);
      logger.d('[UgcIntroController] 使用 playAll mediaList，episodes.length: ${episodes.length}');
    } else if (videoDetail.ugcSeason != null) {
      final UgcSeason ugcSeason = videoDetail.ugcSeason!;
      final List<SectionItem> sections = ugcSeason.sections!;
      for (int i = 0; i < sections.length; i++) {
        final List<EpisodeItem> episodesList = sections[i].episodes!;
        episodes.addAll(episodesList);
      }
      logger.d('[UgcIntroController] 使用 ugcSeason，episodes.length: ${episodes.length}');
    }

    final int currentIndex = episodes.indexWhere(
      (e) =>
          e.cid ==
          (skipPart
              ? videoDetail.listOrder.isDesc
                    ? videoDetail.pages!.last.cid
                    : videoDetail.pages!.first.cid
              : this.cid.value),
    );
    logger.d('[UgcIntroController] 当前 cid: ${this.cid.value}, currentIndex: $currentIndex');

    int prevIndex = currentIndex - 1;
    final PlayRepeat playRepeat = videoDetailCtr.plPlayerController.playRepeat;
    logger.d('[UgcIntroController] prevIndex: $prevIndex, playRepeat: $playRepeat');

    // 列表循环
    if (prevIndex < 0) {
      logger.d('[UgcIntroController] prevIndex < 0，检查是否需要切换模式或循环');
      if (isPart &&
          (videoDetailCtr.isPlayAll || videoDetail.ugcSeason != null)) {
        logger.d('[UgcIntroController] isPart 且有其他播放源，递归调用 prevPlay(true)');
        return prevPlay(true);
      }
      if (_isShuffleMode(isPart)) {
        logger.d('[UgcIntroController] 处于随机播放模式，返回 false');
        return false;
      }
      if (playRepeat == PlayRepeat.listCycle) {
        prevIndex = episodes.length - 1;
        logger.d('[UgcIntroController] 列表循环，跳到最后一个: $prevIndex');
      } else {
        logger.d('[UgcIntroController] 没有上一集且不循环，返回 false');
        return false;
      }
    }

    int? cid = episodes[prevIndex].cid;
    while (cid == null) {
      prevIndex--;
      if (prevIndex < 0) {
        logger.w('[UgcIntroController] 找不到有效的 cid，返回 false');
        return false;
      }
      cid = episodes[prevIndex].cid;
    }

    logger.d('[UgcIntroController] 目标 cid: $cid, 当前 cid: ${this.cid.value}');
    if (cid != this.cid.value) {
      logger.i('[UgcIntroController] 切换到上一集，返回 true');
      onChangeEpisode(episodes[prevIndex]);
      return true;
    } else {
      logger.w('[UgcIntroController] 目标 cid 与当前相同，返回 false');
      return false;
    }
  }

  /// 列表循环或者顺序播放时，自动播放下一个
  @override
  bool nextPlay([bool skipPart = false]) {
    try {
      logger.d('[UgcIntroController] nextPlay 被调用，skipPart: $skipPart, heroTag: $heroTag');
      final List<BaseEpisodeItem> episodes = <BaseEpisodeItem>[];
      bool isPart = false;
      final videoDetail = this.videoDetail.value;
      logger.d('[UgcIntroController] videoDetail.pages?.length: ${videoDetail.pages?.length}, isPlayAll: ${videoDetailCtr.isPlayAll}, ugcSeason: ${videoDetail.ugcSeason != null}');

      // part -> playall -> season
      if (!skipPart && (videoDetail.pages?.length ?? 0) > 1) {
        isPart = true;
        final List<Part> pages = videoDetail.pages!;
        episodes.addAll(pages);
        logger.d('[UgcIntroController] 使用 pages，episodes.length: ${episodes.length}');
      } else if (videoDetailCtr.isPlayAll) {
        episodes.addAll(videoDetailCtr.mediaList);
        logger.d('[UgcIntroController] 使用 playAll mediaList，episodes.length: ${episodes.length}');
      } else if (videoDetail.ugcSeason != null) {
        final UgcSeason ugcSeason = videoDetail.ugcSeason!;
        final List<SectionItem> sections = ugcSeason.sections!;
        for (int i = 0; i < sections.length; i++) {
          final List<EpisodeItem> episodesList = sections[i].episodes!;
          episodes.addAll(episodesList);
        }
        logger.d('[UgcIntroController] 使用 ugcSeason，episodes.length: ${episodes.length}');
      }

      final PlayRepeat playRepeat =
          videoDetailCtr.plPlayerController.playRepeat;
      logger.d('[UgcIntroController] playRepeat: $playRepeat');

      if (episodes.isEmpty) {
        logger.d('[UgcIntroController] episodes 为空');
        if (playRepeat == PlayRepeat.listCycle) {
          logger.d('[UgcIntroController] 列表循环模式，重播当前视频');
          videoDetailCtr.plPlayerController.play(repeat: true);
          return true;
        }
        if (playRepeat == PlayRepeat.autoPlayRelated &&
            videoDetailCtr.plPlayerController.showRelatedVideo) {
          logger.d('[UgcIntroController] 自动播放相关视频');
          return playRelated();
        }
        logger.d('[UgcIntroController] episodes 为空且无其他播放源，返回 false');
        return false;
      }

      final int currentIndex = episodes.indexWhere(
        (e) =>
            e.cid ==
            (skipPart
                ? videoDetail.listOrder.isDesc
                      ? videoDetail.pages!.last.cid
                      : videoDetail.pages!.first.cid
                : this.cid.value),
      );
      logger.d('[UgcIntroController] 当前 cid: ${this.cid.value}, currentIndex: $currentIndex');

      int nextIndex = currentIndex + 1;
      logger.d('[UgcIntroController] nextIndex: $nextIndex, episodes.length: ${episodes.length}');

      if (!isPart &&
          videoDetailCtr.isPlayAll &&
          currentIndex == episodes.length - 2) {
        logger.d('[UgcIntroController] 接近播放列表末尾，加载更多');
        videoDetailCtr.getMediaList();
      }

      // 列表循环
      if (nextIndex >= episodes.length) {
        logger.d('[UgcIntroController] nextIndex >= episodes.length，检查是否需要切换模式或循环');
        if (isPart &&
            (videoDetailCtr.isPlayAll || videoDetail.ugcSeason != null)) {
          logger.d('[UgcIntroController] isPart 且有其他播放源，递归调用 nextPlay(true)');
          return nextPlay(true);
        }

        if (_isShuffleMode(isPart)) {
          logger.d('[UgcIntroController] 处于随机播放模式，返回 false');
          return false;
        }
        if (playRepeat == PlayRepeat.listCycle) {
          nextIndex = 0;
          logger.d('[UgcIntroController] 列表循环，跳到第一个');
        } else if (playRepeat == PlayRepeat.autoPlayRelated &&
            videoDetailCtr.plPlayerController.showRelatedVideo) {
          logger.d('[UgcIntroController] 自动播放相关视频');
          return playRelated();
        } else {
          logger.d('[UgcIntroController] 没有下一集且不循环，返回 false');
          return false;
        }
      }

      int? cid = episodes[nextIndex].cid;
      while (cid == null) {
        nextIndex++;
        if (nextIndex >= episodes.length) {
          logger.w('[UgcIntroController] 找不到有效的 cid，返回 false');
          return false;
        }
        cid = episodes[nextIndex].cid;
      }

      logger.d('[UgcIntroController] 目标 cid: $cid, 当前 cid: ${this.cid.value}');
      if (cid != this.cid.value) {
        logger.i('[UgcIntroController] 切换到下一集，返回 true');
        onChangeEpisode(episodes[nextIndex]);
        return true;
      } else {
        logger.w('[UgcIntroController] 目标 cid 与当前相同，返回 false');
        return false;
      }
    } catch (e) {
      logger.e('[UgcIntroController] nextPlay 异常: $e');
      return false;
    }
  }

  bool playRelated() {
    RelatedController relatedCtr;
    if (Get.isRegistered<RelatedController>(tag: heroTag)) {
      relatedCtr = Get.find<RelatedController>(tag: heroTag);
    } else {
      relatedCtr = Get.put(RelatedController(autoQuery: false), tag: heroTag)
        ..queryData().whenComplete(playRelated);
      return false;
    }

    if (relatedCtr.loadingState.value case Success(:final response)) {
      final firstItem = response?.firstOrNull;
      if (firstItem == null) {
        SmartDialog.showToast('暂无相关视频，停止连播');
        return false;
      }
      onChangeEpisode(
        BaseEpisodeItem(
          aid: firstItem.aid,
          bvid: firstItem.bvid,
          cid: firstItem.cid,
          cover: firstItem.cover,
        ),
      );
      return true;
    }

    return false;
  }

  // ai总结
  static Future<AiConclusionResult?> getAiConclusion(
    String bvid,
    int cid,
    int? mid,
  ) async {
    if (!Accounts.heartbeat.isLogin) {
      SmartDialog.showToast("账号未登录");
      return null;
    }
    SmartDialog.showLoading(msg: '正在获取AI总结');
    final res = await VideoHttp.aiConclusion(
      bvid: bvid,
      cid: cid,
      upMid: mid,
    );
    SmartDialog.dismiss();
    if (res case Success(:final response)) {
      return response.modelResult;
    } else if (res is Error && res.code == 1) {
      SmartDialog.showToast("AI处理中，请稍后再试");
    } else {
      SmartDialog.showToast("当前视频暂不支持AI视频总结");
    }
    return null;
  }

  Future<void> aiConclusion() async {
    aiConclusionResult = await getAiConclusion(
      bvid,
      cid.value,
      videoDetail.value.owner?.mid,
    );
  }
}

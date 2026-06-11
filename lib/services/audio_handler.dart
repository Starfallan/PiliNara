import 'dart:io' show File, Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:get/get.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/local/controller.dart';
import 'package:PiliPlus/pages/audio/controller.dart';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/grpc/bilibili/app/listener/v1.pb.dart' show DetailItem;
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/data.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

Future<VideoPlayerServiceHandler> initAudioService() {
  return AudioService.init(
    builder: VideoPlayerServiceHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.pilinara.audio',
      androidNotificationChannelName: 'Audio Service ${Constants.appName}',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      androidNotificationChannelDescription: 'Media notification channel',
      androidNotificationIcon: 'drawable/ic_notification_icon',
    ),
  );
}

class VideoPlayerServiceHandler extends BaseAudioHandler with SeekHandler {
  static final List<MediaItem> _item = [];
  bool enableBackgroundPlay = Pref.enableBackgroundPlay;

  Future<void>? Function()? onPlay;
  Future<void>? Function()? onPause;
  Future<void>? Function(Duration position)? onSeek;
  Future<void>? Function()? onSkipToNext;
  Future<void>? Function()? onSkipToPrevious;
  String? currentHeroTag;

  @override
  Future<void> skipToNext() async {
    logger.d('[AudioHandler] skipToNext 被调用');
    if (onSkipToNext != null) {
      logger.d('[AudioHandler] 使用 onSkipToNext 回调');
      await onSkipToNext?.call();
      return;
    }
    if (currentHeroTag == null) {
      logger.w('[AudioHandler] currentHeroTag 为 null，无法切换');
      return;
    }
    logger.d('[AudioHandler] currentHeroTag: $currentHeroTag');
    // 直接尝试 find，不检查 isRegistered
    try {
      final ctr = Get.find<UgcIntroController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 UgcIntroController');
      final result = ctr.nextPlay();
      logger.d('[AudioHandler] UgcIntroController.nextPlay() 返回: $result');
      if (result) {
        logger.i('[AudioHandler] 切换成功');
        return;
      } else {
        logger.w('[AudioHandler] UgcIntroController.nextPlay() 返回 false，继续尝试其他 Controller');
      }
    } catch (e) {
      logger.d('[AudioHandler] 未找到 UgcIntroController: $e');
    }
    try {
      final ctr = Get.find<PgcIntroController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 PgcIntroController');
      final result = ctr.nextPlay();
      logger.d('[AudioHandler] PgcIntroController.nextPlay() 返回: $result');
      if (result) {
        logger.i('[AudioHandler] 切换成功');
        return;
      } else {
        logger.w('[AudioHandler] PgcIntroController.nextPlay() 返回 false，继续尝试其他 Controller');
      }
    } catch (e) {
      logger.d('[AudioHandler] 未找到 PgcIntroController: $e');
    }
    try {
      final ctr = Get.find<LocalIntroController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 LocalIntroController');
      final result = ctr.nextPlay();
      logger.d('[AudioHandler] LocalIntroController.nextPlay() 返回: $result');
      if (result) {
        logger.i('[AudioHandler] 切换成功');
        return;
      } else {
        logger.w('[AudioHandler] LocalIntroController.nextPlay() 返回 false，继续尝试其他 Controller');
      }
    } catch (e) {
      logger.d('[AudioHandler] 未找到 LocalIntroController: $e');
    }
    try {
      final ctr = Get.find<AudioController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 AudioController');
      ctr.playNext();
      logger.i('[AudioHandler] AudioController.playNext() 调用完成');
      return;
    } catch (e) {
      logger.d('[AudioHandler] 未找到 AudioController: $e');
    }
    logger.e('[AudioHandler] 所有 Controller 都未能成功切换下一集');
  }

  @override
  Future<void> skipToPrevious() async {
    logger.d('[AudioHandler] skipToPrevious 被调用');
    if (onSkipToPrevious != null) {
      logger.d('[AudioHandler] 使用 onSkipToPrevious 回调');
      await onSkipToPrevious?.call();
      return;
    }
    if (currentHeroTag == null) {
      logger.w('[AudioHandler] currentHeroTag 为 null，无法切换');
      return;
    }
    logger.d('[AudioHandler] currentHeroTag: $currentHeroTag');
    // 直接尝试 find，不检查 isRegistered
    try {
      final ctr = Get.find<UgcIntroController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 UgcIntroController');
      final result = ctr.prevPlay();
      logger.d('[AudioHandler] UgcIntroController.prevPlay() 返回: $result');
      if (result) {
        logger.i('[AudioHandler] 切换成功');
        return;
      } else {
        logger.w('[AudioHandler] UgcIntroController.prevPlay() 返回 false，继续尝试其他 Controller');
      }
    } catch (e) {
      logger.d('[AudioHandler] 未找到 UgcIntroController: $e');
    }
    try {
      final ctr = Get.find<PgcIntroController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 PgcIntroController');
      final result = ctr.prevPlay();
      logger.d('[AudioHandler] PgcIntroController.prevPlay() 返回: $result');
      if (result) {
        logger.i('[AudioHandler] 切换成功');
        return;
      } else {
        logger.w('[AudioHandler] PgcIntroController.prevPlay() 返回 false，继续尝试其他 Controller');
      }
    } catch (e) {
      logger.d('[AudioHandler] 未找到 PgcIntroController: $e');
    }
    try {
      final ctr = Get.find<LocalIntroController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 LocalIntroController');
      final result = ctr.prevPlay();
      logger.d('[AudioHandler] LocalIntroController.prevPlay() 返回: $result');
      if (result) {
        logger.i('[AudioHandler] 切换成功');
        return;
      } else {
        logger.w('[AudioHandler] LocalIntroController.prevPlay() 返回 false，继续尝试其他 Controller');
      }
    } catch (e) {
      logger.d('[AudioHandler] 未找到 LocalIntroController: $e');
    }
    try {
      final ctr = Get.find<AudioController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 AudioController');
      ctr.playPrev();
      logger.i('[AudioHandler] AudioController.playPrev() 调用完成');
      return;
    } catch (e) {
      logger.d('[AudioHandler] 未找到 AudioController: $e');
    }
    logger.e('[AudioHandler] 所有 Controller 都未能成功切换上一集');
  }

  @override
  Future<void> play() {
    return onPlay?.call() ??
        PlPlayerController.playIfExists() ??
        Future.syncValue(null);
    // player.play();
  }

  @override
  Future<void> pause() {
    return onPause?.call() ?? PlPlayerController.pauseIfExists();
    // player.pause();
  }

  @override
  Future<void> seek(Duration position) {
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
      ),
    );
    return (onSeek?.call(position) ??
        PlPlayerController.seekToIfExists(position, isSeek: false));
    // await player.seekTo(position);
  }

  void setMediaItem(MediaItem newMediaItem) {
    if (!enableBackgroundPlay) return;
    // if (kDebugMode) {
    //   debugPrint("此时调用栈为：");
    //   debugPrint(newMediaItem);
    //   debugPrint(newMediaItem.title);
    //   debugPrint(StackTrace.current.toString());
    // }
    if (!mediaItem.isClosed) mediaItem.add(newMediaItem);
  }

  bool _hasEpisodes() {
    logger.d('[AudioHandler] _hasEpisodes 被调用，currentHeroTag: $currentHeroTag');
    if (currentHeroTag == null) {
      logger.d('[AudioHandler] currentHeroTag 为 null，返回 false');
      return false;
    }
    try {
      final ctr = Get.find<UgcIntroController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 UgcIntroController');
      final videoDetail = ctr.videoDetail.value;
      final isSeason = videoDetail.ugcSeason != null;
      final isPart = videoDetail.pages != null && videoDetail.pages!.length > 1;
      final isPlayAll = ctr.videoDetailCtr.isPlayAll;
      logger.d('[AudioHandler] UgcIntroController 状态: isSeason=$isSeason, isPart=$isPart (pages=${videoDetail.pages?.length}), isPlayAll=$isPlayAll');
      final result = isSeason || isPart || isPlayAll;
      logger.d('[AudioHandler] _hasEpisodes 返回: $result');
      return result;
    } catch (e) {
      logger.d('[AudioHandler] 未找到 UgcIntroController: $e');
    }
    try {
      Get.find<PgcIntroController>(tag: currentHeroTag!);
      logger.d('[AudioHandler] 找到 PgcIntroController，返回 true');
      return true;
    } catch (e) {
      logger.d('[AudioHandler] 未找到 PgcIntroController: $e');
    }
    try {
      final ctr = Get.find<LocalIntroController>(tag: currentHeroTag!);
      final result = ctr.list.length > 1;
      logger.d('[AudioHandler] 找到 LocalIntroController，list.length=${ctr.list.length}，返回: $result');
      return result;
    } catch (e) {
      logger.d('[AudioHandler] 未找到 LocalIntroController: $e');
    }
    try {
      final ctr = Get.find<AudioController>(tag: currentHeroTag!);
      final result = ctr.playlist != null && ctr.playlist!.isNotEmpty;
      logger.d('[AudioHandler] 找到 AudioController，playlist=${ctr.playlist?.length ?? 0}，返回: $result');
      return result;
    } catch (e) {
      logger.d('[AudioHandler] 未找到 AudioController: $e');
    }
    logger.d('[AudioHandler] 所有 Controller 都未找到，返回 false');
    return false;
  }

  void setPlaybackState(
    PlayerStatus status,
    bool isBuffering,
    bool isLive,
  ) {
    logger.d('[AudioHandler] setPlaybackState 被调用: status.isPlaying=${status.isPlaying}, isBuffering=$isBuffering, isLive=$isLive');
    if (!enableBackgroundPlay ||
        _item.isEmpty ||
        !PlPlayerController.instanceExists()) {
      logger.d('[AudioHandler] setPlaybackState 跳过: enableBackgroundPlay=$enableBackgroundPlay, _item.isEmpty=${_item.isEmpty}, instanceExists=${PlPlayerController.instanceExists()}');
      return;
    }

    final AudioProcessingState processingState;
    if (status.isCompleted) {
      processingState = AudioProcessingState.completed;
    } else if (isBuffering) {
      processingState = AudioProcessingState.buffering;
    } else {
      processingState = AudioProcessingState.ready;
    }

    final playing = status.isPlaying;

    final hasEpisodes = _hasEpisodes();
    logger.d('[AudioHandler] hasEpisodes: $hasEpisodes，将${hasEpisodes ? "显示" : "隐藏"}上下集按钮');

    final controls = <MediaControl>[
      if (!isLive && hasEpisodes) MediaControl.skipToPrevious,
      MediaControl.rewind.copyWith(
        androidIcon: 'drawable/ic_player_rewind_10s',
      ),
      if (playing)
        MediaControl.pause.copyWith(
          androidIcon: 'drawable/ic_player_pause',
        )
      else
        MediaControl.play.copyWith(
          androidIcon: 'drawable/ic_player_play',
        ),
      MediaControl.fastForward.copyWith(
        androidIcon: 'drawable/ic_player_fast_forward_10s',
      ),
      if (!isLive && hasEpisodes) MediaControl.skipToNext,
    ];

    int playPauseIndex = controls.indexWhere(
      (c) => c.action == MediaAction.play || c.action == MediaAction.pause,
    );
    List<int> compactIndices;
    if (controls.length >= 3) {
      if (playPauseIndex > 0 && playPauseIndex < controls.length - 1) {
        compactIndices = [
          playPauseIndex - 1,
          playPauseIndex,
          playPauseIndex + 1,
        ];
      } else {
        compactIndices = [0, 1, 2];
      }
    } else {
      compactIndices = List.generate(controls.length, (i) => i);
    }

    playbackState.add(
      playbackState.value.copyWith(
        processingState: isBuffering
            ? AudioProcessingState.buffering
            : processingState,
        controls: controls,
        androidCompactActionIndices: compactIndices,
        playing: playing,
        systemActions: {
          MediaAction.seek,
          if (!isLive && hasEpisodes) MediaAction.skipToPrevious,
          MediaAction.rewind,
          MediaAction.fastForward,
          if (!isLive && hasEpisodes) MediaAction.skipToNext,
        },
      ),
    );
    if (Platform.isAndroid &&
        (AndroidHelper.isPipMode ||
            PlPlayerController.instance?.isAutoEnterPip == true)) {
      AndroidHelper.updatePipActions(
        PlatformDispatcher.instance.engineId!,
        isLive,
        playing,
      );
    }
  }

  void onStatusChange(PlayerStatus status, bool isBuffering, isLive) {
    if (!enableBackgroundPlay) return;

    if (_item.isEmpty) return;
    setPlaybackState(status, isBuffering, isLive);
  }

  void onVideoDetailChange(
    dynamic data,
    int cid,
    String herotag, {
    String? artist,
    String? cover,
  }) {
    if (!enableBackgroundPlay) return;
    currentHeroTag = herotag;
    // if (kDebugMode) {
    //   debugPrint('当前调用栈为：');
    //   debugPrint(StackTrace.current);
    // }
    if (!PlPlayerController.instanceExists()) return;
    if (data == null) return;

    Uri getUri(String? cover) => Uri.parse(ImageUtils.safeThumbnailUrl(cover));

    late final id = '$cid$herotag';
    final MediaItem mediaItem;
    switch (data) {
      case VideoDetailData(:final pages):
        if (pages != null && pages.length > 1) {
          final current = pages.firstWhereOrNull((e) => e.cid == cid);
          mediaItem = MediaItem(
            id: id,
            title: current?.part ?? '',
            artist: data.owner?.name,
            duration: Duration(seconds: current?.duration ?? 0),
            artUri: getUri(data.pic),
          );
        } else {
          mediaItem = MediaItem(
            id: id,
            title: data.title ?? '',
            artist: data.owner?.name,
            duration: Duration(seconds: data.duration ?? 0),
            artUri: getUri(data.pic),
          );
        }
      case EpisodeItem():
        mediaItem = MediaItem(
          id: id,
          title: data.showTitle ?? data.longTitle ?? data.title ?? '',
          artist: artist,
          duration: data.from == 'pugv'
              ? Duration(seconds: data.duration ?? 0)
              : Duration(milliseconds: data.duration ?? 0),
          artUri: getUri(data.cover),
        );
      case RoomInfoH5Data():
        mediaItem = MediaItem(
          id: id,
          title: data.roomInfo?.title ?? '',
          artist: data.anchorInfo?.baseInfo?.uname,
          artUri: getUri(data.roomInfo?.cover),
          isLive: true,
        );
      case Part():
        mediaItem = MediaItem(
          id: id,
          title: data.part ?? '',
          artist: artist,
          duration: Duration(seconds: data.duration ?? 0),
          artUri: getUri(cover),
        );
      case DetailItem(:final arc):
        mediaItem = MediaItem(
          id: id,
          title: arc.title,
          artist: data.owner.name,
          duration: Duration(seconds: arc.duration.toInt()),
          artUri: getUri(arc.cover),
        );
      case BiliDownloadEntryInfo():
        final coverFile = File(
          path.join(data.entryDirPath, PathUtils.coverName),
        );
        final uri = coverFile.existsSync()
            ? coverFile.absolute.uri
            : getUri(data.cover);
        mediaItem = MediaItem(
          id: id,
          title: data.showTitle,
          artist: data.ownerName,
          duration: Duration(milliseconds: data.totalTimeMilli),
          artUri: uri,
        );
      default:
        return;
    }
    // if (kDebugMode) debugPrint("exist: ${PlPlayerController.instanceExists()}");
    if (!PlPlayerController.instanceExists()) return;
    _item.add(mediaItem);
    setMediaItem(mediaItem);
  }

  void onVideoDetailDispose(String herotag) {
    if (!enableBackgroundPlay) return;

    if (_item.isNotEmpty) {
      _item.removeWhere((item) => item.id.endsWith(herotag));
    }
    if (_item.isNotEmpty) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      setMediaItem(_item.last);
      stop();
    }
  }

  void clear() {
    if (!enableBackgroundPlay) return;
    mediaItem.add(null);
    _item.clear();
    /**
     * if (playbackState.processingState == AudioProcessingState.idle &&
            previousState?.processingState != AudioProcessingState.idle) {
          await AudioService._stop();
        }
     */
    if (playbackState.value.processingState == AudioProcessingState.idle) {
      playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.completed,
          playing: false,
        ),
      );
    }
    playbackState.add(
      PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  void onPositionChange(Duration position) {
    if (!enableBackgroundPlay ||
        _item.isEmpty ||
        !PlPlayerController.instanceExists()) {
      return;
    }

    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
      ),
    );
  }
}

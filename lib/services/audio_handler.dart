import 'dart:io' show File, Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:get/get.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/local/controller.dart';
import 'package:PiliPlus/pages/audio/controller.dart';

import 'package:PiliPlus/common/constants.dart';
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

  void _clearCallbacks() {
    onPlay = null;
    onPause = null;
    onSeek = null;
    onSkipToNext = null;
    onSkipToPrevious = null;
  }

  void _emitIdleState() {
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

  void _clearCurrentSession({bool clearItems = true}) {
    if (!mediaItem.isClosed) {
      mediaItem.add(null);
    }
    if (clearItems) {
      _item.clear();
    }
    currentHeroTag = null;
    _clearCallbacks();
    _emitIdleState();
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      await onSkipToNext?.call();
      return;
    }
    if (currentHeroTag == null) return;
    // 优先匹配 AudioController（听视频模式）
    try {
      final ctr = Get.find<AudioController>(tag: currentHeroTag!);
      if (ctr.playNext()) return;
    } catch (_) {}
    // 直接尝试 find，不检查 isRegistered
    try {
      final ctr = Get.find<UgcIntroController>(tag: currentHeroTag!);
      if (ctr.nextPlay()) return;
    } catch (_) {}
    try {
      final ctr = Get.find<PgcIntroController>(tag: currentHeroTag!);
      if (ctr.nextPlay()) return;
    } catch (_) {}
    try {
      final ctr = Get.find<LocalIntroController>(tag: currentHeroTag!);
      if (ctr.nextPlay()) return;
    } catch (_) {}
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      await onSkipToPrevious?.call();
      return;
    }
    if (currentHeroTag == null) return;
    // 优先匹配 AudioController（听视频模式）
    try {
      final ctr = Get.find<AudioController>(tag: currentHeroTag!);
      if (ctr.playPrev()) return;
    } catch (_) {}
    // 直接尝试 find，不检查 isRegistered
    try {
      final ctr = Get.find<UgcIntroController>(tag: currentHeroTag!);
      if (ctr.prevPlay()) return;
    } catch (_) {}
    try {
      final ctr = Get.find<PgcIntroController>(tag: currentHeroTag!);
      if (ctr.prevPlay()) return;
    } catch (_) {}
    try {
      final ctr = Get.find<LocalIntroController>(tag: currentHeroTag!);
      if (ctr.prevPlay()) return;
    } catch (_) {}
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
    if (currentHeroTag == null) return false;
    // 优先匹配 AudioController（听视频模式）
    try {
      final ctr = Get.find<AudioController>(tag: currentHeroTag!);
      return ctr.playlist != null && ctr.playlist!.isNotEmpty;
    } catch (_) {}
    try {
      final ctr = Get.find<UgcIntroController>(tag: currentHeroTag!);
      final videoDetail = ctr.videoDetail.value;
      final isSeason = videoDetail.ugcSeason != null;
      final isPart = videoDetail.pages != null && videoDetail.pages!.length > 1;
      final isPlayAll = ctr.videoDetailCtr.isPlayAll;
      return isSeason || isPart || isPlayAll;
    } catch (_) {}
    try {
      Get.find<PgcIntroController>(tag: currentHeroTag!);
      return true;
    } catch (_) {}
    try {
      final ctr = Get.find<LocalIntroController>(tag: currentHeroTag!);
      return ctr.list.length > 1;
    } catch (_) {}
    return false;
  }

  void setPlaybackState(
    PlayerStatus status,
    bool isBuffering,
    bool isLive,
  ) {
    if (!enableBackgroundPlay ||
        _item.isEmpty ||
        !PlPlayerController.instanceExists()) {
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
    _item
      ..removeWhere((item) => item.id == id || item.id.endsWith(herotag))
      ..add(mediaItem);
    setMediaItem(mediaItem);
  }

  void onVideoDetailDispose(String herotag) {
    if (!enableBackgroundPlay) return;

    _item.removeWhere((item) => item.id.endsWith(herotag));
    if (currentHeroTag != herotag) {
      return;
    }
    _clearCurrentSession(clearItems: false);
  }

  void clear() {
    if (!enableBackgroundPlay) return;
    _clearCurrentSession();
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

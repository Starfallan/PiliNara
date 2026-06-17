import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/services/media_trace.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:audio_session/audio_session.dart';

class AudioSessionHandler {
  late AudioSession session;
  bool _playInterrupted = false;

  void _trace(
    String event, {
    Object? message,
    Map<String, Object?>? data,
  }) {
    mediaTrace(
      'AudioSession',
      event,
      message: message,
      data: {
        'playInterrupted': _playInterrupted,
        'playerStatus': PlPlayerController.getPlayerStatusIfExists()?.name,
        'hasPlayerInstance': PlPlayerController.instance != null,
        ...?data,
      },
    );
  }

  Future<bool> setActive(bool active) {
    return session.setActive(active);
  }

  AudioSessionHandler() {
    initSession();
  }

  Future<void> _configureSession() async {
    _trace(
      'configureSession',
      data: {
        'mixWithOthers': Pref.mixWithOthers,
        'isIOS': Platform.isIOS,
      },
    );
    if (Pref.mixWithOthers && Platform.isIOS) {
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        ),
      );
    } else {
      await session.configure(const AudioSessionConfiguration.music());
    }
  }

  Future<void> reconfigure() async {
    await session.setActive(false);
    await _configureSession();
  }

  Future<void> initSession() async {
    session = await AudioSession.instance;
    await _configureSession();
    _trace('initSession:ready');

    session.interruptionEventStream.listen((event) {
      final playerStatus = PlPlayerController.getPlayerStatusIfExists();
      _trace(
        'interruptionEvent',
        data: {
          'begin': event.begin,
          'type': event.type.name,
          'playerStatusBefore': playerStatus?.name,
        },
      );
      // final player = PlPlayerController.getInstance();
      if (event.begin) {
        if (playerStatus != PlayerStatus.playing) return;
        // if (!player.playerStatus.playing) return;
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.instance?.handleDuck(true);
            break;
          case AudioInterruptionType.pause:
            // 接收到其他 App 播放音频的通知，如果允许了同时播放，就无视
            if (Pref.mixWithOthers) return;
            PlPlayerController.pauseIfExists(isInterrupt: true);
            // player.pause(isInterrupt: true);
            _playInterrupted = true;
            break;
          case AudioInterruptionType.unknown:
            PlPlayerController.pauseIfExists(isInterrupt: true);
            // player.pause(isInterrupt: true);
            _playInterrupted = true;
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.instance?.handleDuck(false);
            break;
          case AudioInterruptionType.pause:
            if (_playInterrupted) PlPlayerController.playIfExists();
            //player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
        _playInterrupted = false;
        _trace(
          'interruptionEvent:end',
          data: {
            'type': event.type.name,
          },
        );
      }
    });

    // 耳机拔出暂停
    session.becomingNoisyEventStream.listen((_) {
      _trace('becomingNoisy');
      PlPlayerController.pauseIfExists();
      // final player = PlPlayerController.getInstance();
      // if (player.playerStatus.playing) {
      //   player.pause();
      // }
    });
  }
}

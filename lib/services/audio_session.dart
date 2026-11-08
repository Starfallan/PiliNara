import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:audio_session/audio_session.dart';

class AudioSessionHandler {
  late AudioSession _session;
  late final Future<void> _ready;
  void Function()? _resume;

  AudioSessionHandler() {
    _ready = initSession();
  }

  Future<bool> setActive(bool active) async {
    await _ready;
    return _session.setActive(active);
  }

  Future<void> _configureSession() async {
    if (Pref.mixWithOthers && Platform.isIOS) {
      await _session.configure(
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
      await _session.configure(const AudioSessionConfiguration.music());
    }
  }

  Future<void> reconfigure() async {
    await _ready;
    _resume = null;
    await _session.setActive(false);
    await _configureSession();
  }

  Future<void> initSession() async {
    _session = await AudioSession.instance;
    await _configureSession();
    _session.interruptionEventStream.listen(_onInterrupted);
    _session.becomingNoisyEventStream.listen((_) {
      _resume = null;
      final onPause = videoPlayerServiceHandler?.onPause;
      if (onPause != null) {
        onPause();
      } else {
        PlPlayerController.pauseIfExists();
      }
    });
  }

  void _onInterrupted(AudioInterruptionEvent event) {
    final handler = videoPlayerServiceHandler;
    final player = PlPlayerController.instance;
    if (event.type == AudioInterruptionType.duck) {
      if (handler?.isPlaying == null && player != null &&
          (!event.begin || player.playerStatus.isPlaying)) {
        player.handleDuck(event.begin);
      }
      return;
    }
    if (event.begin) {
      if (Pref.mixWithOthers &&
          (event.type == AudioInterruptionType.pause || Platform.isAndroid)) {
        return;
      }
      final isAudioPlaying = handler?.isPlaying;
      if (isAudioPlaying != null) {
        if (isAudioPlaying()) {
          final onPlay = handler!.onPlay;
          _resume = () {
            if (identical(videoPlayerServiceHandler?.onPlay, onPlay)) onPlay?.call();
          };
          handler.onPause?.call();
        }
      } else if (player != null && player.playerStatus.isPlaying) {
        final owner = PlPlayerController.playOwner;
        _resume = () {
          if (identical(PlPlayerController.instance, player) &&
              PlPlayerController.playOwner == owner &&
              videoPlayerServiceHandler?.isPlaying == null) {
            player.play();
          }
        };
        player.pause(isInterrupt: true);
      }
    } else {
      final resume = _resume;
      _resume = null;
      if (event.type == AudioInterruptionType.pause) resume?.call();
    }
  }
}

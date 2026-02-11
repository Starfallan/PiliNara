import 'package:get/get.dart';

enum PlayerStatus {
  completed,
  playing,
  paused
  ;

  bool get isCompleted => this == PlayerStatus.completed;
  bool get isPlaying => this == PlayerStatus.playing;
  bool get isPaused => this == PlayerStatus.paused;
}

typedef PlPlayerStatus = Rx<PlayerStatus>;

extension PlPlayerStatusExt on PlPlayerStatus {
  bool get isPlaying => value.isPlaying;
  bool get isPaused => value.isPaused;
  bool get isCompleted => value.isCompleted;
}

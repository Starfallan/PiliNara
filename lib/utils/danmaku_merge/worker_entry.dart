// Inspired by the existing danmaku merge pipeline.
// This file hosts the background isolate entry for merge tasks.

import 'dart:isolate';

import 'package:PiliPlus/utils/danmaku_merge/clusterer.dart';
import 'package:PiliPlus/utils/danmaku_merge/pinyin_encoder.dart';
import 'package:PiliPlus/utils/danmaku_merge/worker_models.dart';

@pragma('vm:entry-point')
void danmakuMergeWorkerMain(List<Object?> args) {
  final sendPort = args[0]! as SendPort;
  final dictContent = args[1]! as String;
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final pinyinEncoder = DanmakuPinyinEncoder.withDictionaryContent(dictContent);
  Future<void> queue = Future<void>.value();

  receivePort.listen((message) {
    queue = queue.then((_) async {
    if (message is! Map<Object?, Object?>) {
      return;
    }
    final type = message['type'];
    if (type == 'shutdown') {
      receivePort.close();
      Isolate.exit();
    }
    if (type != 'task') {
      return;
    }

    final task = DanmakuMergeTaskPayload.fromMessage(message);
    try {
      final clusterer = DanmakuClusterer(
        config: task.config,
        pinyinEncoder: pinyinEncoder,
      );
      final merged = await clusterer.mergeSegment(
        segmentIndex: task.segmentIndex,
        currentSegment: task.currentSegment
            .map(deserializeDanmakuElem)
            .toList(growable: false),
        nextSegmentPrefix: task.nextSegmentPrefix
            .map(deserializeDanmakuElem)
            .toList(growable: false),
      );
      sendPort.send(
        DanmakuMergeResultPayload(
          taskId: task.taskId,
          segmentIndex: task.segmentIndex,
          mergedSegment: merged
              .map(serializeDanmakuElem)
              .toList(growable: false),
        ).toMessage(),
      );
    } catch (error, stackTrace) {
      sendPort.send(
        DanmakuMergeErrorPayload(
          taskId: task.taskId,
          message: error.toString(),
          stackTrace: stackTrace.toString(),
        ).toMessage(),
      );
    }
    });
  });
}

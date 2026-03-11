// Inspired by the existing danmaku merge pipeline.
// This file defines isolate-safe request/response payloads.

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/utils/danmaku_merge/models.dart';
import 'package:fixnum/fixnum.dart';

class DanmakuMergeTaskPayload {
  const DanmakuMergeTaskPayload({
    required this.taskId,
    required this.segmentIndex,
    required this.config,
    required this.currentSegment,
    required this.nextSegmentPrefix,
  });

  final int taskId;
  final int segmentIndex;
  final DanmakuMergeConfig config;
  final List<Map<String, Object?>> currentSegment;
  final List<Map<String, Object?>> nextSegmentPrefix;

  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'type': 'task',
      'taskId': taskId,
      'segmentIndex': segmentIndex,
      'config': _configToMessage(config),
      'currentSegment': currentSegment,
      'nextSegmentPrefix': nextSegmentPrefix,
    };
  }

  static DanmakuMergeTaskPayload fromMessage(Map<Object?, Object?> message) {
    return DanmakuMergeTaskPayload(
      taskId: message['taskId']! as int,
      segmentIndex: message['segmentIndex']! as int,
      config: _configFromMessage(message['config']! as Map<Object?, Object?>),
      currentSegment: (message['currentSegment']! as List<Object?>)
          .cast<Map<Object?, Object?>>()
          .map(_normalizeElementMap)
          .toList(growable: false),
      nextSegmentPrefix: (message['nextSegmentPrefix']! as List<Object?>)
          .cast<Map<Object?, Object?>>()
          .map(_normalizeElementMap)
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _configToMessage(DanmakuMergeConfig config) {
    return <String, Object?>{
      'enabled': config.enabled,
      'windowMs': config.windowMs,
      'maxDistance': config.maxDistance,
      'maxCosine': config.maxCosine,
      'usePinyin': config.usePinyin,
      'crossMode': config.crossMode,
      'skipSubtitle': config.skipSubtitle,
      'skipAdvanced': config.skipAdvanced,
      'skipBottom': config.skipBottom,
    };
  }

  static DanmakuMergeConfig _configFromMessage(Map<Object?, Object?> message) {
    return DanmakuMergeConfig(
      enabled: message['enabled']! as bool,
      windowMs: message['windowMs']! as int,
      maxDistance: message['maxDistance']! as int,
      maxCosine: message['maxCosine']! as int,
      usePinyin: message['usePinyin']! as bool,
      crossMode: message['crossMode']! as bool,
      skipSubtitle: message['skipSubtitle']! as bool,
      skipAdvanced: message['skipAdvanced']! as bool,
      skipBottom: message['skipBottom']! as bool,
    );
  }
}

class DanmakuMergeResultPayload {
  const DanmakuMergeResultPayload({
    required this.taskId,
    required this.segmentIndex,
    required this.mergedSegment,
  });

  final int taskId;
  final int segmentIndex;
  final List<Map<String, Object?>> mergedSegment;

  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'type': 'result',
      'taskId': taskId,
      'segmentIndex': segmentIndex,
      'mergedSegment': mergedSegment,
    };
  }

  static DanmakuMergeResultPayload fromMessage(Map<Object?, Object?> message) {
    return DanmakuMergeResultPayload(
      taskId: message['taskId']! as int,
      segmentIndex: message['segmentIndex']! as int,
      mergedSegment: (message['mergedSegment']! as List<Object?>)
          .cast<Map<Object?, Object?>>()
          .map(_normalizeElementMap)
          .toList(growable: false),
    );
  }
}

class DanmakuMergeErrorPayload {
  const DanmakuMergeErrorPayload({
    required this.taskId,
    required this.message,
    required this.stackTrace,
  });

  final int taskId;
  final String message;
  final String stackTrace;

  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'type': 'error',
      'taskId': taskId,
      'message': message,
      'stackTrace': stackTrace,
    };
  }
}

Map<String, Object?> serializeDanmakuElem(DanmakuElem element) {
  return <String, Object?>{
    'id': element.id.toInt(),
    'progress': element.progress,
    'mode': element.mode,
    'fontsize': element.fontsize,
    'color': element.color,
    'midHash': element.midHash,
    'content': element.content,
    'ctime': element.ctime.toInt(),
    'weight': element.weight,
    'action': element.action,
    'pool': element.pool,
    'idStr': element.idStr,
    'attr': element.attr,
    'animation': element.animation,
    'colorful': element.colorful,
    'isSelf': element.isSelf,
    'count': element.count,
  };
}

DanmakuElem deserializeDanmakuElem(Map<Object?, Object?> message) {
  return DanmakuElem()
    ..id = Int64(message['id']! as int)
    ..progress = message['progress']! as int
    ..mode = message['mode']! as int
    ..fontsize = message['fontsize']! as int
    ..color = message['color']! as int
    ..midHash = message['midHash']! as String
    ..content = message['content']! as String
    ..ctime = Int64(message['ctime']! as int)
    ..weight = message['weight']! as int
    ..action = message['action']! as String
    ..pool = message['pool']! as int
    ..idStr = message['idStr']! as String
    ..attr = message['attr']! as int
    ..animation = message['animation']! as String
    ..colorful = DmColorfulType.valueOf(message['colorful']! as int) ??
        DmColorfulType.NoneType
    ..isSelf = message['isSelf']! as bool
    ..count = message['count']! as int;
}

Map<String, Object?> _normalizeElementMap(Map<Object?, Object?> message) {
  return <String, Object?>{
    for (final entry in message.entries) entry.key! as String: entry.value,
  };
}

// Inspired by the local danmaku merge pipeline.
// Quick manual debugger for sentence comparison and danmaku file merging.

import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/utils/danmaku_merge/clusterer.dart';
import 'package:PiliPlus/utils/danmaku_merge/models.dart';
import 'package:PiliPlus/utils/danmaku_merge/normalizer.dart';
import 'package:PiliPlus/utils/danmaku_merge/pinyin_encoder.dart';
import 'package:PiliPlus/utils/danmaku_merge/similarity_matcher.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exitCode = 1;
    return;
  }

  switch (args.first) {
    case 'compare':
      if (args.length < 3) {
        stderr.writeln('compare 需要两个句子');
        _printUsage();
        exitCode = 1;
        return;
      }
      await _compare(args[1], args[2]);
      return;
    case 'merge':
      if (args.length < 2) {
        stderr.writeln('merge 需要一个文件路径');
        _printUsage();
        exitCode = 1;
        return;
      }
      await _mergeFile(args[1]);
      return;
    default:
      stderr.writeln('未知命令: ${args.first}');
      _printUsage();
      exitCode = 1;
  }
}

Future<void> _compare(String left, String right) async {
  final config = _defaultConfig();
  final encoder = DanmakuPinyinEncoder.fromFileSystem();
  final matcher = DanmakuSimilarityMatcher(
    config: config,
    pinyinEncoder: encoder,
  );

  final leftNormalized = DanmakuNormalizer.normalize(left);
  final rightNormalized = DanmakuNormalizer.normalize(right);
  final leftTokens = leftNormalized.runes.toList(growable: false);
  final rightTokens = rightNormalized.runes.toList(growable: false);

  final result = await matcher.match(
    DanmakuMergeCandidate(
      element: _fakeElem(content: left, progress: 0),
      segmentIndex: 0,
      normalizedText: leftNormalized,
      charTokens: leftTokens,
      gramTokens: DanmakuSimilarityMatcher.buildGramTokens(leftNormalized),
    ),
    DanmakuMergeCandidate(
      element: _fakeElem(content: right, progress: 0),
      segmentIndex: 0,
      normalizedText: rightNormalized,
      charTokens: rightTokens,
      gramTokens: DanmakuSimilarityMatcher.buildGramTokens(rightNormalized),
    ),
  );

  final charDistance = matcher.charDistance(leftTokens, rightTokens);
  final pinyinDistance = await matcher.pinyinDistance(
    leftNormalized,
    rightNormalized,
  );
  final cosineSimilarity = matcher.cosineSimilarity(
    DanmakuSimilarityMatcher.buildGramTokens(leftNormalized),
    DanmakuSimilarityMatcher.buildGramTokens(rightNormalized),
  );

  final buffer = StringBuffer()
    ..writeln('left.raw       : $left')
    ..writeln('right.raw      : $right')
    ..writeln('left.normalized: $leftNormalized')
    ..writeln('right.normalized: $rightNormalized')
    ..writeln('charDistance   : $charDistance')
    ..writeln('pinyinDistance : $pinyinDistance')
    ..writeln('cosineSimilarity: $cosineSimilarity')
    ..writeln(
      'match          : ${result == null ? 'false' : 'true (${result.reason.name}, ${result.distance})'}',
    );
  stdout.write(buffer.toString());
}

Future<void> _mergeFile(String inputPath) async {
  final file = File(inputPath);
  if (!file.existsSync()) {
    stderr.writeln('文件不存在: $inputPath');
    exitCode = 1;
    return;
  }

  final elements = await _readElements(file);
  final clusterer = DanmakuClusterer(
    config: _defaultConfig(),
    pinyinEncoder: DanmakuPinyinEncoder.fromFileSystem(),
  );
  final merged = await clusterer.mergeSegment(
    segmentIndex: 0,
    currentSegment: elements,
    nextSegmentPrefix: const <DanmakuElem>[],
  );

  stdout
    ..writeln('input.count : ${elements.length}')
    ..writeln('merged.count: ${merged.length}')
    ..writeln();

  for (final element in merged) {
    stdout.writeln(
      '[${element.progress}ms] x${element.count > 0 ? element.count : 1} '
      'mode=${element.mode} pool=${element.pool} ${element.content}',
    );
  }
}

Future<List<DanmakuElem>> _readElements(File file) async {
  if (file.path.toLowerCase().endsWith('.pb')) {
    return DmSegMobileReply.fromBuffer(await file.readAsBytes()).elems;
  }

  if (file.path.toLowerCase().endsWith('.json')) {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException('JSON 顶层必须是数组');
    }
    return decoded
        .map((item) => _elemFromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  throw const FormatException('仅支持 .pb 或 .json 文件');
}

DanmakuElem _elemFromJson(Map<String, dynamic> json) {
  return _fakeElem(
    content: json['content'] as String? ?? '',
    progress: json['progress'] as int? ?? 0,
    mode: json['mode'] as int? ?? 1,
    pool: json['pool'] as int? ?? 0,
    weight: json['weight'] as int? ?? 10,
    color: json['color'] as int? ?? 0xFFFFFF,
    fontsize: json['fontsize'] as int? ?? 25,
    midHash: json['midHash'] as String? ?? '',
    isSelf: json['isSelf'] as bool? ?? false,
  );
}

DanmakuElem _fakeElem({
  required String content,
  required int progress,
  int mode = 1,
  int pool = 0,
  int weight = 10,
  int color = 0xFFFFFF,
  int fontsize = 25,
  String midHash = '',
  bool isSelf = false,
}) {
  return DanmakuElem()
    ..content = content
    ..progress = progress
    ..mode = mode
    ..pool = pool
    ..weight = weight
    ..color = color
    ..fontsize = fontsize
    ..midHash = midHash
    ..isSelf = isSelf;
}

DanmakuMergeConfig _defaultConfig() {
  return const DanmakuMergeConfig(
    enabled: true,
    windowMs: 20000,
    maxDistance: 5,
    maxCosine: 45,
    crossMode: false,
    skipSubtitle: true,
    skipAdvanced: true,
    skipBottom: false,
  );
}

void _printUsage() {
  stdout
    ..writeln('用法:')
    ..writeln(
      '  flutter pub run tool/danmaku_merge_debug.dart compare "句子A" "句子B"',
    )
    ..writeln(
      '  flutter pub run tool/danmaku_merge_debug.dart merge path/to/danmaku.pb',
    )
    ..writeln(
      '  flutter pub run tool/danmaku_merge_debug.dart merge path/to/danmaku.json',
    )
    ..writeln()
    ..writeln('JSON 文件格式示例:')
    ..writeln(
      '[{"progress":1000,"content":"23333","mode":1,"pool":0},{"progress":1200,"content":"233333","mode":1,"pool":0}]',
    );
}

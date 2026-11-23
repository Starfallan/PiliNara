import 'dart:io';

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/utils/danmaku_density_trend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File file;
  const durationMs = 120000;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pilinara_dm_trend_');
    file = File('${directory.path}/danmaku.pb');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<List<double>?> load({
    int duration = durationMs,
    bool Function()? shouldCancel,
  }) => DanmakuDensityTrend.buildFromFile(
    filePath: file.path,
    cid: 1,
    durationMs: duration,
    shouldCancel: shouldCancel,
  );

  test('cached protobuf produces the same density as the online raw list', () async {
    final elems = [
      DanmakuElem(progress: 0, content: '开始', mode: 1, fontsize: 25),
      DanmakuElem(progress: 10000, content: '高能😀', mode: 5, fontsize: 36),
      DanmakuElem(progress: 10500, content: '高能😀', mode: 1, fontsize: 25),
      DanmakuElem(progress: 80000, content: '尾声', mode: 4, fontsize: 25),
      DanmakuElem(progress: durationMs, content: '结束', mode: 1, fontsize: 25),
    ];
    await file.writeAsBytes(DmSegMobileReply(elems: elems).writeToBuffer());
    final expected = await DanmakuDensityTrend.build(
      cid: 1,
      durationMs: durationMs,
      elems: elems,
    );

    expect(expected, isNotNull);
    expect(expected!.any((value) => value > 0), isTrue);
    expect(await load(), expected);
  });

  test('missing, empty and corrupt files have no chart', () async {
    expect(await load(), isNull);
    await file.writeAsBytes([]);
    expect(await load(), isNull);
    await file.writeAsBytes([0xff]);
    expect(await load(), isNull);
  });

  test('empty or unusable protobuf data has no chart', () async {
    await file.writeAsBytes(DmSegMobileReply(state: 1).writeToBuffer());
    expect(await load(), isNull);
    await file.writeAsBytes(DmSegMobileReply(elems: [
      DanmakuElem(progress: 1000, content: '', mode: 1),
      DanmakuElem(progress: 1000, content: 'code', mode: 8),
      DanmakuElem(progress: 1000, content: 'BAS', mode: 9),
      DanmakuElem(progress: -1, content: 'before', mode: 1),
      DanmakuElem(progress: durationMs + 1, content: 'after', mode: 1),
    ]).writeToBuffer());
    expect(await load(), isNull);
  });

  test('invalid duration and cancelled requests have no chart', () async {
    await file.writeAsBytes(DmSegMobileReply(elems: [
      DanmakuElem(progress: 1000, content: '弹幕', mode: 1, fontsize: 25),
    ]).writeToBuffer());
    expect(await load(duration: 0), isNull);
    expect(await load(duration: -1), isNull);
    expect(await load(shouldCancel: () => true), isNull);

    var cancelled = false;
    final pending = load(shouldCancel: () => cancelled);
    cancelled = true;
    expect(await pending, isNull);
  });

  test('reopening reads updated danmaku instead of caching the old chart', () async {
    await file.writeAsBytes(DmSegMobileReply(elems: [
      DanmakuElem(progress: 10000, content: '弹幕', mode: 1, fontsize: 25),
    ]).writeToBuffer());
    final before = await load();
    await file.writeAsBytes(DmSegMobileReply(elems: [
      DanmakuElem(progress: 90000, content: '弹幕', mode: 1, fontsize: 25),
    ]).writeToBuffer());
    final after = await load();

    expect(before, isNotNull);
    expect(after, isNotNull);
    expect(after, isNot(equals(before)));
  });
}

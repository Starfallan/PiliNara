import 'dart:io';

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/models/user/danmaku_rule.dart';
import 'package:PiliPlus/models/user/danmaku_rule_adapter.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Count real matching calls without adding instrumentation to the playback path.
// ignore: deprecated_implement
class _CountingRegExp implements RegExp {
  final RegExp delegate;
  int calls = 0;

  _CountingRegExp(String pattern) : delegate = RegExp(pattern);

  @override
  bool hasMatch(String input) {
    calls++;
    return delegate.hasMatch(input);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// The pre-cache wire format: three string lists, with no field tags or count.
class _LegacyRuleFilterAdapter extends TypeAdapter<RuleFilter> {
  @override
  final int typeId = 12;

  @override
  RuleFilter read(BinaryReader reader) => RuleFilter(
    reader.readStringList(),
    reader.readStringList().map((s) => RegExp(s, caseSensitive: false)),
    reader.readStringList(),
  );

  @override
  void write(BinaryWriter writer, RuleFilter obj) {
    writer
      ..writeStringList(obj.dmFilterString.toList())
      ..writeStringList(obj.dmRegExp.map((r) => r.pattern).toList())
      ..writeStringList(obj.dmUid.toList());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('pilinara-rule-filter-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('matching and nonmatching objects are each evaluated once on replay', () {
    final regexp = _CountingRegExp('blocked');
    final filter = RuleFilter([], [regexp], []);
    final blocked = DanmakuElem(content: 'blocked', midHash: 'a');
    final allowed = DanmakuElem(content: 'allowed', midHash: 'a');
    for (var i = 0; i < 3; i++) {
      expect(filter.remove(blocked), isTrue);
      expect(filter.remove(allowed), isFalse);
    }
    expect(regexp.calls, 2);
    expect(filter.remove(DanmakuElem(content: 'allowed', midHash: 'a')), isFalse);
    expect(regexp.calls, 3);
  });

  test('identical text from different senders does not share a UID result', () {
    final filter = RuleFilter([], [], ['a']);
    expect(filter.remove(DanmakuElem(content: 'same', midHash: 'a')), isTrue);
    expect(filter.remove(DanmakuElem(content: 'same', midHash: 'b')), isFalse);
  });

  test('new UID invalidates old misses, duplicate UID keeps cached results', () {
    final regexp = _CountingRegExp('blocked');
    final filter = RuleFilter([], [regexp], []);
    final blocked = DanmakuElem(content: 'hello', midHash: 'a');
    final allowed = DanmakuElem(content: 'hello', midHash: 'b');
    expect(filter.remove(blocked), isFalse);
    expect(filter.remove(allowed), isFalse);
    expect(regexp.calls, 2);
    expect(filter.addUid('a'), isTrue);
    expect(filter.remove(blocked), isTrue);
    expect(filter.remove(allowed), isFalse);
    expect(regexp.calls, 3);
    expect(filter.addUid('a'), isFalse);
    expect(filter.remove(allowed), isFalse);
    expect(regexp.calls, 3);
    expect(filter.count, 2);
  });

  test('constructor aliases and public views cannot change active rules', () {
    final strings = ['original'];
    final regexps = [RegExp('regex')];
    final uids = {'a'};
    final filter = RuleFilter(strings, regexps, uids);
    strings.clear();
    regexps.clear();
    uids.clear();
    expect(filter.count, 3);
    expect(() => (filter.dmFilterString as List<String>).clear(), throwsUnsupportedError);
    expect(() => (filter.dmRegExp as List<RegExp>).clear(), throwsUnsupportedError);
    expect(() => (filter.dmUid as Set<String>).clear(), throwsUnsupportedError);
    final uidView = filter.dmUid;
    filter.addUid('b');
    expect(uidView, containsAll(['a', 'b']));
    expect(filter.remove(DanmakuElem(content: 'original')), isTrue);
  });

  test('empty rules can become active without carrying an old result', () {
    final filter = RuleFilter.empty();
    final elem = DanmakuElem(content: 'hello', midHash: 'a');
    expect(filter.isEmpty, isTrue);
    expect(filter.remove(elem), isFalse);
    filter.addUid('a');
    expect(filter.isEmpty, isFalse);
    expect(filter.remove(elem), isTrue);
  });

  test('rule comparison ignores order but includes regex flags and contents', () {
    final filter = RuleFilter(['a', 'b'], [RegExp('c', caseSensitive: false)], ['d', 'e']);
    expect(filter.hasSameRules(
      RuleFilter(['b', 'a'], [RegExp('c', caseSensitive: false)], ['e', 'd']),
    ), isTrue);
    for (final regexp in [
      RegExp('c'),
      RegExp('c', caseSensitive: false, multiLine: true),
      RegExp('c', caseSensitive: false, unicode: true),
      RegExp('c', caseSensitive: false, dotAll: true),
      RegExp('other', caseSensitive: false),
    ]) {
      expect(filter.hasSameRules(RuleFilter(['a', 'b'], [regexp], ['d', 'e'])), isFalse);
    }
    expect(filter.hasSameRules(RuleFilter.empty()), isFalse);
  });

  test('both save paths use the current runtime value and default to enabled', () async {
    expect(Pref.danmakuFilterEnabled, isTrue);
    expect(DanmakuOptions.danmakuFilterEnabled, isTrue);
    DanmakuOptions.danmakuFilterEnabled = false;
    await DanmakuOptions.saveFilterEnabled();
    expect(Pref.danmakuFilterEnabled, isFalse);
    DanmakuOptions.danmakuFilterEnabled = true;
    await DanmakuOptions.save(1.0);
    expect(Pref.danmakuFilterEnabled, isTrue);
    expect(GStorage.setting.get(SettingBoxKey.danmakuFilterEnabled), isTrue);
  });

  test('Hive type 12 remains readable in both old and new three-list formats', () async {
    Hive.registerAdapter<RuleFilter>(_LegacyRuleFilterAdapter());
    var box = await Hive.openBox<RuleFilter>('rules');
    final original = RuleFilter(['word'], [RegExp('regex', caseSensitive: false)], ['a']);
    await box.put('rules', original);
    await box.close();

    Hive.registerAdapter<RuleFilter>(RuleFilterAdapter(), override: true);
    box = await Hive.openBox<RuleFilter>('rules');
    final restored = box.get('rules')!;
    expect(restored.hasSameRules(original), isTrue);
    final elem = DanmakuElem(content: 'plain', midHash: 'b');
    expect(restored.remove(elem), isFalse);
    restored.addUid('b');
    expect(restored.remove(elem), isTrue);
    await box.put('rules', restored);
    await box.close();

    Hive.registerAdapter<RuleFilter>(_LegacyRuleFilterAdapter(), override: true);
    box = await Hive.openBox<RuleFilter>('rules');
    expect(box.get('rules')!.hasSameRules(restored), isTrue);
    expect(box.get('rules')!.remove(DanmakuElem(content: 'REGEX')), isTrue);
    await box.close();
  });
}

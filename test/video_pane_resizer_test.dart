import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/pages/video/models/pane_geometry.dart';
import 'package:PiliPlus/pages/video/widgets/pane_resizer.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('ratio settings validate stored values and restore automatic layout', () async {
    final directory = await Directory('${Directory.current.path}/.dart_tool')
        .createTemp('video-pane-test-');
    Hive.init(directory.path);
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    GStorage.setting = await Hive.openBox('setting');
    expect(Pref.videoPaneRatio, isNull);
    for (final value in [null, '0.6', -1, 0, 1, 2, double.nan, double.infinity]) {
      await GStorage.setting.put(SettingBoxKey.videoPaneRatio, value);
      expect(Pref.videoPaneRatio, isNull);
    }
    await Pref.saveVideoPaneRatio(0.6);
    expect(Pref.videoPaneRatio, 0.6);
    await GStorage.setting.put(SettingBoxKey.dynamicDetailRatio, [60.0, 40.0]);
    await Pref.saveVideoPaneRatio(null);
    expect(Pref.videoPaneRatio, isNull);
    expect(GStorage.setting.containsKey(SettingBoxKey.videoPaneRatio), isFalse);
    expect(Pref.dynamicDetailRatio, [60.0, 40.0]);
  });

  test('both panels and introduction remain within bounds', () {
    for (final width in [850.0, 1024.0, 1536.0, 1920.0]) {
      for (final height in [390.0, 600.0, 792.0, 1080.0]) {
        final geometry = VideoPaneGeometry(
          width: width, height: height, automaticWidth: width - 350,
          minRightWidth: 404,
        );
        if (!geometry.canResize) continue;
        for (final ratio in [0.01, 0.3, 0.7, 0.99]) {
          final left = geometry.leftWidth(ratio);
          expect(left, greaterThanOrEqualTo(500));
          expect(geometry.contentWidth - left, greaterThanOrEqualTo(404 - 0.001));
          expect(height - left / VideoPaneGeometry.aspectRatio,
            greaterThanOrEqualTo(120 - 0.001));
        }
      }
    }
    expect(const VideoPaneGeometry(width: 844, height: 390,
      automaticWidth: 564, minRightWidth: 320).canResize, isFalse);
  });

  late GlobalKey<VideoPaneResizerState> paneKey;
  late StateSetter updateHost;
  late double? stored;
  late bool enabled;
  late int saves;
  late int errors;
  late double leftWidth;
  late ScrollController scrollController;
  final contentKey = GlobalKey<_ContentProbeState>();
  late Future<void> Function(double?) save;

  Future<void> mount(WidgetTester tester, {double? ratio}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    paneKey = GlobalKey<VideoPaneResizerState>();
    stored = ratio;
    enabled = true;
    saves = errors = 0;
    scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    save = (ratio) async { saves++; stored = ratio; };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        updateHost = setState;
        return VideoPaneResizer(
          key: paneKey,
          enabled: enabled,
          automaticWidth: 975,
          minRightWidth: 320,
          hasIntro: true,
          readRatio: () => stored,
          saveRatio: (ratio) => save(ratio),
          onSaveError: () => errors++,
          builder: (width, size, gap, divider) {
            leftWidth = width;
            return Row(children: [
              SizedBox(width: width, child: _ContentProbe(key: contentKey)),
              divider,
              SizedBox(
                width: size.width - width - gap,
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 100,
                  itemExtent: 50,
                  itemBuilder: (context, index) => Text('评论 $index'),
                ),
              ),
            ]);
          },
        );
      })),
    ));
    await tester.pumpAndSettle();
  }

  Finder getDivider() => find.byKey(const ValueKey('video-pane-divider'));

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('$kind drag continues outside divider and preserves children', (tester) async {
      await mount(tester);
      final state = contentKey.currentState;
      scrollController.jumpTo(300);
      final before = leftWidth;
      final gesture = await tester.startGesture(tester.getCenter(getDivider()), kind: kind);
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();
      expect(leftWidth, lessThan(before - 100));
      expect(saves, 0);
      expect(contentKey.currentState, same(state));
      expect(scrollController.offset, 300);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(stored, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pointer cancellation restores preview without saving', (tester) async {
    await mount(tester, ratio: 0.65);
    final before = leftWidth;
    final gesture = await tester.startGesture(tester.getCenter(getDivider()));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(leftWidth, before);
    expect(saves, 0);
  });

  testWidgets('a second touch cancels the active edit', (tester) async {
    await mount(tester, ratio: 0.65);
    final before = leftWidth;
    final first = await tester.startGesture(tester.getCenter(getDivider()), pointer: 1);
    await first.moveBy(const Offset(-40, 0));
    await tester.pump();
    await first.moveBy(const Offset(-80, 0));
    await tester.pump();
    final second = await tester.startGesture(tester.getCenter(getDivider()), pointer: 2);
    await tester.pump();
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    expect(leftWidth, before);
    expect(saves, 0);
  });

  testWidgets('failed drag save restores the saved ratio and reports error', (tester) async {
    await mount(tester, ratio: 0.65);
    final before = leftWidth;
    save = (_) => Future.error(StateError('write failed'));
    await tester.drag(getDivider(), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(errors, 1);
    expect(leftWidth, before);
    expect(stored, 0.65);
  });

  testWidgets('temporary window bounds do not overwrite preference', (tester) async {
    await mount(tester, ratio: 0.75);
    final before = leftWidth;
    tester.view.physicalSize = const Size(1100, 800);
    await tester.pumpAndSettle();
    expect(leftWidth, lessThan(before));
    expect(stored, 0.75);
    tester.view.physicalSize = const Size(1400, 800);
    await tester.pumpAndSettle();
    expect(leftWidth, before);
    expect(saves, 0);
  });

  testWidgets('insufficient height hides adjustment and restores preference later', (tester) async {
    await mount(tester, ratio: 0.65);
    final before = leftWidth;
    tester.view.physicalSize = const Size(1400, 390);
    await tester.pumpAndSettle();
    expect(paneKey.currentState!.canAdjust, isFalse);
    expect(getDivider(), findsNothing);
    await paneKey.currentState!.showRatioDialog();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored, 0.65);
    tester.view.physicalSize = const Size(1400, 800);
    await tester.pumpAndSettle();
    expect(leftWidth, before);
    expect(getDivider(), findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('resizing during drag cancels the gesture before release', (tester) async {
    await mount(tester, ratio: 0.65);
    final gesture = await tester.startGesture(tester.getCenter(getDivider()));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(stored, 0.65);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing before touch drag starts cancels until the next gesture', (tester) async {
    await mount(tester, ratio: 0.65);
    final gesture = await tester.startGesture(tester.getCenter(getDivider()));
    await tester.pump();
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pump();
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-80, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(stored, 0.65);
    expect(saves, 0);
    await tester.drag(getDivider(), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(stored, isNot(0.65));
    expect(saves, 1);
    expect(tester.takeException(), isNull);
  });

  for (final disable in [true, false]) {
    testWidgets('${disable ? 'disabling' : 'shrinking'} clears hover before divider returns', (tester) async {
      await mount(tester);
      Color dividerColor() => tester.widget<Container>(find.descendant(
        of: getDivider(), matching: find.byType(Container),
      ).first).color!;
      final normalColor = dividerColor();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(20, 20));
      await mouse.moveTo(tester.getCenter(getDivider()));
      await tester.pump();
      expect(dividerColor(), isNot(normalColor));
      if (disable) {
        updateHost(() => enabled = false);
      } else {
        tester.view.physicalSize = const Size(1400, 390);
      }
      await tester.pumpAndSettle();
      expect(getDivider(), findsNothing);
      await mouse.moveTo(const Offset(20, 20));
      if (disable) {
        updateHost(() => enabled = true);
      } else {
        tester.view.physicalSize = const Size(1400, 800);
      }
      await tester.pumpAndSettle();
      expect(dividerColor(), normalColor);
      expect(saves, 0);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dialog previews, cancels and restores automatic mode', (tester) async {
    await mount(tester, ratio: 0.55);
    final before = leftWidth;
    unawaited(paneKey.currentState!.showRatioDialog());
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复自动'));
    await tester.pump();
    expect(leftWidth, isNot(before));
    expect(saves, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(leftWidth, before);
    unawaited(paneKey.currentState!.showRatioDialog());
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复自动'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(stored, isNull);
    expect(saves, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('dialog keyboard adjustment and system back cancel preview', (tester) async {
    await mount(tester, ratio: 0.55);
    final before = leftWidth;
    unawaited(paneKey.currentState!.showRatioDialog());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(leftWidth, greaterThan(before));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(leftWidth, before);
    expect(saves, 0);
  });

  testWidgets('failed dialog save remains open for retry', (tester) async {
    await mount(tester);
    save = (_) => Future.error(StateError('write failed'));
    unawaited(paneKey.currentState!.showRatioDialog());
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    save = (ratio) async { saves++; stored = ratio; };
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('resize cancels dialog preview and preserves saved preference', (tester) async {
    await mount(tester, ratio: 0.55);
    unawaited(paneKey.currentState!.showRatioDialog());
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复自动'));
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored, 0.55);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog saves once while write is pending and protects back', (tester) async {
    await mount(tester, ratio: 0.55);
    final completion = Completer<void>();
    save = (ratio) async {
      saves++;
      await completion.future;
      stored = ratio;
    };
    unawaited(paneKey.currentState!.showRatioDialog());
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复自动'));
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.tap(find.text('保存中'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(saves, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored, isNull);
  });

  testWidgets('disabling layout dismisses only its own dialog', (tester) async {
    await mount(tester);
    unawaited(paneKey.currentState!.showRatioDialog());
    await tester.pumpAndSettle();
    final navigator = Navigator.of(tester.element(find.byType(AlertDialog)));
    unawaited(navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('另一个页面')),
    )));
    await tester.pumpAndSettle();
    updateHost(() => enabled = false);
    await tester.pumpAndSettle();
    expect(find.text('另一个页面'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(getDivider(), findsNothing);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });
}

class _ContentProbe extends StatefulWidget {
  const _ContentProbe({super.key});
  @override
  State<_ContentProbe> createState() => _ContentProbeState();
}

class _ContentProbeState extends State<_ContentProbe> {
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

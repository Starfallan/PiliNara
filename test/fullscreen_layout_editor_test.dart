import 'dart:async';

import 'package:PiliPlus/common/widgets/back_detector.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/main.dart' show onAppBack, onAppKeyEvent;
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_layout.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/fullscreen_layout_editor.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kBackMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final initial = FullscreenLayout.defaults(isMobile: true);

  Future<void> openEditor(
    WidgetTester tester, {
    FullscreenLayout? layout,
    required Future<void> Function(FullscreenLayout) onSave,
    Size size = const Size(1100, 620),
    EdgeInsets viewPadding = EdgeInsets.zero,
    bool removeSafeArea = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewPadding: viewPadding,
          padding: EdgeInsets.zero,
        ),
        child: child!,
      ),
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showGeneralDialog<void>(
            context: context,
            pageBuilder: (context, animation, secondaryAnimation) => FullscreenLayoutEditor(
              initial: layout ?? initial,
              isMobile: true,
              supportsPip: true,
              removeSafeArea: removeSafeArea,
              onSave: onSave,
            ),
          ),
          child: const Text('编辑'),
        ),
      )),
    ));
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel and reset only change the draft', (tester) async {
    var saves = 0;
    final layout = initial.toggle(PlayerLayoutControl.like);
    await openEditor(tester, layout: layout, onSave: (_) async { saves++; });
    await tester.tap(find.text('恢复默认'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('layout-share')));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(layout.shows(PlayerLayoutControl.like), isFalse);
    expect(find.byType(FullscreenLayoutEditor), findsNothing);
  });

  testWidgets('save commits the draft once', (tester) async {
    FullscreenLayout? saved;
    await openEditor(tester, onSave: (layout) async { saved = layout; });
    await tester.tap(find.byKey(const ValueKey('layout-share')));
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();
    expect(saved!.shows(PlayerLayoutControl.share), isFalse);
    expect(initial.shows(PlayerLayoutControl.share), isTrue);
    expect(find.byType(FullscreenLayoutEditor), findsNothing);
  });

  testWidgets('a failed save keeps the draft for retry', (tester) async {
    await openEditor(tester, onSave: (_) => Future.error(StateError('write failed')));
    await tester.tap(find.byKey(const ValueKey('layout-share')));
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.byType(FullscreenLayoutEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<NavigatorState> openWithAppBack(
    WidgetTester tester,
    Future<void> Function(FullscreenLayout) onSave,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(920, 430);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FocusManager.instance.addEarlyKeyEventHandler(onAppKeyEvent);
    addTearDown(() => FocusManager.instance.removeEarlyKeyEventHandler(onAppKeyEvent));
    await tester.pumpWidget(MaterialApp(
      navigatorKey: Get.key,
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(
        builder: (context, child) => BackDetector(onBack: onAppBack, child: child!),
      ),
      home: const Scaffold(body: Text('首页')),
    ));
    final navigator = Get.key.currentState!;
    unawaited(navigator.push(GetPageRoute<void>(
      page: () => Builder(builder: (context) => Scaffold(
        body: Column(children: [
          const Text('视频页'),
          TextButton(
            onPressed: () => showGeneralDialog<void>(
              context: context,
              transitionDuration: const Duration(milliseconds: 150),
              pageBuilder: (context, animation, secondaryAnimation) => FullscreenLayoutEditor(
                initial: initial,
                isMobile: true,
                supportsPip: true,
                onSave: onSave,
              ),
            ),
            child: const Text('编辑'),
          ),
        ]),
      )),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    return navigator;
  }

  Future<void> appBack(WidgetTester tester, String input) async {
    if (input == 'Escape') {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    } else if (input == 'mouse') {
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await mouse.down(const Offset(400, 300));
      await mouse.up();
      await mouse.removePointer();
    } else {
      await tester.binding.handlePopRoute();
    }
    await tester.pumpAndSettle();
  }

  for (final input in ['Escape', 'mouse', 'system']) {
    testWidgets('$input uses the app back path and cannot interrupt a save', (tester) async {
      final saved = Completer<void>();
      await openWithAppBack(tester, (_) => saved.future);
      await tester.tap(find.text('完成编辑'));
      await tester.pump();
      await appBack(tester, input);
      expect(find.byType(FullscreenLayoutEditor), findsOneWidget);
      expect(find.text('保存中…'), findsOneWidget);
      saved.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FullscreenLayoutEditor), findsNothing);
      expect(find.text('视频页'), findsOneWidget);
    });

    testWidgets('$input cancels the editor when no save is pending', (tester) async {
      var saves = 0;
      await openWithAppBack(tester, (_) async { saves++; });
      await appBack(tester, input);
      expect(saves, 0);
      expect(find.byType(FullscreenLayoutEditor), findsNothing);
      expect(find.text('视频页'), findsOneWidget);
    });
  }

  testWidgets('a save finishing during dismissal cannot pop the video route', (tester) async {
    final saved = Completer<void>();
    final navigator = await openWithAppBack(tester, (_) => saved.future);
    await tester.tap(find.text('完成编辑'));
    await tester.pump();
    // 模拟路由被程序主动关闭；pop 本来就不遵守 PopScope。
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(FullscreenLayoutEditor), findsOneWidget);
    saved.complete();
    await tester.pumpAndSettle();
    expect(find.text('视频页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save remains visible after an app back attempt', (tester) async {
    final saved = Completer<void>();
    await openWithAppBack(tester, (_) => saved.future);
    await tester.tap(find.text('完成编辑'));
    await tester.pump();
    await appBack(tester, 'Escape');
    saved.completeError(StateError('write failed'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    await appBack(tester, 'mouse');
    expect(find.text('视频页'), findsOneWidget);
  });

  testWidgets('save does not close a covering route or leave the editor disabled', (tester) async {
    final saved = Completer<void>();
    final navigator = await openWithAppBack(tester, (_) => saved.future);
    await tester.tap(find.text('完成编辑'));
    await tester.pump();
    unawaited(navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('其他页面')),
    )));
    await tester.pumpAndSettle();
    saved.complete();
    await tester.pumpAndSettle();
    expect(find.text('其他页面'), findsOneWidget);
    await appBack(tester, 'Escape');
    expect(find.text('完成编辑'), findsOneWidget);
    expect(find.text('保存中…'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('视频页'), findsOneWidget);
  });

  testWidgets('app back still respects page guards and keeps the root route', (tester) async {
    var blocked = 0;
    final navigator = await openWithAppBack(tester, (_) async {});
    await appBack(tester, 'Escape');
    unawaited(navigator.push(GetPageRoute<void>(
      page: () => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) blocked++;
        },
        child: const Scaffold(body: Text('受保护页面')),
      ),
    )));
    await tester.pumpAndSettle();
    await appBack(tester, 'Escape');
    await appBack(tester, 'mouse');
    expect(blocked, 2);
    expect(find.text('受保护页面'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    await appBack(tester, 'Escape');
    await appBack(tester, 'mouse');
    expect(find.text('首页'), findsOneWidget);
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('dragging an action onto the bottom region is rejected', (tester) async {
    FullscreenLayout? saved;
    await openEditor(tester, onSave: (layout) async { saved = layout; });
    final start = tester.getCenter(find.byKey(const ValueKey('layout-like')));
    final target = tester.getCenter(find.byKey(const ValueKey('layout-subtitle')));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();
    expect(saved!.toJson(), initial.toJson());
  });

  testWidgets('a same-region drag inserts after the target', (tester) async {
    FullscreenLayout? saved;
    await openEditor(tester, onSave: (layout) async { saved = layout; });
    final start = tester.getCenter(find.byKey(const ValueKey('layout-like')));
    final target = tester.getRect(find.byKey(const ValueKey('layout-share')));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(Offset(target.right - 4, target.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();
    expect(saved!.items(PlayerLayoutRegion.actions).last, PlayerLayoutControl.like);
  });

  testWidgets('side drag moves the lock to the right without hiding it', (tester) async {
    FullscreenLayout? saved;
    await openEditor(tester, onSave: (layout) async { saved = layout; });
    final start = tester.getCenter(find.byKey(const ValueKey('layout-lock')));
    final target = tester.getRect(find.byKey(const ValueKey('layout-screenshot')));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(Offset(target.center.dx, target.bottom - 4));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();
    expect(saved!.items(PlayerLayoutRegion.left), isEmpty);
    expect(saved!.items(PlayerLayoutRegion.right), [
      PlayerLayoutControl.screenshot,
      PlayerLayoutControl.lock,
    ]);
    expect(saved!.shows(PlayerLayoutControl.lock), isTrue);
  });

  testWidgets('keeps player icons and places editing actions in the center', (tester) async {
    const size = Size(920, 430);
    await openEditor(tester, size: size, onSave: (_) async {});
    expect(find.byIcon(FontAwesomeIcons.thumbsUp), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.b), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.shareFromSquare), findsOneWidget);
    expect(find.byIcon(CustomIcons.download), findsOneWidget);
    expect(find.text('点赞'), findsNothing);
    expect(find.text('画面比例'), findsNothing);
    expect(find.text('自动'), findsOneWidget);
    for (final label in ['恢复默认', '取消', '完成编辑']) {
      expect(tester.getCenter(find.text(label)).dy, inInclusiveRange(size.height * 0.4, size.height * 0.65));
    }
    expect(tester.getCenter(find.byType(ProgressBar)).dy, greaterThan(size.height - 80));
    final elapsed = tester.getRect(find.text('00:38'));
    final total = tester.getRect(find.text('01:42'));
    expect(elapsed.center.dx, closeTo(total.center.dx, 0.1));
    expect(elapsed.bottom, lessThanOrEqualTo(total.top));
    expect(total.left, lessThan(100));
  });

  testWidgets('information toggles are clickable below the title', (tester) async {
    FullscreenLayout? saved;
    await openEditor(tester, onSave: (layout) async { saved = layout; });
    await tester.tap(find.byKey(const ValueKey('layout-online')));
    await tester.tap(find.byKey(const ValueKey('layout-dmCount')));
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();
    expect(saved!.shows(PlayerLayoutControl.online), isTrue);
    expect(saved!.shows(PlayerLayoutControl.dmCount), isTrue);
  });

  testWidgets('portrait editor avoids the cutout and omits landscape-only header controls', (tester) async {
    FullscreenLayout? saved;
    final layout = initial.toggle(PlayerLayoutControl.clock)
        .toggle(PlayerLayoutControl.battery);
    await openEditor(
      tester,
      size: const Size(390, 844),
      viewPadding: const EdgeInsets.only(top: 48),
      layout: layout,
      onSave: (value) async { saved = value; },
    );
    expect(find.byIcon(FontAwesomeIcons.house), findsNothing);
    expect(find.byKey(const ValueKey('layout-clock')), findsNothing);
    expect(find.byKey(const ValueKey('layout-battery')), findsNothing);
    final back = tester.getRect(find.byTooltip('返回（固定）'));
    expect(back.top, closeTo(60, 0.1));
    final info = tester.getRect(find.byKey(const ValueKey('layout-online')));
    expect(info.left, closeTo(back.right, 0.1));
    for (final control in ['sponsorSubmit', 'pip', 'like', 'online', 'dmCount']) {
      final item = find.byKey(ValueKey('layout-$control'));
      expect(item.hitTestable(), findsOneWidget);
      expect(tester.getRect(item).top, greaterThanOrEqualTo(48));
    }
    for (final control in ['subtitle', 'qa', 'fit', 'episode', 'viewPoints', 'superResolution']) {
      expect(find.byKey(ValueKey('layout-$control')).hitTestable(), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('layout-online')));
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();
    expect(saved!.shows(PlayerLayoutControl.online), isTrue);
    expect(saved!.shows(PlayerLayoutControl.clock), isFalse);
    expect(saved!.shows(PlayerLayoutControl.battery), isFalse);
    expect(saved!.regions, layout.regions);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait editor respects the existing remove-safe-area setting', (tester) async {
    await openEditor(
      tester,
      size: const Size(390, 844),
      viewPadding: const EdgeInsets.only(top: 48),
      removeSafeArea: true,
      onSave: (_) async {},
    );
    expect(tester.getTopLeft(find.byTooltip('返回（固定）')).dy, closeTo(12, 0.1));
    expect(find.byKey(const ValueKey('layout-clock')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape keeps header controls and both side safe areas', (tester) async {
    await openEditor(
      tester,
      size: const Size(844, 390),
      viewPadding: const EdgeInsets.only(left: 48, right: 24),
      onSave: (_) async {},
    );
    expect(find.byIcon(FontAwesomeIcons.house), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-clock')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-battery')).hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(find.byTooltip('返回（固定）')).dx, closeTo(48, 0.1));
    expect(tester.getTopRight(find.byTooltip('更多（固定）')).dx, closeTo(820, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('header drag can move pip before the other optional controls', (tester) async {
    FullscreenLayout? saved;
    await openEditor(tester, onSave: (layout) async { saved = layout; });
    final start = tester.getCenter(find.byKey(const ValueKey('layout-pip')));
    final target = tester.getRect(find.byKey(const ValueKey('layout-sponsorSubmit')));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(Offset(target.left + 3, target.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成编辑'));
    await tester.pumpAndSettle();
    expect(saved!.items(PlayerLayoutRegion.header), [
      PlayerLayoutControl.pin,
      PlayerLayoutControl.pip,
      PlayerLayoutControl.sponsorSubmit,
      PlayerLayoutControl.sponsorInfo,
    ]);
  });

  for (final size in [const Size(640, 360), const Size(390, 844)]) {
    testWidgets('editor remains usable at $size', (tester) async {
      await openEditor(tester, size: size, onSave: (_) async {});
      expect(find.text('因视频属性不同，部分功能可能不会展示在屏幕上'), findsOneWidget);
      expect(find.text('完成编辑').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quality can be dragged to the first bottom slot at $size', (tester) async {
      FullscreenLayout? saved;
      await openEditor(tester, size: size, onSave: (layout) async { saved = layout; });
      final start = tester.getCenter(find.byKey(const ValueKey('layout-qa')));
      final target = tester.getRect(find.byKey(const ValueKey('layout-viewPoints')));
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(Offset(target.left + 3, target.center.dy));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成编辑'));
      await tester.pumpAndSettle();
      expect(saved!.items(PlayerLayoutRegion.bottom).first, PlayerLayoutControl.qa);
    });
  }
}

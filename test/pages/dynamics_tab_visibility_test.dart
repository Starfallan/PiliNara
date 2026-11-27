import 'dart:typed_data';

import 'package:PiliPlus/http/loading_state.dart' as load;
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/action_panel.dart';
import 'package:PiliPlus/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/pages/dynamics_tab/view.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GStorage.setting = await Hive.openBox('setting', bytes: Uint8List(0));
    GStorage.localCache = await Hive.openBox('cache', bytes: Uint8List(0));
  });
  tearDownAll(Hive.close);
  tearDown(Get.reset);

  test(
    'dynamic visibility preferences default off and are independent',
    () async {
      expect(Pref.hideTextDyn, isFalse);
      expect(Pref.hideImageDyn, isFalse);
      expect(Pref.hideDynamicComments, isFalse);
      await GStorage.setting.put(SettingBoxKey.hideImageDyn, true);
      expect(Pref.hideTextDyn, isFalse);
      expect(Pref.hideImageDyn, isTrue);
      expect(Pref.hideDynamicComments, isFalse);
      await GStorage.setting.delete(SettingBoxKey.hideImageDyn);
    },
  );

  for (final waterfall in [false, true]) {
    testWidgets(
      'hidden page tails require one tap per request (grid=$waterfall)',
      (tester) async {
        final ctr = await _showFeed(
          tester,
          layout: waterfall,
          type: waterfall ? DynamicsTabType.up : DynamicsTabType.all,
          pages: [
            _page(['first']),
            _page(['second']),
            const load.Error('offline'),
            _page([]),
          ],
        );
        final more = find.text('加载更多');
        expect(more, findsOneWidget);
        expect(find.byType(ActionPanel), findsNothing);
        expect(ctr.requests, 1);
        expect(ctr.offset, '1');
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(ctr.requests, 2);
        expect(ctr.offset, '2');
        final items = ctr.loadingState.value.data!;
        expect(items.map((item) => item.idStr), ['first', 'second']);
        expect(items.map((item) => item.visible), [null, null]);
        expect(more, findsOneWidget);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(ctr.requests, 3);
        expect(ctr.offset, '2');
        expect(more, findsOneWidget);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(ctr.requests, 4);
        expect(ctr.isEnd, isTrue);
        expect(more, findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('fold carrier renders and expands its original hidden member', (
    tester,
  ) async {
    final page = _page(['fold', 'member']);
    final [carrier, member] = page.response.items!;
    carrier.modules.moduleFold = ModuleFold.fromJson({
      'ids': ['member'],
      'statement': '展开测试折叠',
    });
    member.visible = false;
    final ctr = await _showFeed(
      tester,
      layout: false,
      type: DynamicsTabType.all,
      pages: [page, _page([])],
    );
    expect(find.byType(ActionPanel), findsOneWidget);
    final unfold = find.textContaining('展开测试折叠', findRichText: true);
    expect(unfold, findsOneWidget);
    expect(ctr.requests, 2);
    await tester.tap(unfold);
    await tester.pumpAndSettle();
    expect(member.visible, isTrue);
    expect(carrier.modules.moduleFold, isNull);
    expect(ctr.loadingState.value.data, orderedEquals([carrier, member]));
    expect(find.byType(ActionPanel), findsNothing);
    expect(ctr.requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a dedicated tab still renders its visible tail and auto-loads', (
    tester,
  ) async {
    final ctr = await _showFeed(
      tester,
      layout: false,
      type: DynamicsTabType.article,
      pages: [
        _page(['visible']),
        _page([]),
      ],
    );
    expect(
      tester.widget<DynamicPanel>(find.byType(DynamicPanel)).hidden,
      isFalse,
    );
    expect(find.byType(ActionPanel), findsOneWidget);
    expect(find.text('加载更多'), findsNothing);
    expect(ctr.requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<_FeedController> _showFeed(
  WidgetTester tester, {
  required bool layout,
  required DynamicsTabType type,
  required List<load.LoadingState<DynamicsDataModel>> pages,
}) async {
  await GStorage.setting.put(SettingBoxKey.hideTextDyn, true);
  GlobalData().dynamicsWaterfallFlow = layout;
  Get
    ..put<AccountService>(_AccountService())
    ..put<DynamicsController>(_DynamicsController());
  final controller =
      Get.put<DynamicsTabController>(
            _FeedController(type, pages),
            tag: type.name,
          )
          as _FeedController;
  await controller.queryData();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DynamicsTabPage(dynamicsType: type)),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

load.Success<DynamicsDataModel> _page(List<String> items) => load.Success(
  DynamicsDataModel.fromJson({
    'offset': items.isEmpty
        ? ''
        : items.first == 'second'
        ? '2'
        : '1',
    'has_more': items.isNotEmpty,
    'items': items
        .map(
          (id) => {
            'id_str': id,
            'type': 'DYNAMIC_TYPE_WORD',
            'modules': {
              'module_author': {
                'mid': 9,
                'name': 'author',
                'face': '',
                'type': 'AUTHOR_TYPE_NORMAL',
              },
              'module_stat': {
                'comment': {'count': 12, 'status': false},
                'forward': {'count': 3, 'status': false},
                'like': {'count': 4, 'status': false},
              },
              'module_dynamic': {
                'desc': {'text': id},
              },
            },
          },
        )
        .toList(),
  }),
);

class _AccountService extends AccountService {
  // The test supplies fixture state rather than running production startup.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _DynamicsController extends DynamicsController {
  // The test supplies fixture state rather than running production startup.
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void onClose() => scrollController.dispose();
}

class _FeedController extends DynamicsTabController {
  _FeedController(DynamicsTabType type, this.pages) : super(dynamicsType: type);

  final List<load.LoadingState<DynamicsDataModel>> pages;
  int requests = 0;

  // The test supplies fixture state rather than running production startup.
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<load.LoadingState<DynamicsDataModel>> customGetData() async =>
      pages[requests++];
}

import 'dart:typed_data';

import 'package:PiliPlus/http/loading_state.dart' as load;
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/widgets/action_panel.dart';
import 'package:PiliPlus/pages/member_dynamics/controller.dart';
import 'package:PiliPlus/pages/member_dynamics/view.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
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

  for (final waterfall in [false, true]) {
    testWidgets(
      'member dynamics hides text and image tails with manual continuation '
      '(waterfall=$waterfall)',
      (tester) async {
        await GStorage.setting.put(SettingBoxKey.hideTextDyn, true);
        await GStorage.setting.put(SettingBoxKey.hideImageDyn, true);
        GlobalData().dynamicsWaterfallFlow = waterfall;

        const mid = 42;
        final controller =
            Get.put<MemberDynamicsController>(
                  _MemberController(mid, [_page(), _emptyPage()]),
                  tag: Utils.makeHeroTag(mid),
                )
                as _MemberController;
        await controller.queryData();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: MemberDynamicsPage(mid: mid)),
          ),
        );
        await tester.pumpAndSettle();

        expect(Pref.hideTextDyn, isTrue);
        expect(Pref.hideImageDyn, isTrue);
        expect(find.byType(ActionPanel), findsNothing);
        expect(
          find.text(
            '\u5f53\u524d\u9875\u9762\u52a8\u6001\u5747\u5df2\u9690\u85cf',
          ),
          findsOneWidget,
        );
        expect(find.text('\u52a0\u8f7d\u66f4\u591a'), findsOneWidget);
        expect(controller.requests, 1);

        await tester.tap(find.text('\u52a0\u8f7d\u66f4\u591a'));
        await tester.pumpAndSettle();

        expect(controller.requests, 2);
        expect(controller.isEnd, isTrue);
        expect(controller.offset, '-1');
        expect(find.text('\u52a0\u8f7d\u66f4\u591a'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

load.Success<DynamicsDataModel> _page() => load.Success(
  DynamicsDataModel.fromJson({
    'offset': 'cursor-1',
    'has_more': true,
    'items': [
      {
        'id_str': 'text-item',
        'type': 'DYNAMIC_TYPE_WORD',
        'modules': {
          'module_author': {'mid': 9, 'name': 'author', 'face': ''},
          'module_dynamic': {
            'desc': {'text': 'text body'},
          },
        },
      },
      {
        'id_str': 'image-item',
        'type': 'DYNAMIC_TYPE_DRAW',
        'modules': {
          'module_author': {'mid': 9, 'name': 'author', 'face': ''},
          'module_dynamic': {
            'major': {
              'type': 'MAJOR_TYPE_DRAW',
              'draw': {
                'items': [
                  {'img_src': 'https://example.com/image.jpg'},
                ],
              },
            },
          },
        },
      },
    ],
  }),
);

load.Success<DynamicsDataModel> _emptyPage() => load.Success(
  DynamicsDataModel.fromJson({
    'offset': '',
    'has_more': false,
    'items': [],
  }),
);

class _MemberController extends MemberDynamicsController {
  _MemberController(super.mid, this.pages);

  final List<load.LoadingState<DynamicsDataModel>> pages;
  int requests = 0;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<load.LoadingState<DynamicsDataModel>> customGetData() async =>
      pages[requests++];
}

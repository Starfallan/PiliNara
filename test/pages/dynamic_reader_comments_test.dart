import 'dart:typed_data';

import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

Map<String, dynamic> _item() => {
  'id_str': 'dyn-1',
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
      'desc': {'text': 'body'},
    },
    'module_interaction': {
      'items': [
        {
          'type': 1,
          'desc': {
            'rich_text_nodes': [
              {'text': '热评文本', 'orig_text': '热评文本'},
            ],
          },
        },
        {
          'type': 2,
          'desc': {
            'rich_text_nodes': [
              {'text': '点赞文本', 'orig_text': '点赞文本'},
            ],
          },
        },
      ],
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GStorage.setting = await Hive.openBox('setting', bytes: Uint8List(0));
    GStorage.localCache = await Hive.openBox('cache', bytes: Uint8List(0));
  });
  tearDownAll(Hive.close);

  Finder button(String label) => find.byWidgetPredicate(
    (widget) => widget is Icon && widget.semanticLabel == label,
  );

  testWidgets(
    'hidden card comments preserve like and non-comment interaction',
    (tester) async {
      await GStorage.setting.put(SettingBoxKey.hideDynamicComments, true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicPanel(item: DynamicItemModel.fromJson(_item())),
          ),
        ),
      );
      expect(find.textContaining('热评文本', findRichText: true), findsNothing);
      expect(button('评论'), findsNothing);
      expect(find.textContaining('点赞文本', findRichText: true), findsOneWidget);
      expect(button('点赞'), findsOneWidget);
      expect(button('转发'), findsOneWidget);
    },
  );

  testWidgets('comments remain visible when preference is off', (tester) async {
    await GStorage.setting.put(SettingBoxKey.hideDynamicComments, false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicPanel(item: DynamicItemModel.fromJson(_item())),
        ),
      ),
    );
    expect(find.textContaining('热评文本', findRichText: true), findsOneWidget);
    expect(button('评论'), findsOneWidget);
  });
}

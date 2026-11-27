import 'dart:typed_data';

import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Classification contract for the dynamic display preference: only reliable
// evidence yields text/image; anything missing or contradictory stays unknown
// so the View keeps rendering it. Filtering itself is not part of the getter.

Map<String, dynamic> dyn(
  String type, {
  Map<String, dynamic>? major,
  Map<String, dynamic>? desc,
  Map<String, dynamic>? orig,
}) => <String, dynamic>{
  'id_str': '1',
  'type': type,
  'modules': {
    'module_dynamic': <String, dynamic>{'major': ?major, 'desc': ?desc},
  },
  'orig': ?orig,
};

DynamicContentType? typeOf(Map<String, dynamic> json) =>
    DynamicItemModel.fromJson(json).contentType;

Map<String, dynamic> opus({
  List<Map<String, dynamic>>? pics,
  String? text,
}) => <String, dynamic>{
  'type': 'MAJOR_TYPE_OPUS',
  'opus': <String, dynamic>{
    'pics': ?pics,
    'summary': ?(text == null ? null : {'text': text}),
  },
};

Map<String, dynamic> draw(List<Map<String, dynamic>> items) =>
    <String, dynamic>{
      'type': 'MAJOR_TYPE_DRAW',
      'draw': {'items': items},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GStorage.setting = await Hive.openBox('settings', bytes: Uint8List(0));
    GStorage.localCache = await Hive.openBox('cache', bytes: Uint8List(0));
  });
  tearDownAll(Hive.close);

  group('content type', () {
    test('only text and image exist', () {
      expect(DynamicContentType.values, const [
        DynamicContentType.text,
        DynamicContentType.image,
      ]);
    });

    test('traditional word and draw', () {
      expect(
        typeOf(dyn('DYNAMIC_TYPE_WORD', desc: {'text': 'hello'})),
        DynamicContentType.text,
      );
      // Rich text wording alone is still plain text.
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_WORD',
            desc: {
              'text': 'hello',
              'rich_text_nodes': [
                {'type': 'RICH_TEXT_NODE_TYPE_TEXT', 'orig_text': 'hello'},
              ],
            },
          ),
        ),
        DynamicContentType.text,
      );
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_DRAW',
            major: draw([
              {'img_src': 'https://i0.hdslb.com/a.jpg'},
            ]),
          ),
        ),
        DynamicContentType.image,
      );
      // Draw with only blank/missing picture evidence is contradictory.
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_DRAW',
            major: draw([
              {'img_src': '   '},
            ]),
            desc: {'text': 'hello'},
          ),
        ),
        isNull,
      );
      expect(typeOf(dyn('DYNAMIC_TYPE_DRAW')), isNull);
    });

    test('opus text, opus image and incomplete opus', () {
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_WORD',
            major: opus(pics: [], text: 'plain'),
          ),
        ),
        DynamicContentType.text,
      );
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_DRAW',
            major: opus(pics: [], text: 'plain'),
          ),
        ),
        DynamicContentType.text,
      );
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_WORD',
            major: opus(
              pics: [
                {'url': 'https://i0.hdslb.com/b.jpg'},
              ],
              text: 'caption',
            ),
          ),
        ),
        DynamicContentType.image,
      );
      // Picture slot present but unusable.
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_WORD',
            major: opus(pics: [<String, dynamic>{}], text: 'caption'),
          ),
        ),
        isNull,
      );
      // No pics field: emptiness cannot be proven either.
      expect(
        typeOf(dyn('DYNAMIC_TYPE_WORD', major: opus(text: 'caption'))),
        isNull,
      );
      // Text-less opus is not a pure text dynamic.
      expect(
        typeOf(dyn('DYNAMIC_TYPE_WORD', major: opus(pics: []))),
        isNull,
      );
    });

    test('rich text picture nodes', () {
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_WORD',
            desc: {
              'text': 'see pic',
              'rich_text_nodes': [
                {
                  'type': 'RICH_TEXT_NODE_TYPE_VIEW_PICTURE',
                  'pics': [
                    {'src': 'https://i0.hdslb.com/c.jpg'},
                  ],
                },
              ],
            },
          ),
        ),
        DynamicContentType.image,
      );
      // Unknown picture node content must not degrade into text.
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_WORD',
            desc: {
              'text': 'see pic',
              'rich_text_nodes': [
                {'type': 'RICH_TEXT_NODE_TYPE_VIEW_PICTURE'},
              ],
            },
          ),
        ),
        isNull,
      );
    });

    test('forward inherits the original classification', () {
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_FORWARD',
            orig: dyn('DYNAMIC_TYPE_WORD', desc: {'text': 'hello'}),
          ),
        ),
        DynamicContentType.text,
      );
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_FORWARD',
            orig: dyn(
              'DYNAMIC_TYPE_DRAW',
              major: draw([
                {'img_src': 'https://i0.hdslb.com/d.jpg'},
              ]),
            ),
          ),
        ),
        DynamicContentType.image,
      );
      // Nested forward resolves through the chain.
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_FORWARD',
            orig: dyn(
              'DYNAMIC_TYPE_FORWARD',
              orig: dyn('DYNAMIC_TYPE_WORD', desc: {'text': 'hello'}),
            ),
          ),
        ),
        DynamicContentType.text,
      );
      // Unknown or absent original stays unknown.
      expect(
        typeOf(dyn('DYNAMIC_TYPE_FORWARD', orig: dyn('DYNAMIC_TYPE_AV'))),
        isNull,
      );
      expect(typeOf(dyn('DYNAMIC_TYPE_FORWARD')), isNull);
    });

    test('fromJson keeps every classified item and its visible flag', () {
      final payload = <String, dynamic>{
        'items': [
          dyn('DYNAMIC_TYPE_WORD', desc: {'text': 'keep me'})..['id_str'] = 'a',
          dyn(
            'DYNAMIC_TYPE_DRAW',
            major: draw([
              {'img_src': 'https://i0.hdslb.com/f.jpg'},
            ]),
          )..['id_str'] = 'b',
          dyn('DYNAMIC_TYPE_WORD', desc: {'text': 'fold member'})
            ..['id_str'] = 'c'
            ..['visible'] = false,
        ],
        'has_more': true,
        'offset': 'next',
      };
      final model = DynamicsDataModel.fromJson(payload);
      expect(model.items!.map((e) => e.idStr), ['a', 'b', 'c']);
      expect(model.items!.map((e) => e.contentType), [
        DynamicContentType.text,
        DynamicContentType.image,
        DynamicContentType.text,
      ]);
      expect(model.items![2].visible, isFalse);
      expect(model.hasMore, isTrue);
      expect(model.offset, 'next');
    });

    test('non-target and unavailable dynamics are never classified', () {
      for (final type in [
        'DYNAMIC_TYPE_AV',
        'DYNAMIC_TYPE_LIVE',
        'DYNAMIC_TYPE_LIVE_RCMD',
        'DYNAMIC_TYPE_PGC',
        'DYNAMIC_TYPE_UGC_SEASON',
        'DYNAMIC_TYPE_NONE',
      ]) {
        expect(typeOf(dyn(type)), isNull, reason: type);
      }
      // Image-bearing column article.
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_ARTICLE',
            major: opus(
              pics: [
                {'url': 'https://i0.hdslb.com/e.jpg'},
              ],
              text: 'article',
            ),
          ),
        ),
        isNull,
      );
      // Expired dynamic keeps its placeholder instead of being hidden.
      expect(
        typeOf(
          dyn(
            'DYNAMIC_TYPE_WORD',
            major: {
              'type': 'MAJOR_TYPE_NONE',
              'none': {'tips': '已失效'},
            },
            desc: {'text': 'hello'},
          ),
        ),
        isNull,
      );
    });
  });
}

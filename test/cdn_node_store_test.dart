import 'package:PiliPlus/utils/cdn_node_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidNodeHost', () {
    test('accepts bilibili media hosts', () {
      expect(
        CdnNodeStore.isValidNodeHost('cn-sh-ct-01-01.bilivideo.com'),
        true,
      );
      expect(
        CdnNodeStore.isValidNodeHost('d1--cn-gotcha204-1.bilivideo.com'),
        true,
      );
      expect(
        CdnNodeStore.isValidNodeHost('upos-hz-mirrorakam.akamaized.net'),
        true,
      );
    });

    test('rejects non-whitelisted or malformed hosts', () {
      expect(CdnNodeStore.isValidNodeHost('bilivideo.evil.com'), false);
      expect(CdnNodeStore.isValidNodeHost('evil.com'), false);
      expect(
        CdnNodeStore.isValidNodeHost('https://cn-sh.bilivideo.com'),
        false,
      );
      expect(CdnNodeStore.isValidNodeHost('cn-sh.bilivideo.com/path'), false);
      expect(CdnNodeStore.isValidNodeHost(''), false);
    });
  });

  group('parseNodes', () {
    test('keeps valid entries and drops invalid ones', () {
      final parsed = CdnNodeStore.parseNodes({
        '上海': ['cn-sh-ct-01-01.bilivideo.com', 'evil.com', 42],
        '空': ['not-a-host'],
        3: ['cn-bj-cc-03-14.bilivideo.com'],
        '北京': 'oops',
      });
      expect(parsed, {
        '上海': ['cn-sh-ct-01-01.bilivideo.com'],
      });
    });

    test('returns null when nothing valid', () {
      expect(CdnNodeStore.parseNodes(null), null);
      expect(CdnNodeStore.parseNodes([]), null);
      expect(
        CdnNodeStore.parseNodes({
          'a': ['evil.com'],
        }),
        null,
      );
    });
  });

  group('labels', () {
    test('parses isp and short title from host', () {
      expect(
        CdnNodeStore.nodeTitleOf('cn-sh-ct-01-01.bilivideo.com'),
        '电信 01-01',
      );
      expect(
        CdnNodeStore.nodeTitleOf('cn-sccd-cu-01-05.bilivideo.com'),
        '联通 01-05',
      );
      expect(
        CdnNodeStore.nodeTitleOf('cn-sh-office-bcache-01.bilivideo.com'),
        'B站自建 01',
      );
      expect(
        CdnNodeStore.nodeTitleOf('upos-sz-mirrorali.bilivideo.com'),
        'upos-sz-mirrorali',
      );
    });
  });

  group('sortedRegions', () {
    test('orders by upstream region order, unknown regions last', () {
      expect(
        CdnNodeStore.sortedRegions({
          '海外': ['a.bilivideo.com'],
          '未知地区': ['b.bilivideo.com'],
          '上海': ['c.bilivideo.com'],
          '北京': ['d.bilivideo.com'],
        }),
        ['北京', '上海', '海外', '未知地区'],
      );
    });
  });
}

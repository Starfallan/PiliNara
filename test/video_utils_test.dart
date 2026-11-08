import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // 静态字段先赋值，避免触发 Pref/Hive 的惰性初始化
    VideoUtils.cdnService = CDNService.ali;
    VideoUtils.customCDNUrl = null;
    VideoUtils.disableAudioCDN = false;
  });

  group('normalizeCustomCDNHost', () {
    test('extracts host from full URL', () {
      expect(
        VideoUtils.normalizeCustomCDNHost('https://example.cdn.test/path?a=1'),
        'example.cdn.test',
      );
    });

    test('accepts bare host with surrounding spaces', () {
      expect(
        VideoUtils.normalizeCustomCDNHost(' example.cdn.test '),
        'example.cdn.test',
      );
    });

    test('rejects host with path/query and blank input', () {
      expect(VideoUtils.normalizeCustomCDNHost('example.cdn.test/'), null);
      expect(VideoUtils.normalizeCustomCDNHost('a.b/c?d=1'), null);
      expect(VideoUtils.normalizeCustomCDNHost(''), null);
      expect(VideoUtils.normalizeCustomCDNHost('   '), null);
      expect(VideoUtils.normalizeCustomCDNHost(null), null);
    });
  });

  group('getCdnUrl custom host', () {
    const mirrorUrl =
        'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/12/34/video.m4s?e=1';
    const bcacheUrl =
        'https://cn-sh-ct-01-01.bilivideo.com/upgcxcode/12/34/video.m4s?e=1';

    test('replaces mirror host with explicit custom host', () {
      expect(
        VideoUtils.getCdnUrl(
          [mirrorUrl],
          defaultCDNService: CDNService.cos,
          customHost: 'custom.cdn.test',
        ),
        'https://custom.cdn.test/upgcxcode/12/34/video.m4s?e=1',
      );
    });

    test('replaces bcache upgcxcode host with custom host', () {
      expect(
        VideoUtils.getCdnUrl(
          [bcacheUrl],
          defaultCDNService: CDNService.ali,
          customHost: 'custom.cdn.test',
        ),
        'https://custom.cdn.test/upgcxcode/12/34/video.m4s?e=1',
      );
    });

    test('global custom host bypasses baseUrl/backupUrl semantics', () {
      VideoUtils.customCDNUrl = 'custom.cdn.test';
      expect(
        VideoUtils.getCdnUrl(
          [mirrorUrl],
          defaultCDNService: CDNService.baseUrl,
        ),
        'https://custom.cdn.test/upgcxcode/12/34/video.m4s?e=1',
      );
      expect(
        VideoUtils.getCdnUrl(
          [mirrorUrl],
          defaultCDNService: CDNService.backupUrl,
        ),
        'https://custom.cdn.test/upgcxcode/12/34/video.m4s?e=1',
      );
    });

    test('applyCustomCDN: false ignores global custom host', () {
      VideoUtils.customCDNUrl = 'custom.cdn.test';
      expect(
        VideoUtils.getCdnUrl(
          [mirrorUrl],
          defaultCDNService: CDNService.cos,
          applyCustomCDN: false,
        ),
        'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/12/34/video.m4s?e=1',
      );
    });

    test('audio with disableAudioCDN ignores custom host', () {
      VideoUtils.customCDNUrl = 'custom.cdn.test';
      VideoUtils.disableAudioCDN = true;
      expect(
        VideoUtils.getCdnUrl(
          [mirrorUrl],
          defaultCDNService: CDNService.ali,
          isAudio: true,
        ),
        mirrorUrl,
      );
    });

    test('api-like urls are skipped', () {
      expect(
        VideoUtils.getCdnUrl(
          [
            'https://api.bilibili.com/x/player/playurl?cid=1',
            mirrorUrl,
          ],
          customHost: 'custom.cdn.test',
        ),
        'https://custom.cdn.test/upgcxcode/12/34/video.m4s?e=1',
      );
    });

    test('blocked-prefix host falls back to builtin replacement', () {
      expect(
        VideoUtils.getCdnUrl(
          ['https://bvc1.akamaized.net/upgcxcode/12/34/video.m4s'],
          defaultCDNService: CDNService.ali,
          customHost: 'custom.cdn.test',
        ),
        'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/12/34/video.m4s',
      );
    });

    test('forged suffix host is not replaced with custom host', () {
      expect(
        VideoUtils.getCdnUrl(
          ['https://bilivideo.evil.com/upgcxcode/12/34/video.m4s'],
          defaultCDNService: CDNService.ali,
          customHost: 'custom.cdn.test',
        ),
        'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/12/34/video.m4s',
      );
    });

    test('without custom host keeps builtin behavior', () {
      expect(
        VideoUtils.getCdnUrl([mirrorUrl], defaultCDNService: CDNService.cos),
        'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/12/34/video.m4s?e=1',
      );
      expect(
        VideoUtils.getCdnUrl(
          [mirrorUrl],
          defaultCDNService: CDNService.backupUrl,
        ),
        mirrorUrl,
      );
      expect(
        VideoUtils.getCdnUrl(
          [mirrorUrl],
          defaultCDNService: CDNService.baseUrl,
        ),
        mirrorUrl,
      );
    });
  });
}

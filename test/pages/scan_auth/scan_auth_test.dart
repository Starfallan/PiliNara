import 'dart:convert' show base64Encode, utf8;

import 'package:PiliPlus/http/scan_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// 扫码授权的内容识别：链接、裸 key、base64 图片都不能互相误判
void main() {
  // 最小的 PNG 头，够魔数判定认出来即可
  final pngBytes = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0,
  ];
  final pngPayload = base64Encode(pngBytes);
  const webUrl =
      'https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=abc123';

  test('带 data: 前缀的 base64 图片能解出字节', () {
    expect(ScanAuth.imageBytesOf('data:image/png;base64,$pngPayload'), pngBytes);
  });

  test('只有裸载荷（粘贴时前缀被截掉）也能解出字节', () {
    expect(ScanAuth.imageBytesOf(pngPayload), pngBytes);
  });

  test('载荷中间夹换行也能解出字节', () {
    final wrapped =
        '${pngPayload.substring(0, 8)}
${pngPayload.substring(8)}';
    expect(ScanAuth.imageBytesOf(wrapped), pngBytes);
  });

  test('网页链接不会被当成图片', () {
    expect(ScanAuth.imageBytesOf(webUrl), isNull);
    expect(ScanAuth.imageBytesOf('https://example.com/a.png'), isNull);
  });

  test('裸 key 不会被当成图片', () {
    expect(ScanAuth.imageBytesOf('abc123def456'), isNull);
    expect(ScanAuth.imageBytesOf('0123456789abcdef0123456789abcdef'), isNull);
  });

  test('能 base64 解码但不是图片时不算图片', () {
    // SGVsbG8= 是 Hello，解出来是文本不是图片
    expect(ScanAuth.imageBytesOf('data:text/plain;base64,SGVsbG8='), isNull);
  });

  test('链接里的 key 与类型能被解析', () {
    final parsed = ScanAuth.parse(webUrl);
    expect(parsed, isNotNull);
    expect(parsed!.$1, ScanQrType.web);
    expect(parsed.$2, 'abc123');
  });

  test('TV 端的 auth_code 能被解析', () {
    const tvUrl =
        'https://passport.bilibili.com/x/passport-tv-login/h5/qrcode/auth?auth_code=tv999';
    final parsed = ScanAuth.parse(tvUrl);
    expect(parsed, isNotNull);
    expect(parsed!.$1, ScanQrType.tv);
    expect(parsed.$2, 'tv999');
  });

  test('裸 key 解析为无类型，交由调用方决定', () {
    final parsed = ScanAuth.parse('abc123def456');
    expect(parsed, isNotNull);
    expect(parsed!.$1, isNull);
    expect(parsed.$2, 'abc123def456');
  });

  test('不是登录二维码的链接被拒绝', () {
    expect(ScanAuth.parse('https://example.com/hello'), isNull);
    expect(ScanAuth.parse(''), isNull);
  });

  test('base64 编码过的二维码文本能还原成链接', () {
    final encoded = base64Encode(utf8.encode(webUrl));
    expect(ScanAuth.decodeText(encoded), webUrl);
  });

  test('普通链接与裸 key 不会被误当成 base64 文本', () {
    expect(ScanAuth.decodeText(webUrl), isNull);
    expect(ScanAuth.decodeText('abc123def456'), isNull);
  });
}

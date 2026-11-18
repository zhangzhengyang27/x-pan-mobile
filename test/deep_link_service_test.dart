import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.extractInviteCode', () {
    test('解析自定义协议深链', () {
      expect(
        DeepLinkService.extractInviteCode(Uri.parse('xpan://join?code=abc123')),
        'ABC123',
      );
    });

    test('解析网页邀请链接', () {
      expect(
        DeepLinkService.extractInviteCode(
          Uri.parse('https://pan.example.com/join?code=HQWUXE3V'),
        ),
        'HQWUXE3V',
      );
    });

    test('忽略无关链接', () {
      expect(
        DeepLinkService.extractInviteCode(Uri.parse('xpan://other?code=ABC')),
        isNull,
      );
      expect(
        DeepLinkService.extractInviteCode(
          Uri.parse('https://pan.example.com/share/123'),
        ),
        isNull,
      );
    });
  });

  group('DeepLinkService.parseInviteInput', () {
    test('支持纯邀请码', () {
      expect(DeepLinkService.parseInviteInput(' hqwuxe3v '), 'HQWUXE3V');
    });

    test('支持完整深链与网页链接', () {
      expect(
        DeepLinkService.parseInviteInput('xpan://join?code=abc123'),
        'ABC123',
      );
      expect(
        DeepLinkService.parseInviteInput('https://x/join?code=zz99'),
        'ZZ99',
      );
    });

    test('空输入返回 null', () {
      expect(DeepLinkService.parseInviteInput('   '), isNull);
    });
  });
}

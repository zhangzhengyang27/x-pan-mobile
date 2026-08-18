import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/providers/notification_provider.dart';

void main() {
  group('NotificationThrottle（节流）', () {
    final now = DateTime(2026, 8, 17, 12, 0, 0);

    test('首次通知应推送', () {
      final throttle = NotificationThrottle();
      expect(throttle.shouldPush('system-升级', now), isTrue);
    });

    test('相同通知窗口内去重', () {
      final throttle = NotificationThrottle();
      expect(throttle.shouldPush('system-升级', now), isTrue);
      // 5 秒后相同通知应去重
      expect(
        throttle.shouldPush('system-升级', now.add(const Duration(seconds: 5))),
        isFalse,
      );
    });

    test('超过窗口后相同通知可再次推送', () {
      final throttle = NotificationThrottle();
      expect(throttle.shouldPush('system-升级', now), isTrue);
      // 11 秒后应可再次推送
      expect(
        throttle.shouldPush('system-升级', now.add(const Duration(seconds: 11))),
        isTrue,
      );
    });

    test('不同通知不节流', () {
      final throttle = NotificationThrottle();
      expect(throttle.shouldPush('system-升级', now), isTrue);
      // 不同内容不节流
      expect(
        throttle.shouldPush('upload-新文件', now.add(const Duration(seconds: 2))),
        isTrue,
      );
    });
  });
}

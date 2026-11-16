import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/services/notification_service.dart';

/// WS 韧性回归测试
///
/// 两个历史缺陷：
/// 1. 重连 8 次耗尽后永久放弃——地铁断网约 2 分钟即耗尽退避，出网后通知
///    永久失效，需手动杀 App 或重新登录；
/// 2. 心跳只发 PING 不校验服务端回包——半开连接（Wi-Fi/蜂窝切换）下
///    `_connected` 恒为 true，消息通道悄悄失效。
void main() {
  group('reconnectDelay（重连耗尽后降级为低频长周期）', () {
    test('前 8 次指数退避（1s → 30s 封顶）', () {
      expect(NotificationService.reconnectDelay(0), const Duration(milliseconds: 1000));
      expect(NotificationService.reconnectDelay(3), const Duration(milliseconds: 8000));
      expect(NotificationService.reconnectDelay(7), const Duration(milliseconds: 30000));
    });

    test('耗尽（>=8）后低频长周期重连（60s），而不是永久放弃', () {
      expect(NotificationService.reconnectDelay(8), const Duration(seconds: 60));
      expect(NotificationService.reconnectDelay(20), const Duration(seconds: 60));
    });
  });

  group('isStale（半开连接检测）', () {
    final now = DateTime(2026, 11, 16, 12, 0, 0);

    test('从未收到消息（null）不判定为半开', () {
      expect(NotificationService.isStale(null, now), isFalse);
    });

    test('两个心跳周期内收到过消息不判定为半开', () {
      expect(NotificationService.isStale(now.subtract(const Duration(seconds: 49)), now), isFalse);
    });

    test('超过两个心跳周期（>50s）无消息判定为半开', () {
      expect(NotificationService.isStale(now.subtract(const Duration(seconds: 51)), now), isTrue);
    });
  });
}

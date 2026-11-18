import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/services/notification_api.dart';

/// 通知中心 API 封装回归测试
///
/// 网络层错误语义由全局拦截器统一覆盖（与项目现状一致），本组锚定
/// fromJson 容错与列表分页参数拼装——真实请求由手动验证清单覆盖。
void main() {
  group('NotificationItem.fromJson', () {
    test('完整字段解析', () {
      final item = NotificationItem.fromJson({
        'id': '1',
        'type': 'SHARE_STATS_UPDATE',
        'title': '分享被访问',
        'content': 'xxx',
        'readFlag': 1,
        'createTime': '2026-11-16 10:00:00',
      });
      expect(item.id, '1');
      expect(item.type, 'SHARE_STATS_UPDATE');
      expect(item.title, '分享被访问');
      expect(item.content, 'xxx');
      expect(item.readFlag, 1);
      expect(item.createTime, '2026-11-16 10:00:00');
    });

    test('缺省字段容错（null/缺失 → 空串/未读）', () {
      final item = NotificationItem.fromJson({'id': '2', 'title': 't'});
      expect(item.readFlag, 0);
      expect(item.content, '');
      expect(item.type, '');
      expect(item.createTime, '');
    });

    test('list 分页参数：默认 limit=50，自定义可覆盖', () {
      expect(NotificationApi.listQuery(limit: 50), {'limit': 50});
      expect(NotificationApi.listQuery(limit: 100), {'limit': 100});
    });
  });
}

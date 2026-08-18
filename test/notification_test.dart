import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/services/notification_service.dart';

void main() {
  group('NoticeType.fromString', () {
    test('识别系统通知', () {
      expect(NoticeType.fromString('SYSTEM_NOTICE'), NoticeType.systemNotice);
    });

    test('识别上传完成', () {
      expect(NoticeType.fromString('UPLOAD_FINISHED'), NoticeType.uploadFinished);
    });

    test('识别离线任务更新', () {
      expect(NoticeType.fromString('OFFLINE_TASK_UPDATE'), NoticeType.offlineTaskUpdate);
    });

    test('未知类型', () {
      expect(NoticeType.fromString('UNKNOWN'), NoticeType.unknown);
    });
  });

  group('NoticeMessage.fromJson', () {
    test('解析系统通知消息', () {
      final msg = NoticeMessage.fromJson({
        'type': 'SYSTEM_NOTICE',
        'payload': {'level': 'warning', 'message': '系统升级'},
        'ts': 1234567890,
      });
      expect(msg.type, NoticeType.systemNotice);
      expect(msg.payload['message'], '系统升级');
      expect(msg.ts, 1234567890);
    });

    test('payload 为空', () {
      final msg = NoticeMessage.fromJson({'type': 'PING', 'ts': 0});
      expect(msg.type, NoticeType.ping);
      expect(msg.payload, isNull);
    });
  });
}

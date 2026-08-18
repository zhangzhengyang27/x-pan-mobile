import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/token_storage.dart';
import '../services/local_notification_service.dart';
import '../services/notification_service.dart';

/// 通知项（用于通知中心展示）
class AppNotice {
  const AppNotice({
    required this.title,
    required this.message,
    required this.level,
    required this.time,
    required this.type,
  });

  final String title;
  final String message;
  final String level; // info / success / warning / error
  final String time;
  final NoticeType type;
}

/// 通知状态
class NotificationState {
  const NotificationState({
    this.notices = const [],
    this.connected = false,
  });

  final List<AppNotice> notices;
  final bool connected;

  NotificationState copyWith({
    List<AppNotice>? notices,
    bool? connected,
  }) {
    return NotificationState(
      notices: notices ?? this.notices,
      connected: connected ?? this.connected,
    );
  }
}

/// 通知管理器
///
/// 建立 WebSocket 连接，将实时消息转为通知列表。
class NotificationManager extends StateNotifier<NotificationState> {
  NotificationManager() : super(const NotificationState());

  bool _started = false;

  /// 节流：相同通知 10s 内只推一次系统通知，避免刷屏
  final NotificationThrottle _throttle = NotificationThrottle();

  /// 启动（登录后调用）
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final token = await TokenStorage.getToken();
    if (token.isEmpty) return;

    final service = NotificationService.instance;
    service.onMessage = _handleMessage;
    service.onConnectionChanged = (connected) {
      state = state.copyWith(connected: connected);
    };
    service.connect(token);
  }

  /// 停止并复位（登出时由 auth 层调用，使 [start] 可再次生效）
  void stop() {
    _started = false;
    NotificationService.instance.disconnect();
    NotificationService.instance.reset();
    state = const NotificationState();
  }

  void _handleMessage(NoticeMessage message) {
    AppNotice notice;
    switch (message.type) {
      case NoticeType.systemNotice:
        final payload = message.payload;
        final level = payload is Map ? (payload['level'] ?? 'info').toString() : 'info';
        final msg = payload is Map ? (payload['message'] ?? '').toString() : '';
        notice = AppNotice(
          title: '系统通知',
          message: msg,
          level: level,
          time: _now(),
          type: message.type,
        );
      case NoticeType.uploadFinished:
        final filename = message.payload is Map
            ? (message.payload['filename'] ?? '').toString()
            : '';
        notice = AppNotice(
          title: '上传完成',
          message: filename.isEmpty ? '文件已上传' : filename,
          level: 'success',
          time: _now(),
          type: message.type,
        );
      case NoticeType.offlineTaskUpdate:
        notice = AppNotice(
          title: '离线下载更新',
          message: _payloadDesc(message.payload),
          level: 'info',
          time: _now(),
          type: message.type,
        );
      case NoticeType.offlineTaskRemoved:
        notice = AppNotice(
          title: '离线任务移除',
          message: _payloadDesc(message.payload),
          level: 'warning',
          time: _now(),
          type: message.type,
        );
      case NoticeType.shareStatsUpdate:
        notice = AppNotice(
          title: '分享动态',
          message: _payloadDesc(message.payload),
          level: 'info',
          time: _now(),
          type: message.type,
        );
      default:
        return;
    }

    state = state.copyWith(notices: [notice, ...state.notices].take(50).toList());

    // 触发系统级本地通知（后台推送提醒），相同通知 10s 内去重
    final now = DateTime.now();
    final pushKey = '${notice.type}-${notice.message}';
    if (!shouldPushNotice(pushKey, now)) return;

    unawaited(
      LocalNotificationService.instance.show(
        id: '${notice.type}-${now.millisecondsSinceEpoch}',
        title: notice.title,
        body: notice.message,
      ),
    );
  }

  /// 节流判断：相同通知 10s 内不重复推送
  bool shouldPushNotice(String pushKey, DateTime now) {
    return _throttle.shouldPush(pushKey, now);
  }

  String _payloadDesc(dynamic payload) {
    if (payload is Map) {
      final filename = payload['filename'] ?? payload['fileName'] ?? '';
      final status = payload['status'] ?? '';
      final statusText = payload['statusText'] ?? '';
      return [filename.toString(), statusText.toString()]
          .where((s) => s.isNotEmpty)
          .join(' · ');
    }
    return payload?.toString() ?? '';
  }

  String _now() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 清空通知
  void clear() {
    state = state.copyWith(notices: const []);
  }

  /// 测试辅助：注入一条通知（仅测试用）
  @visibleForTesting
  void testInjectNotice(String title, String message, String level) {
    state = state.copyWith(
      notices: [
        AppNotice(
          title: title,
          message: message,
          level: level,
          time: '12:00',
          type: NoticeType.systemNotice,
        ),
        ...state.notices,
      ],
    );
  }

  @override
  void dispose() {
    NotificationService.instance.disconnect();
    super.dispose();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationManager, NotificationState>((ref) {
  return NotificationManager();
});

/// 通知推送节流器：相同通知在窗口期内不重复推送（纯逻辑，便于测试）
class NotificationThrottle {
  NotificationThrottle({
    this.window = const Duration(seconds: 10),
  });

  /// 去重窗口
  final Duration window;

  String _lastKey = '';
  DateTime _lastTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// 判断是否应推送；相同 key 在窗口内返回 false
  bool shouldPush(String key, DateTime now) {
    if (key == _lastKey && now.difference(_lastTime) < window) {
      return false;
    }
    _lastKey = key;
    _lastTime = now;
    return true;
  }
}

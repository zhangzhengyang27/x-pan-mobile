import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';

/// 通知消息类型（对齐后端 WsMessageType）
enum NoticeType {
  connected,
  ping,
  pong,
  offlineTaskUpdate,
  offlineTaskRemoved,
  shareStatsUpdate,
  uploadFinished,
  systemNotice,
  unknown;

  static NoticeType fromString(String s) {
    switch (s) {
      case 'CONNECTED':
        return NoticeType.connected;
      case 'PING':
        return NoticeType.ping;
      case 'PONG':
        return NoticeType.pong;
      case 'OFFLINE_TASK_UPDATE':
        return NoticeType.offlineTaskUpdate;
      case 'OFFLINE_TASK_REMOVED':
        return NoticeType.offlineTaskRemoved;
      case 'SHARE_STATS_UPDATE':
        return NoticeType.shareStatsUpdate;
      case 'UPLOAD_FINISHED':
        return NoticeType.uploadFinished;
      case 'SYSTEM_NOTICE':
        return NoticeType.systemNotice;
      default:
        return NoticeType.unknown;
    }
  }
}

/// 通知消息
class NoticeMessage {
  const NoticeMessage({
    required this.type,
    this.payload,
    this.ts = 0,
  });

  final NoticeType type;
  final dynamic payload;
  final int ts;

  factory NoticeMessage.fromJson(Map<String, dynamic> json) {
    return NoticeMessage(
      type: NoticeType.fromString(json['type'] as String? ?? ''),
      payload: json['payload'],
      ts: json['ts'] as int? ?? 0,
    );
  }
}

/// WebSocket 实时通知服务
///
/// 对齐后端 /ws/notification 协议 + 前端 useWebSocket：
/// - 连接：ws://host:port/ws/notification?token=xxx
/// - 心跳：服务端 30s ping，客户端 25s 回 PONG
/// - 自动重连（指数退避，最多 8 次）
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  bool _disposed = false;
  bool _connected = false;
  bool get isConnected => _connected;

  /// 通知回调（type -> message）
  void Function(NoticeMessage message)? onMessage;

  /// 连接状态变化回调
  void Function(bool connected)? onConnectionChanged;

  /// 从 API base URL 推导 WS URL（http -> ws, https -> wss）
  ///
  /// 复用后端 host 与端口；默认端口（80/443）省略，避免冗余。
  String _buildWsUrl(String token) {
    final uri = Uri.parse(AppConfig.apiBaseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final host = uri.host;
    // 默认端口省略
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://$host$port/ws/notification?token=${Uri.encodeComponent(token)}';
  }

  void connect(String token) {
    if (token.isEmpty) return;
    if (_disposed) return;
    if (_channel != null && _connected) return;

    final url = _buildWsUrl(token);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _subscription = _channel!.stream.listen(
        _onData,
        onError: (_) => _onClose(),
        onDone: _onClose,
      );

      // 连接建立后（首条消息或直接认为已连接）
      _connected = true;
      _reconnectAttempts = 0;
      onConnectionChanged?.call(true);
      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final msg = NoticeMessage.fromJson(map);
      if (msg.type == NoticeType.ping) {
        // 收到服务端 ping，回 PONG
        send(jsonEncode({'type': 'PONG', 'ts': DateTime.now().millisecondsSinceEpoch}));
        return;
      }
      onMessage?.call(msg);
    } catch (_) {
      // 忽略解析失败
    }
  }

  void _onClose() {
    _connected = false;
    onConnectionChanged?.call(false);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    // 非主动断开时自动重连
    if (!_disposed) {
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => send(jsonEncode({'type': 'PING', 'ts': DateTime.now().millisecondsSinceEpoch})),
    );
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectAttempts >= 8) return;
    final delay = (1000 * (1 << _reconnectAttempts)).clamp(1000, 30000);
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _reconnectTimer = null;
      // 重连时刷新 token（可能已续期）
      TokenStorage.getToken().then((token) {
        if (token.isNotEmpty && !_disposed) {
          connect(token);
        }
      });
    });
  }

  void send(String data) {
    try {
      _channel?.sink.add(data);
    } catch (_) {
      // 忽略发送失败
    }
  }

  void disconnect() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {
      // 忽略
    }
    _channel = null;
    _connected = false;
    onConnectionChanged?.call(false);
  }

  /// 复位（重新登录后可再次 connect）
  void reset() {
    _disposed = false;
    _reconnectAttempts = 0;
  }
}

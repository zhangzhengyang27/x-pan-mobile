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
  chatNew,
  chatRead,
  chatRecall,
  chatFriendApply,
  chatGroupInvite,
  chatGroupDismissed,
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
      case 'CHAT_NEW':
        return NoticeType.chatNew;
      case 'CHAT_READ':
        return NoticeType.chatRead;
      case 'CHAT_RECALL':
        return NoticeType.chatRecall;
      case 'CHAT_FRIEND_APPLY':
        return NoticeType.chatFriendApply;
      case 'CHAT_GROUP_INVITE':
        return NoticeType.chatGroupInvite;
      case 'CHAT_GROUP_DISMISSED':
        return NoticeType.chatGroupDismissed;
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

  /// 连接代次：每次发起 connect 递增，使仍在握手中的旧连接流程失效，
  /// 避免旧的 await 完成后重复置状态 / 重复调度重连。
  int _epoch = 0;

  bool _disposed = false;
  bool _connected = false;
  bool get isConnected => _connected;

  /// 是否已被主动断开（登出后为 true，需 [reset] 后才能再次连接）
  bool get isDisposed => _disposed;

  /// 通知回调（type -> message）
  void Function(NoticeMessage message)? onMessage;

  /// 聊天事件回调（CHAT_*；与 onMessage 并行，互不影响）
  void Function(NoticeMessage message)? onChatMessage;

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

  /// 建立连接
  ///
  /// [WebSocketChannel.connect] 非阻塞立即返回，握手结果由 [WebSocketChannel.ready]
  /// 异步给出：等待 ready 成功后才置 _connected / 清零重连计数 / 启动心跳，
  /// 失败（握手失败、网络不通）走指数退避重连，避免退避被提前清零而失效。
  Future<void> connect(String token) async {
    if (token.isEmpty) return;
    if (_disposed) return;
    if (_connected) return;

    // 递增代次，使仍在握手中的旧连接流程失效（幂等守卫）
    final epoch = ++_epoch;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final channel = WebSocketChannel.connect(Uri.parse(_buildWsUrl(token)));
    _channel = channel;
    try {
      // 等待握手真正建立；连接失败/超时由 ready 抛出
      await channel.ready.timeout(const Duration(seconds: 15));
    } catch (_) {
      if (epoch != _epoch) return; // 已被新的连接取代
      _channel = null;
      _scheduleReconnect();
      return;
    }

    if (epoch != _epoch) {
      // 握手期间发生了新的 connect / disconnect，废弃本次连接
      try {
        await channel.sink.close();
      } catch (_) {
        // 忽略
      }
      return;
    }

    // 连接确认建立后才置状态并启动心跳
    _connected = true;
    _reconnectAttempts = 0;
    onConnectionChanged?.call(true);
    _subscription = channel.stream.listen(
      _onData,
      onError: (_) => _onClose(),
      onDone: _onClose,
    );
    _startHeartbeat();
  }

  void _onData(dynamic raw) {
    _lastServerActivity = DateTime.now();
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final msg = NoticeMessage.fromJson(map);
      if (msg.type == NoticeType.ping) {
        // 收到服务端 ping，回 PONG
        send(jsonEncode({'type': 'PONG', 'ts': DateTime.now().millisecondsSinceEpoch}));
        return;
      }
      onMessage?.call(msg);
      // 聊天事件并行通道：onMessage 单槽被通知 Provider 占用，聊天 Provider 独立挂载
      if (msg.type == NoticeType.chatNew ||
          msg.type == NoticeType.chatRead ||
          msg.type == NoticeType.chatRecall ||
          msg.type == NoticeType.chatFriendApply ||
          msg.type == NoticeType.chatGroupInvite ||
          msg.type == NoticeType.chatGroupDismissed) {
        onChatMessage?.call(msg);
      }
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

  DateTime? _lastServerActivity;

  void _startHeartbeat() {
    _lastServerActivity = DateTime.now();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      // 半开连接检测：两个心跳周期内没有任何服务端消息（含 PONG/ping），
      // 本地 TCP 仍在但对端已失联——主动关闭触发重连，而不是继续空转
      if (isStale(_lastServerActivity, DateTime.now())) {
        try {
          _channel?.sink.close();
        } catch (_) {
          // 忽略关闭异常（onDone/onError 会走重连）
        }
        return;
      }
      send(jsonEncode({'type': 'PING', 'ts': DateTime.now().millisecondsSinceEpoch}));
    });
  }

  /// 重连延迟：前 8 次指数退避（1s → 30s 封顶）；耗尽后降级为 60s 低频长周期。
  /// 旧实现耗尽即永久放弃——地铁断网约 2 分钟即耗尽，出网后通知永久失效，
  /// 需手动杀 App 或重新登录才能恢复。
  static Duration reconnectDelay(int attempts) {
    if (attempts >= 8) {
      return const Duration(seconds: 60);
    }
    return Duration(milliseconds: (1000 * (1 << attempts)).clamp(1000, 30000));
  }

  /// 半开连接判定：超过两个心跳周期（心跳 25s × 2 = 50s）未收到服务端任何消息。
  /// 旧实现只发 PING 不校验回包——半开连接下 _connected 恒为 true，消息通道悄悄失效。
  static bool isStale(DateTime? lastServerActivity, DateTime now) {
    if (lastServerActivity == null) return false;
    return now.difference(lastServerActivity) > const Duration(seconds: 50);
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    final delay = reconnectDelay(_reconnectAttempts);
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      // 重连时刷新 token（可能已续期）
      TokenStorage.getToken().then((token) {
        if (token.isNotEmpty && !_disposed) {
          unawaited(connect(token));
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
    _epoch++; // 使仍在握手中的 connect 流程失效
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

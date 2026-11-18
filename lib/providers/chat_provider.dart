import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_vo.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

/// 会话状态（列表 + 消息缓存 + 未读聚合 + WS 事件接入）
class ChatState {
  const ChatState({
    this.conversations = const [],
    this.friends = const [],
    this.applies = const [],
    this.messagesByConv = const {},
    this.loaded = false,
  });

  final List<ChatConversationVO> conversations;
  final List<ChatFriendVO> friends;
  final List<ChatFriendApplyVO> applies;
  /// 已打开会话的消息缓存（升序；WS 实时追加）
  final Map<int, List<ChatMessageVO>> messagesByConv;
  final bool loaded;

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + (c.unread > 0 ? c.unread : 0));

  ChatState copyWith({
    List<ChatConversationVO>? conversations,
    List<ChatFriendVO>? friends,
    List<ChatFriendApplyVO>? applies,
    Map<int, List<ChatMessageVO>>? messagesByConv,
    bool? loaded,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      friends: friends ?? this.friends,
      applies: applies ?? this.applies,
      messagesByConv: messagesByConv ?? this.messagesByConv,
      loaded: loaded ?? this.loaded,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(const ChatState()) {
    NotificationService.instance.onChatMessage = _onWsMessage;
  }

  final Ref _ref;
  final ChatService _service = ChatService.instance;

  /// 当前打开的详情页会话（用于 WS 新消息自动已读）
  int? _activeDetailConversationId;

  void setActiveDetail(int? conversationId) {
    _activeDetailConversationId = conversationId;
    if (conversationId != null) _markReadToMax(conversationId);
  }

  String get _currentUsername =>
      _ref.read(authProvider).user?.username ?? '';

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _service.conversations(),
        _service.friends(),
        _service.friendApplies(),
      ]);
      state = state.copyWith(
        conversations: results[0] as List<ChatConversationVO>,
        friends: results[1] as List<ChatFriendVO>,
        applies: results[2] as List<ChatFriendApplyVO>,
        loaded: true,
      );
    } catch (_) {
      // 静默失败：下拉刷新可重试
    }
  }

  /// 首屏加载某会话消息（已有缓存则 afterSeq 增量）
  Future<void> loadMessages(int conversationId) async {
    final cached = state.messagesByConv[conversationId];
    if (cached == null) {
      // 占位空条目：空会话也视为已加载，避免详情页永久 loading
      state = state.copyWith(
          messagesByConv: {
            ...state.messagesByConv,
            conversationId: <ChatMessageVO>[]
          });
    }
    try {
      List<ChatMessageVO> fetched;
      if (cached != null && cached.isNotEmpty) {
        fetched = await _service.messages(conversationId,
            afterSeq: cached.last.seq);
      } else {
        fetched = await _service.messages(conversationId, limit: 50);
      }
      _appendMessages(conversationId, fetched);
      await _markReadToMax(conversationId);
    } catch (_) {
      // 保留旧缓存
    }
  }

  void _appendMessages(int conversationId, List<ChatMessageVO> incoming) {
    if (incoming.isEmpty) return;
    final map = Map<int, List<ChatMessageVO>>.from(state.messagesByConv);
    final list = <ChatMessageVO>[...(map[conversationId] ?? const <ChatMessageVO>[])];
    final seen = list.map((m) => m.id).toSet();
    for (final message in incoming) {
      if (!seen.contains(message.id)) list.add(message);
    }
    list.sort((a, b) => a.seq.compareTo(b.seq));
    map[conversationId] = list;
    state = state.copyWith(messagesByConv: map);
  }

  void _markRecalled(int conversationId, int messageId) {
    final map = Map<int, List<ChatMessageVO>>.from(state.messagesByConv);
    final list = map[conversationId];
    if (list == null) return;
    map[conversationId] = list
        .map((m) => m.id == messageId ? m.copyWith(status: 'RECALLED') : m)
        .toList();
    state = state.copyWith(messagesByConv: map);
  }

  Future<void> _markReadToMax(int conversationId) async {
    final conv = state.conversations
        .where((c) => c.conversationId == conversationId)
        .toList();
    if (conv.isEmpty) return;
    final target = state.messagesByConv[conversationId]?.isEmpty ?? true
        ? conv.first.maxSeq
        : state.messagesByConv[conversationId]!.last.seq;
    if (conv.first.lastReadSeq >= target) return;
    try {
      await _service.markRead(conversationId, target);
      final updated = state.conversations
          .map((c) => c.conversationId == conversationId
              ? ChatConversationVO(
                  conversationId: c.conversationId,
                  type: c.type,
                  groupName: c.groupName,
                  displayName: c.displayName,
                  peerUserId: c.peerUserId,
                  peerOnline: c.peerOnline,
                  lastMsgPreview: c.lastMsgPreview,
                  maxSeq: c.maxSeq,
                  lastReadSeq: target,
                  unread: c.maxSeq > target ? c.maxSeq - target : 0,
                  role: c.role,
                )
              : c)
          .toList();
      state = state.copyWith(conversations: updated);
    } catch (_) {
      // 已读失败不阻塞
    }
  }

  /// 发送后由调用方 append 返回的消息；WS 事件去重兜底
  Future<void> send(int conversationId, String msgType,
      {String? content, String? fileId, int? mediaId}) async {
    final message = await _service.sendMessage(conversationId, msgType,
        content: content, fileId: fileId, mediaId: mediaId);
    _appendMessages(conversationId, [message]);
  }

  Future<void> recall(ChatMessageVO message) async {
    await _service.recallMessage(message.id);
    _markRecalled(message.conversationId, message.id);
  }

  Future<void> forward(ChatMessageVO message, List<int> targetIds) async {
    await _service.forwardMessage(message.id, targetIds);
  }

  void _onWsMessage(NoticeMessage message) {
    switch (message.type) {
      case NoticeType.chatNew:
        _onNewMessage(message.payload as Map<String, dynamic>?);
        break;
      case NoticeType.chatRecall:
        final payload = message.payload as Map<String, dynamic>? ?? {};
        final conversationId = (payload['conversationId'] as num?)?.toInt();
        final messageId = (payload['messageId'] as num?)?.toInt();
        if (conversationId != null && messageId != null) {
          _markRecalled(conversationId, messageId);
        }
        refresh();
        break;
      case NoticeType.chatFriendApply:
      case NoticeType.chatGroupInvite:
      case NoticeType.chatGroupDismissed:
      case NoticeType.chatRead:
        refresh();
        break;
      default:
        break;
    }
  }

  void _onNewMessage(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final message = ChatMessageVO.fromJson(payload);
    final isOpen = state.messagesByConv.containsKey(message.conversationId);
    if (isOpen) {
      _appendMessages(message.conversationId, [message]);
      if (message.conversationId == _activeDetailConversationId &&
          message.senderUsername != _currentUsername) {
        _markReadToMax(message.conversationId);
      }
    }

    final list = [...state.conversations];
    final index =
        list.indexWhere((c) => c.conversationId == message.conversationId);
    if (index < 0) {
      refresh();
      return;
    }
    final conv = list[index];
    final senderIsMe = message.senderUsername == _currentUsername;
    final newUnread = senderIsMe ? conv.unread : conv.unread + 1;
    list[index] = conv.copyWith(
      maxSeq: message.seq,
      unread: newUnread,
      lastMsgPreview: _preview(message),
    );
    list.sort((a, b) => b.maxSeq.compareTo(a.maxSeq));
    state = state.copyWith(conversations: list);
  }

  String _preview(ChatMessageVO message) {
    switch (message.msgType) {
      case 'IMAGE':
        return '[图片]';
      case 'VOICE':
        return '[语音]';
      case 'FILE_CARD':
        return '[文件] ${message.fileCardName}';
      default:
        return message.content;
    }
  }
}

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));

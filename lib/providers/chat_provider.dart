import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_vo.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

/// 会话状态（列表 + 未读聚合 + WS 事件接入）
class ChatState {
  const ChatState({
    this.conversations = const [],
    this.friends = const [],
    this.applies = const [],
    this.loaded = false,
  });

  final List<ChatConversationVO> conversations;
  final List<ChatFriendVO> friends;
  final List<ChatFriendApplyVO> applies;
  final bool loaded;

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + (c.unread > 0 ? c.unread : 0));

  ChatState copyWith({
    List<ChatConversationVO>? conversations,
    List<ChatFriendVO>? friends,
    List<ChatFriendApplyVO>? applies,
    bool? loaded,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      friends: friends ?? this.friends,
      applies: applies ?? this.applies,
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

  void _onWsMessage(NoticeMessage message) {
    switch (message.type) {
      case NoticeType.chatNew:
        _onNewMessage(message.payload as Map<String, dynamic>?);
        break;
      case NoticeType.chatFriendApply:
      case NoticeType.chatGroupInvite:
      case NoticeType.chatGroupDismissed:
      case NoticeType.chatRead:
      case NoticeType.chatRecall:
        refresh();
        break;
      default:
        break;
    }
  }

  void _onNewMessage(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final message = ChatMessageVO.fromJson(payload);
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
    list.sort((a, b) => b.unread.compareTo(a.unread));
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

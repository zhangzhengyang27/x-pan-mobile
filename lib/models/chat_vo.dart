/// 站内 IM 模型（对齐后端 chat 模块 VO）
class ChatConversationVO {
  final int conversationId;
  final String type; // DIRECT / GROUP
  final String groupName;
  final String displayName;
  final String peerUserId;
  final bool peerOnline;
  final String lastMsgPreview;
  final int maxSeq;
  final int lastReadSeq;
  final int unread;
  final String role; // OWNER / MEMBER

  const ChatConversationVO({
    required this.conversationId,
    required this.type,
    required this.groupName,
    required this.displayName,
    required this.peerUserId,
    required this.peerOnline,
    required this.lastMsgPreview,
    required this.maxSeq,
    required this.lastReadSeq,
    required this.unread,
    required this.role,
  });

  factory ChatConversationVO.fromJson(Map<String, dynamic> json) {
    return ChatConversationVO(
      conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'DIRECT',
      groupName: json['groupName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      peerUserId: json['peerUserId'] as String? ?? '',
      peerOnline: json['peerOnline'] as bool? ?? false,
      lastMsgPreview: json['lastMsgPreview'] as String? ?? '',
      maxSeq: (json['maxSeq'] as num?)?.toInt() ?? 0,
      lastReadSeq: (json['lastReadSeq'] as num?)?.toInt() ?? 0,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      role: json['role'] as String? ?? 'MEMBER',
    );
  }

  ChatConversationVO copyWith({int? unread, int? maxSeq, String? lastMsgPreview}) {
    return ChatConversationVO(
      conversationId: conversationId,
      type: type,
      groupName: groupName,
      displayName: displayName,
      peerUserId: peerUserId,
      peerOnline: peerOnline,
      lastMsgPreview: lastMsgPreview ?? this.lastMsgPreview,
      maxSeq: maxSeq ?? this.maxSeq,
      lastReadSeq: lastReadSeq,
      unread: unread ?? this.unread,
      role: role,
    );
  }
}

class ChatMessageVO {
  final int id;
  final int conversationId;
  final int seq;
  final String senderId;
  final String senderUsername;
  final String msgType; // TEXT / IMAGE / FILE_CARD / VOICE / SYSTEM
  final String content;
  final String fileId;
  final String fileCardName;
  final int fileCardSize;
  final int mediaId;
  final String status; // SENT / RECALLED
  final bool recallable;
  final String createTime;

  const ChatMessageVO({
    required this.id,
    required this.conversationId,
    required this.seq,
    required this.senderId,
    required this.senderUsername,
    required this.msgType,
    required this.content,
    required this.fileId,
    required this.fileCardName,
    required this.fileCardSize,
    required this.mediaId,
    required this.status,
    required this.recallable,
    required this.createTime,
  });

  factory ChatMessageVO.fromJson(Map<String, dynamic> json) {
    return ChatMessageVO(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      senderId: json['senderId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? '',
      msgType: json['msgType'] as String? ?? 'TEXT',
      content: json['content'] as String? ?? '',
      fileId: json['fileId'] as String? ?? '',
      fileCardName: json['fileCardName'] as String? ?? '',
      fileCardSize: (json['fileCardSize'] as num?)?.toInt() ?? 0,
      mediaId: (json['mediaId'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'SENT',
      recallable: json['recallable'] as bool? ?? false,
      createTime: json['createTime'] as String? ?? '',
    );
  }

  ChatMessageVO copyWith({String? status}) {
    return ChatMessageVO(
      id: id,
      conversationId: conversationId,
      seq: seq,
      senderId: senderId,
      senderUsername: senderUsername,
      msgType: msgType,
      content: content,
      fileId: fileId,
      fileCardName: fileCardName,
      fileCardSize: fileCardSize,
      mediaId: mediaId,
      status: status ?? this.status,
      recallable: recallable,
      createTime: createTime,
    );
  }
}

class ChatFriendVO {
  final String friendUserId;
  final String username;
  final String remark;
  final bool online;

  const ChatFriendVO({
    required this.friendUserId,
    required this.username,
    required this.remark,
    required this.online,
  });

  factory ChatFriendVO.fromJson(Map<String, dynamic> json) {
    return ChatFriendVO(
      friendUserId: json['friendUserId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      remark: json['remark'] as String? ?? '',
      online: json['online'] as bool? ?? false,
    );
  }
}

class ChatFriendApplyVO {
  final int id;
  final String fromUserId;
  final String fromUsername;
  final String applyMessage;
  final String createTime;

  const ChatFriendApplyVO({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.applyMessage,
    required this.createTime,
  });

  factory ChatFriendApplyVO.fromJson(Map<String, dynamic> json) {
    return ChatFriendApplyVO(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fromUserId: json['fromUserId'] as String? ?? '',
      fromUsername: json['fromUsername'] as String? ?? '',
      applyMessage: json['applyMessage'] as String? ?? '',
      createTime: json['createTime'] as String? ?? '',
    );
  }
}

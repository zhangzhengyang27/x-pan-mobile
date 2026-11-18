import 'package:dio/dio.dart';

import '../core/network/http_client.dart';
import '../models/chat_vo.dart';

/// 站内 IM API
class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final HttpClient _http = HttpClient.instance;
  Dio get _dio => HttpClient.instance.dio;

  Future<List<ChatConversationVO>> conversations() {
    return _http.request<List<ChatConversationVO>>('/chat/conversations',
        dataDecoder: (json) => (json as List<dynamic>)
            .map((e) => ChatConversationVO.fromJson(e as Map<String, dynamic>))
            .toList());
  }

  Future<ChatConversationVO> directConversation(String peerUserId) {
    return _http.request<ChatConversationVO>('/chat/conversations/direct/$peerUserId',
        dataDecoder: (json) => ChatConversationVO.fromJson(json as Map<String, dynamic>));
  }

  Future<ChatConversationVO> createGroup(
      String groupName, List<String> memberUserIds) {
    return _http.request<ChatConversationVO>('/chat/conversations/group',
        method: 'POST',
        data: {'groupName': groupName, 'memberUserIds': memberUserIds},
        dataDecoder: (json) => ChatConversationVO.fromJson(json as Map<String, dynamic>));
  }

  Future<List<ChatMessageVO>> messages(int conversationId,
      {int? afterSeq, int? beforeSeq, int? limit}) {
    return _http.request<List<ChatMessageVO>>('/chat/messages',
        query: {
          'conversationId': conversationId,
          if (afterSeq != null) 'afterSeq': afterSeq,
          if (beforeSeq != null) 'beforeSeq': beforeSeq,
          if (limit != null) 'limit': limit,
        },
        dataDecoder: (json) => (json as List<dynamic>)
            .map((e) => ChatMessageVO.fromJson(e as Map<String, dynamic>))
            .toList());
  }

  Future<ChatMessageVO> sendMessage(int conversationId, String msgType,
      {String? content, String? fileId, int? mediaId}) {
    return _http.request<ChatMessageVO>('/chat/messages',
        method: 'POST',
        data: {
          'conversationId': conversationId,
          'msgType': msgType,
          if (content != null) 'content': content,
          if (fileId != null) 'fileId': fileId,
          if (mediaId != null) 'mediaId': mediaId,
        },
        dataDecoder: (json) => ChatMessageVO.fromJson(json as Map<String, dynamic>));
  }

  Future<void> markRead(int conversationId, int seq) {
    return _http.request<dynamic>('/chat/conversations/$conversationId/read',
        method: 'PUT', data: {'seq': seq});
  }

  Future<void> recallMessage(int messageId) {
    return _http.request<dynamic>('/chat/messages/$messageId/recall', method: 'PUT');
  }

  Future<void> forwardMessage(int messageId, List<int> targetConversationIds) {
    return _http.request<dynamic>('/chat/messages/forward',
        method: 'POST', data: {'messageId': messageId, 'targetConversationIds': targetConversationIds});
  }

  Future<List<ChatFriendVO>> friends() {
    return _http.request<List<ChatFriendVO>>('/chat/friend/list',
        dataDecoder: (json) => (json as List<dynamic>)
            .map((e) => ChatFriendVO.fromJson(e as Map<String, dynamic>))
            .toList());
  }

  Future<List<ChatFriendApplyVO>> friendApplies() {
    return _http.request<List<ChatFriendApplyVO>>('/chat/friend/applies',
        dataDecoder: (json) => (json as List<dynamic>)
            .map((e) => ChatFriendApplyVO.fromJson(e as Map<String, dynamic>))
            .toList());
  }

  Future<void> applyFriend(String targetUserId, String applyMessage) {
    return _http.request<dynamic>('/chat/friend/apply',
        method: 'POST',
        data: {'targetUserId': targetUserId, 'applyMessage': applyMessage});
  }

  Future<void> acceptFriendApply(int id) {
    return _http.request<dynamic>('/chat/friend/applies/$id/accept', method: 'PUT');
  }

  Future<void> rejectFriendApply(int id) {
    return _http.request<dynamic>('/chat/friend/applies/$id/reject', method: 'PUT');
  }

  Future<void> deleteFriend(String friendUserId) {
    return _http.request<dynamic>('/chat/friend/$friendUserId', method: 'DELETE');
  }

  Future<void> setFriendRemark(String friendUserId, String remark) {
    return _http.request<dynamic>('/chat/friend/$friendUserId/remark',
        method: 'PUT', data: {'remark': remark});
  }

  Future<List<ChatFriendVO>> groupMembers(int groupId) {
    return _http.request<List<ChatFriendVO>>('/chat/groups/$groupId/members',
        dataDecoder: (json) => (json as List<dynamic>)
            .map((e) => ChatFriendVO.fromJson({
                  'friendUserId': (e as Map<String, dynamic>)['userId'] ?? '',
                  'username': e['username'] ?? '',
                  'remark': e['username'] ?? '',
                  'online': e['online'] ?? false,
                }))
            .toList());
  }

  Future<void> addGroupMembers(int groupId, List<String> userIds) {
    return _http.request<dynamic>('/chat/groups/$groupId/members',
        method: 'POST', data: {'userIds': userIds});
  }

  Future<void> kickGroupMember(int groupId, String userId) {
    return _http.request<dynamic>('/chat/groups/$groupId/members/$userId', method: 'DELETE');
  }

  Future<void> exitGroup(int groupId) {
    return _http.request<dynamic>('/chat/groups/$groupId/exit', method: 'PUT');
  }

  Future<void> dismissGroup(int groupId) {
    return _http.request<dynamic>('/chat/groups/$groupId/dismiss', method: 'PUT');
  }

  /// 上传聊天媒体（图片/语音），返回 mediaId
  /// [mediaType] IMAGE/VOICE；VOICE 必须传 durationMs（后端 60s 上限校验）
  Future<int> uploadMedia(MultipartFile file,
      {required String mediaType, int? durationMs}) async {
    final response = await _dio.request<dynamic>('/chat/media',
        data: FormData.fromMap({
          'file': file,
          'mediaType': mediaType,
          if (durationMs != null) 'durationMs': durationMs,
        }),
        options: Options(method: 'POST'));
    final map = response.data as Map<String, dynamic>;
    if (map['code'] == 10) {
      // token 失效：与统一错误处理同款广播，避免停留"已登录"假态
      HttpClient.notifyNeedRelogin();
      throw Exception('登录已失效，请重新登录');
    }
    if (map['code'] != 0) {
      throw Exception(map['message'] ?? '媒体上传失败');
    }
    return ((map['data'] as Map<String, dynamic>)['mediaId'] as num).toInt();
  }

  /// 文件卡片转存到我的网盘根目录（服务端跨用户 copy，校验配额）
  Future<void> saveFileCard(int messageId) {
    return _http.request<dynamic>('/chat/messages/$messageId/save', method: 'POST');
  }
}

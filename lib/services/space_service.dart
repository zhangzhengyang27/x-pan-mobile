import '../core/network/http_client.dart';
import '../models/space_info.dart';
import '../models/space_member.dart';

/// 团队空间 API，对齐后端 /space/*
class SpaceService {
  SpaceService._();

  static final SpaceService instance = SpaceService._();

  final HttpClient _http = HttpClient.instance;

  /// 可访问空间列表（个人空间 + 团队空间）
  Future<List<SpaceInfo>> list() {
    return _http.request<List<SpaceInfo>>(
      '/space/list',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => SpaceInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 邀请码预览（匿名可访问）
  Future<SpaceInvitePreview> previewInvite(String inviteCode) {
    return _http.request<SpaceInvitePreview>(
      '/space/invite/$inviteCode',
      dataDecoder: (json) =>
          SpaceInvitePreview.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 通过邀请码加入空间
  Future<SpaceInfo> join(String inviteCode) {
    return _http.request<SpaceInfo>(
      '/space/join',
      method: 'POST',
      data: {'inviteCode': inviteCode},
      dataDecoder: (json) => SpaceInfo.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 创建团队空间
  Future<SpaceInfo> createTeam(String spaceName) {
    return _http.request<SpaceInfo>(
      '/space/team',
      method: 'POST',
      data: {'spaceName': spaceName},
      dataDecoder: (json) => SpaceInfo.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 成员列表
  Future<List<SpaceMemberInfo>> listMembers(String spaceId) {
    return _http.request<List<SpaceMemberInfo>>(
      '/space/team/$spaceId/members',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => SpaceMemberInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 创建邀请
  Future<SpaceInviteInfo> createInvite(
    String spaceId, {
    int expireHours = 72,
    int maxUses = 0,
  }) {
    return _http.request<SpaceInviteInfo>(
      '/space/team/$spaceId/invite',
      method: 'POST',
      data: {'expireHours': expireHours, 'maxUses': maxUses},
      dataDecoder: (json) =>
          SpaceInviteInfo.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 有效邀请列表
  Future<List<SpaceInviteInfo>> listInvites(String spaceId) {
    return _http.request<List<SpaceInviteInfo>>(
      '/space/team/$spaceId/invites',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => SpaceInviteInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 撤销邀请
  Future<dynamic> revokeInvite(String spaceId, String inviteId) {
    return _http.request<dynamic>(
      '/space/team/$spaceId/invites/$inviteId',
      method: 'DELETE',
    );
  }

  /// 修改成员角色
  Future<dynamic> updateMemberRole(
    String spaceId,
    String userId,
    String role,
  ) {
    return _http.request<dynamic>(
      '/space/team/$spaceId/members/$userId',
      method: 'PUT',
      data: {'role': role},
    );
  }

  /// 移除成员（传自己的 userId 表示退出）
  Future<dynamic> removeMember(String spaceId, String userId) {
    return _http.request<dynamic>(
      '/space/team/$spaceId/members/$userId',
      method: 'DELETE',
    );
  }

  /// 解散团队空间
  Future<dynamic> dissolve(String spaceId) {
    return _http.request<dynamic>(
      '/space/team/$spaceId',
      method: 'DELETE',
    );
  }
}

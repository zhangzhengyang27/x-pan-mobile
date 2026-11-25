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

  /// 用户组列表
  Future<List<SpaceGroup>> listGroups(String spaceId) {
    return _http.request<List<SpaceGroup>>(
      '/space/team/$spaceId/groups',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => SpaceGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<SpaceGroup> createGroup(String spaceId, String groupName) {
    return _http.request<SpaceGroup>(
      '/space/team/$spaceId/groups',
      method: 'POST',
      data: {'groupName': groupName},
      dataDecoder: (json) => SpaceGroup.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> deleteGroup(String spaceId, String groupId) async {
    await _http.request<dynamic>(
      '/space/team/$spaceId/groups/$groupId',
      method: 'DELETE',
    );
  }

  Future<void> addGroupMembers(String spaceId, String groupId, List<String> userIds) async {
    await _http.request<dynamic>(
      '/space/team/$spaceId/groups/$groupId/members',
      method: 'POST',
      data: {'userIds': userIds},
    );
  }

  Future<void> removeGroupMembers(String spaceId, String groupId, List<String> userIds) async {
    await _http.request<dynamic>(
      '/space/team/$spaceId/groups/$groupId/members/remove',
      method: 'POST',
      data: {'userIds': userIds},
    );
  }

  Future<List<SpaceAcl>> listAcls(String spaceId, {String? folderId, int page = 1, int pageSize = 100}) {
    return _http.request<List<SpaceAcl>>(
      '/space/team/$spaceId/acls',
      query: {
        if (folderId != null) 'folderId': folderId,
        'page': page,
        'pageSize': pageSize,
      },
      dataDecoder: (json) {
        final map = json as Map<String, dynamic>;
        return (map['records'] as List<dynamic>? ?? const [])
            .map((e) => SpaceAcl.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<SpaceAcl> saveAcl(
    String spaceId, {
    required String folderId,
    required String subjectType,
    required String subjectId,
    required String permission,
  }) {
    return _http.request<SpaceAcl>(
      '/space/team/$spaceId/acls',
      method: 'POST',
      data: {
        'folderId': folderId,
        'subjectType': subjectType,
        'subjectId': subjectId,
        'permission': permission,
      },
      dataDecoder: (json) => SpaceAcl.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> deleteAcl(String spaceId, String aclId) async {
    await _http.request<dynamic>(
      '/space/team/$spaceId/acls/$aclId',
      method: 'DELETE',
    );
  }

  Future<List<SpaceFolderNode>> listFolders(String spaceId) {
    return _http.request<List<SpaceFolderNode>>(
      '/space/team/$spaceId/folders',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => SpaceFolderNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 用户组视图（成员 userId 为后端原始 ID 字符串，供加组/加 ACL 使用）
class SpaceGroup {
  const SpaceGroup({
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.members,
  });

  final String groupId;
  final String groupName;
  final int memberCount;
  final List<SpaceGroupMember> members;

  factory SpaceGroup.fromJson(Map<String, dynamic> json) {
    return SpaceGroup(
      groupId: json['groupId']?.toString() ?? '',
      groupName: json['groupName'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      members: (json['members'] as List<dynamic>? ?? const [])
          .map((e) => SpaceGroupMember.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SpaceGroupMember {
  const SpaceGroupMember({required this.userId, required this.username});

  final String userId;
  final String username;

  factory SpaceGroupMember.fromJson(Map<String, dynamic> json) {
    return SpaceGroupMember(
      userId: json['userId']?.toString() ?? '',
      username: json['username'] as String? ?? '',
    );
  }
}

/// 目录 ACL 视图
class SpaceAcl {
  const SpaceAcl({
    required this.id,
    required this.folderId,
    required this.folderName,
    required this.folderPath,
    required this.subjectType,
    required this.subjectId,
    required this.subjectName,
    required this.permission,
    required this.createTime,
  });

  final String id;
  final String folderId;
  final String folderName;
  final String folderPath;
  final String subjectType;
  final String subjectId;
  final String subjectName;
  final String permission;
  final String createTime;

  factory SpaceAcl.fromJson(Map<String, dynamic> json) {
    return SpaceAcl(
      id: json['id']?.toString() ?? '',
      folderId: json['folderId']?.toString() ?? '',
      folderName: json['folderName'] as String? ?? '',
      folderPath: json['folderPath'] as String? ?? '',
      subjectType: json['subjectType'] as String? ?? '',
      subjectId: json['subjectId']?.toString() ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      permission: json['permission'] as String? ?? '',
      createTime: json['createTime'] as String? ?? '',
    );
  }
}

/// 空间文件夹树节点（只用于选择目录；id 为加密串）
class SpaceFolderNode {
  const SpaceFolderNode({
    required this.id,
    required this.parentId,
    required this.label,
    required this.children,
  });

  final String id;
  final String parentId;
  final String label;
  final List<SpaceFolderNode> children;

  factory SpaceFolderNode.fromJson(Map<String, dynamic> json) {
    return SpaceFolderNode(
      id: json['id']?.toString() ?? '',
      parentId: json['parentId']?.toString() ?? '',
      label: json['label'] as String? ?? '',
      children: (json['children'] as List<dynamic>? ?? const [])
          .map((e) => SpaceFolderNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

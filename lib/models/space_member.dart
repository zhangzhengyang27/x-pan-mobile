/// 空间成员，对齐后端 SpaceMemberVO
class SpaceMemberInfo {
  const SpaceMemberInfo({
    required this.userId,
    required this.username,
    required this.role,
    this.joinTime,
  });

  final String userId;
  final String username;
  final String role;
  final String? joinTime;

  factory SpaceMemberInfo.fromJson(Map<String, dynamic> json) {
    return SpaceMemberInfo(
      userId: json['userId']?.toString() ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'MEMBER',
      joinTime: json['joinTime'] as String?,
    );
  }
}

/// 邀请码预览，对齐后端 SpaceInvitePreviewVO
class SpaceInvitePreview {
  const SpaceInvitePreview({
    required this.spaceId,
    required this.spaceName,
    required this.ownerUsername,
    required this.inviterUsername,
    required this.memberCount,
    required this.alreadyMember,
  });

  final String spaceId;
  final String spaceName;
  final String ownerUsername;
  final String inviterUsername;
  final int memberCount;
  final bool alreadyMember;

  factory SpaceInvitePreview.fromJson(Map<String, dynamic> json) {
    return SpaceInvitePreview(
      spaceId: json['spaceId']?.toString() ?? '',
      spaceName: json['spaceName'] as String? ?? '',
      ownerUsername: json['ownerUsername'] as String? ?? '',
      inviterUsername: json['inviterUsername'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      alreadyMember: json['alreadyMember'] as bool? ?? false,
    );
  }
}

/// 空间邀请，对齐后端 SpaceInviteVO
class SpaceInviteInfo {
  const SpaceInviteInfo({
    required this.id,
    required this.inviteCode,
    required this.inviteUrl,
    required this.maxUses,
    required this.usedCount,
    required this.status,
    this.expireTime,
  });

  final String id;
  final String inviteCode;
  final String inviteUrl;
  final int maxUses;
  final int usedCount;
  final int status;
  final String? expireTime;

  factory SpaceInviteInfo.fromJson(Map<String, dynamic> json) {
    return SpaceInviteInfo(
      id: json['id']?.toString() ?? '',
      inviteCode: json['inviteCode'] as String? ?? '',
      inviteUrl: json['inviteUrl'] as String? ?? '',
      maxUses: (json['maxUses'] as num?)?.toInt() ?? 0,
      usedCount: (json['usedCount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as num?)?.toInt() ?? 0,
      expireTime: json['expireTime'] as String?,
    );
  }
}

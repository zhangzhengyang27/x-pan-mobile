/// 空间信息，对齐后端 SpaceVO
class SpaceInfo {
  const SpaceInfo({
    required this.spaceId,
    required this.spaceName,
    required this.spaceType,
    required this.role,
    required this.ownerUserId,
    required this.ownerUsername,
    required this.rootFileId,
    required this.usedSize,
    required this.totalSize,
    required this.memberCount,
  });

  final String spaceId;
  final String spaceName;
  final String spaceType;
  final String role;
  final String ownerUserId;
  final String ownerUsername;
  final String rootFileId;
  final int usedSize;
  final int totalSize;
  final int memberCount;

  bool get isTeam => spaceType == 'TEAM';

  bool get canWrite => role != 'VIEWER';

  factory SpaceInfo.fromJson(Map<String, dynamic> json) {
    return SpaceInfo(
      spaceId: json['spaceId']?.toString() ?? '',
      spaceName: json['spaceName'] as String? ?? '',
      spaceType: json['spaceType'] as String? ?? 'PERSONAL',
      role: json['role'] as String? ?? 'MEMBER',
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      ownerUsername: json['ownerUsername'] as String? ?? '',
      rootFileId: json['rootFileId'] as String? ?? '',
      usedSize: (json['usedSize'] as num?)?.toInt() ?? 0,
      totalSize: (json['totalSize'] as num?)?.toInt() ?? 0,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
    );
  }
}

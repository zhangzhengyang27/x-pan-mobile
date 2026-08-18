/// 用户信息，对齐前端 IUserInfo
class UserInfo {
  const UserInfo({
    required this.userId,
    required this.username,
    required this.rootFileId,
    required this.rootFilename,
    required this.usedSize,
    required this.totalSize,
    this.avatar,
    this.email,
  });

  final String userId;
  final String username;
  final String rootFileId;
  final String rootFilename;
  final String? avatar;
  final String? email;
  final int usedSize;
  final int totalSize;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      rootFileId: json['rootFileId'] as String? ?? '',
      rootFilename: json['rootFilename'] as String? ?? '',
      avatar: json['avatar'] as String?,
      email: json['email'] as String?,
      usedSize: json['usedSize'] as int? ?? 0,
      totalSize: json['totalSize'] as int? ?? 0,
    );
  }
}

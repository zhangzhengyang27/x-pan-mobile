/// 用户文件统计概览，对齐后端 UserFileStatsVO
class UserFileStats {
  const UserFileStats({
    required this.totalFileCount,
    required this.totalFolderCount,
    required this.usedSpace,
    required this.imageCount,
    required this.videoCount,
    required this.audioCount,
    required this.docCount,
    required this.archiveCount,
    required this.codeCount,
    required this.otherCount,
  });

  /// 文件总数（不含文件夹）
  final int totalFileCount;

  /// 文件夹总数
  final int totalFolderCount;

  /// 已用存储空间（字节）
  final int usedSpace;

  final int imageCount;
  final int videoCount;
  final int audioCount;
  final int docCount;
  final int archiveCount;
  final int codeCount;
  final int otherCount;

  factory UserFileStats.fromJson(Map<String, dynamic> json) {
    return UserFileStats(
      totalFileCount: (json['totalFileCount'] as num?)?.toInt() ?? 0,
      totalFolderCount: (json['totalFolderCount'] as num?)?.toInt() ?? 0,
      usedSpace: (json['usedSpace'] as num?)?.toInt() ?? 0,
      imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
      videoCount: (json['videoCount'] as num?)?.toInt() ?? 0,
      audioCount: (json['audioCount'] as num?)?.toInt() ?? 0,
      docCount: (json['docCount'] as num?)?.toInt() ?? 0,
      archiveCount: (json['archiveCount'] as num?)?.toInt() ?? 0,
      codeCount: (json['codeCount'] as num?)?.toInt() ?? 0,
      otherCount: (json['otherCount'] as num?)?.toInt() ?? 0,
    );
  }
}

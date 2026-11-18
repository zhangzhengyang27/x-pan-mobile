/// 相册备份分类规则（纯函数，无 IO）：
/// - 截图（title/relativePath 含 "screenshot"）→ 相册备份/截图/
/// - 其余按拍摄时间归 相册备份/{YYYY-MM}/，拍摄时间缺失回退修改时间
class BackupClassification {
  const BackupClassification({required this.relativeDir, required this.isScreenshot});
  final String relativeDir;
  final bool isScreenshot;
}

const String kPhotoBackupRoot = '相册备份';
const String kScreenshotDir = '相册备份/截图';

class BackupClassifier {
  static bool detectScreenshot({String? title, String? relativePath}) {
    final t = (title ?? '').toLowerCase();
    final p = (relativePath ?? '').toLowerCase();
    return t.contains('screenshot') || p.contains('screenshot');
  }

  static BackupClassification classify({
    required bool isVideo,
    required bool isScreenshot,
    required DateTime modifiedTime,
    DateTime? takenTime,
  }) {
    if (isScreenshot) {
      return const BackupClassification(relativeDir: kScreenshotDir, isScreenshot: true);
    }
    final base = takenTime ?? modifiedTime;
    final month = base.month.toString().padLeft(2, '0');
    return BackupClassification(relativeDir: '$kPhotoBackupRoot/${base.year}-$month', isScreenshot: false);
  }
}

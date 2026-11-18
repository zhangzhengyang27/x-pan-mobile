import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/core/photo/backup_classifier.dart';

void main() {
  test('截图 → 截图目录（takenTime 缺失也回退 modifiedTime 不影响目录）', () {
    final c = BackupClassifier.classify(
      isVideo: false,
      isScreenshot: true,
      modifiedTime: DateTime(2026, 11, 16),
    );
    expect(c.isScreenshot, isTrue);
    expect(c.relativeDir, '相册备份/截图');
  });

  test('照片按拍摄时间归月份目录', () {
    final c = BackupClassifier.classify(
      isVideo: false,
      isScreenshot: false,
      modifiedTime: DateTime(2026, 1, 1),
      takenTime: DateTime(2026, 11, 3, 14, 30),
    );
    expect(c.relativeDir, '相册备份/2026-11');
  });

  test('视频同样按拍摄时间归月份目录', () {
    final c = BackupClassifier.classify(
      isVideo: true,
      isScreenshot: false,
      modifiedTime: DateTime(2026, 2, 1),
      takenTime: DateTime(2026, 12, 31),
    );
    expect(c.relativeDir, '相册备份/2026-12');
  });

  test('takenTime 缺失回退 modifiedTime（截图无 EXIF 场景）', () {
    final c = BackupClassifier.classify(
      isVideo: false,
      isScreenshot: false,
      modifiedTime: DateTime(2026, 9, 15),
      takenTime: null,
    );
    expect(c.relativeDir, '相册备份/2026-09');
  });

  test('截图判定：title 或 relativePath 含 screenshot（不分大小写）', () {
    expect(BackupClassifier.detectScreenshot(title: 'Screenshot_20261116_1.jpg'), isTrue);
    expect(BackupClassifier.detectScreenshot(title: 'screenshot.png'), isTrue);
    expect(BackupClassifier.detectScreenshot(title: 'IMG_123.jpg', relativePath: 'DCIM/Screenshots/IMG_123.jpg'), isTrue);
    expect(BackupClassifier.detectScreenshot(title: 'IMG_123.jpg', relativePath: 'DCIM/Camera/IMG_123.jpg'), isFalse);
    expect(BackupClassifier.detectScreenshot(title: null, relativePath: null), isFalse);
  });
}

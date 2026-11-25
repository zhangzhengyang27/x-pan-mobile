import 'package:workmanager/workmanager.dart';

import '../../services/local_notification_service.dart';
import '../../services/upload_service.dart';
import '../../services/user_service.dart';
import 'backup_record_store.dart';
import 'photo_asset_source.dart';
import 'photo_backup_engine.dart';

/// 后台周期任务名（workmanager uniqueName 与 taskName 同值）
const String kPhotoBackupTask = 'xpan-photo-backup';

/// 后台 isolate 的引擎组装：直调 UploadService（不走 riverpod UI 状态）。
/// rootFileId 每次经 /user/info 获取（后台无 authProvider 缓存）。
PhotoBackupEngine buildBackgroundEngine() {
  final recordStore = BackupRecordStore();
  return PhotoBackupEngine(
    assetSource: PhotoManagerAssetSource(),
    recordStore: recordStore,
    dirResolver: _resolveDirBackground,
    // 后台通道：逐个 await 上传，成功才记（I2 语义：失败不 mark，下次扫描自动重试）
    enqueuer: (file, parentId, asset) async {
      await UploadService.instance.uploadFile(file: file, parentId: parentId);
      final size = await file.length();
      await recordStore.markBackedUp(
          asset.assetId, asset.modifiedTime.millisecondsSinceEpoch, size);
    },
  );
}

Future<String> _resolveDirBackground(String relativeDir) async {
  final info = await UserService.instance.info();
  final rootId = info.rootFileId;
  var parentId = rootId;
  for (final name in relativeDir.split('/')) {
    final existing = await _findChildFolder(parentId, name);
    if (existing != null) {
      parentId = existing;
      continue;
    }
    await FileService.instance.createFolder(parentId: parentId, filename: name);
    final created = await _findChildFolder(parentId, name);
    if (created == null) {
      throw Exception('备份目录创建失败：$name');
    }
    parentId = created;
  }
  return parentId;
}

Future<String?> _findChildFolder(String parentId, String name) async {
  final page = await FileService.instance.list(
    parentId: parentId,
    keyword: name,
    pageSize: 50,
  );
  for (final vo in page.records) {
    if (vo.filename == name && vo.isFolder) return vo.fileId;
  }
  return null;
}

/// 备份完成系统通知（后台场景前台不可见）
Future<void> notifyBackupDone(int count) async {
  try {
    await LocalNotificationService.instance.show(
      id: 'photo_backup_$count',
      title: '相册备份完成',
      body: '已备份 $count 个文件到"相册备份"目录',
    );
  } on Exception catch (_) {
    // 通知失败不影响备份结果
  }
}

/// workmanager 回调分发器（@pragma 防止 release 裁剪）
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kPhotoBackupTask) return true;
    try {
      final engine = buildBackgroundEngine();
      final result = await engine.scanAndEnqueue(
        force: true,
        // 后台 isolate 串行 await 上传，单次不宜过长（WorkManager 有执行窗口）
        maxEnqueue: kBackgroundEnqueueLimit,
      );
      if (result.enqueued > 0) {
        await notifyBackupDone(result.enqueued);
      }
      return true;
    } catch (_) {
      // 后台任务异常：返回 false 让系统按其策略重试
      return false;
    }
  });
}

/// 周期任务注册/取消（设置开关切换时调用；平台不支持时静默）
Future<void> setPhotoBackupWork(bool enabled) async {
  try {
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        kPhotoBackupTask,
        kPhotoBackupTask,
        frequency: const Duration(minutes: 15),
      );
    } else {
      await Workmanager().cancelByUniqueName(kPhotoBackupTask);
    }
  } catch (_) {
    // 未初始化 / 平台不支持（如 macOS）→ 静默
  }
}

/// 后台任务里的串行上传兜底（防御：engine 的 enqueuer 已按序 await，
/// 本函数仅为未来并行改造预留占位，当前空实现）
Future<void> flushUploadQueue() async {}

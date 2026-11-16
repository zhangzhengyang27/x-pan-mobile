import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_classifier.dart';
import 'backup_record_store.dart';
import 'photo_asset_source.dart';

class BackupScanResult {
  const BackupScanResult({
    required this.scanned,
    required this.enqueued,
    required this.skipped,
    this.needsPermission = false,
    this.error,
  });
  final int scanned;
  final int enqueued;
  final int skipped;
  final bool needsPermission;
  final String? error;
}

typedef UploadEnqueuer = Future<void> Function(
    File file, String parentId, BackupAsset asset);

/// 解析相对目录（如 "相册备份/2026-11"）为该目录的 parentId（幂等创建）
typedef DirectoryResolver = Future<String> Function(String relativeDir);

const int kBatchSize = 20;
const String kMutexKey = 'photo_backup_running';
const Duration kMutexTimeout = Duration(minutes: 30);
const Duration kThrottleInterval = Duration(minutes: 10);
const String kLastScanKey = 'photo_backup_last_scan';

/// 相册备份引擎（纯 Dart，不依赖 riverpod）：
/// 扫描相册 → 去重过滤 → 分类 → 落临时文件 → 入队。
/// 前台 provider 与 workmanager 后台回调共用本类。
class PhotoBackupEngine {
  PhotoBackupEngine({
    required this.assetSource,
    required this.recordStore,
    required this.dirResolver,
    required this.enqueuer,
    Directory? tempRoot,
  }) : _tempRootOverride = tempRoot;

  final PhotoAssetSource assetSource;
  final BackupRecordStore recordStore;
  final DirectoryResolver dirResolver;
  final UploadEnqueuer enqueuer;
  final Directory? _tempRootOverride;

  Future<Directory> get _tempRoot async {
    if (_tempRootOverride != null) return _tempRootOverride;
    final base = await getTemporaryDirectory();
    return Directory('${base.path}/photo_backup');
  }

  /// 扫描 → 过滤 → 分类 → 分批入队。
  /// [force] = 手动"立即备份"或后台周期触发，绕过 10 分钟节流。
  /// 前后台并发互斥：SP 标记（30 分钟超时兜底），被占用直接跳过本次。
  Future<BackupScanResult> scanAndEnqueue({bool force = false}) async {
    final sp = await SharedPreferences.getInstance();
    // 跨 isolate 可见性：shared_preferences 有进程内缓存，后台 isolate 写入的
    // 标记/记录前台缓存看不到——扫描入口强制 reload 后再读
    await sp.reload();
    final running = sp.getString(kMutexKey);
    if (running != null) {
      final startedAt = DateTime.tryParse(running);
      if (startedAt != null && DateTime.now().difference(startedAt) < kMutexTimeout) {
        return const BackupScanResult(
            scanned: 0, enqueued: 0, skipped: 0, error: 'another-backup-running');
      }
    }
    await sp.setString(kMutexKey, DateTime.now().toIso8601String());
    try {
      if (!force) {
        final lastScanMs = sp.getInt(kLastScanKey) ?? 0;
        if (lastScanMs > 0 &&
            DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastScanMs)) <
                kThrottleInterval) {
          return const BackupScanResult(scanned: 0, enqueued: 0, skipped: 0);
        }
      }
      final result = await _scanAndEnqueueInner(sp);
      await sp.setInt(kLastScanKey, DateTime.now().millisecondsSinceEpoch);
      return result;
    } finally {
      await sp.remove(kMutexKey);
    }
  }

  Future<BackupScanResult> _scanAndEnqueueInner(SharedPreferences sp) async {
    // C1：先加载持久化记录（markBackedUp 只在自己实例触发 load，
    // 新实例/新 isolate 的判定若不 load 会读到空缓存 → 每轮重复入队首个资产）
    await recordStore.load();
    if (!await assetSource.ensurePermission()) {
      return const BackupScanResult(scanned: 0, enqueued: 0, skipped: 0, needsPermission: true);
    }
    await cleanupTemp();

    final assets = await assetSource.recentAssets();
    final dirIdCache = <String, String>{};
    int enqueued = 0;
    int skipped = 0;

    for (final asset in assets) {
      if (enqueued >= kBatchSize) {
        // 分批：超出首批的部分留待下次扫描（避免一次性堵满上传队列）
        skipped += 1;
        continue;
      }
      final classification = BackupClassifier.classify(
        isVideo: asset.isVideo,
        isScreenshot: asset.isScreenshot,
        modifiedTime: asset.modifiedTime,
        takenTime: asset.takenTime,
      );
      final mtimeMillis = asset.modifiedTime.millisecondsSinceEpoch;

      // 落临时文件后取真实 size 判定三元组（落盘失败跳过，本次不计）
      final file = await asset.toFile();
      if (file == null) {
        skipped += 1;
        continue;
      }
      final size = await file.length();
      if (recordStore.isBackedUp(asset.assetId, mtimeMillis, size)) {
        skipped += 1;
        continue;
      }

      String parentId = dirIdCache[classification.relativeDir] ?? '';
      if (parentId.isEmpty) {
        parentId = await dirResolver(classification.relativeDir);
        dirIdCache[classification.relativeDir] = parentId;
      }
      // markBackedUp 不在此处调用（I2）：入队 ≠ 上传成功——前台 addFile 立即返回，
      // 失败任务的资产必须留待下次扫描重试。"上传成功才记"由 enqueuer 实现方
      // 在任务终态（后台 await uploadFile 成功 / 前台 onTaskSettled）时执行
      await enqueuer(file, parentId, asset);
      enqueued += 1;
      await Future<void>.delayed(Duration.zero);
    }

    return BackupScanResult(scanned: assets.length, enqueued: enqueued, skipped: skipped);
  }

  /// 清理临时目录中超过 24h 的残留副本（含按资产隔离的子目录）；每次扫描前顺带执行
  Future<void> cleanupTemp() async {
    final root = await _tempRoot;
    if (!await root.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entity in root.list()) {
      final stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) {
        try {
          await entity.delete(recursive: entity is Directory);
        } catch (_) {
          // 单个清理失败不影响其余
        }
      }
    }
  }
}

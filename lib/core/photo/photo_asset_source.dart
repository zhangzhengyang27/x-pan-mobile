import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'backup_classifier.dart';

/// 相册资产抽象（隔离 photo_manager，测试注入 fake）
abstract class BackupAsset {
  BackupAsset({
    required this.assetId,
    required this.fileName,
    required this.modifiedTime,
    required this.takenTime,
    required this.isVideo,
    required this.isScreenshot,
  });

  final String assetId;
  final String fileName; // 原文件名（photo_manager AssetEntity.title），保留不改
  final DateTime modifiedTime;
  final DateTime? takenTime;
  final bool isVideo;
  final bool isScreenshot;

  /// 落临时文件（原图副本，保留原文件名）；失败返回 null（调用方跳过并记录）。
  /// 统一放进 photo_backup/ 临时目录，由 engine 清理。
  Future<File?> toFile() async {
    final origin = await originFile();
    if (origin == null) return null;
    final dir = Directory('${(await getTemporaryDirectory()).path}/photo_backup');
    await dir.create(recursive: true);
    final target = File('${dir.path}/$fileName');
    if (target.path == origin.path) return origin;
    return origin.copy(target.path);
  }

  Future<File?> originFile();
}

abstract class PhotoAssetSource {
  Future<bool> ensurePermission();
  Future<List<BackupAsset>> recentAssets();
}

/// photo_manager 实现
class PhotoManagerAssetSource implements PhotoAssetSource {
  @override
  Future<bool> ensurePermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth;
  }

  @override
  Future<List<BackupAsset>> recentAssets() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.updateDate, asc: false)],
      ),
    );
    if (paths.isEmpty) return [];
    final recent = paths.first; // "最近照片"聚合相册（覆盖全量媒体）
    final assets = await recent.getAssetListRange(start: 0, end: 10000);
    return assets.map(_toBackupAsset).whereType<BackupAsset>().toList();
  }

  BackupAsset? _toBackupAsset(AssetEntity asset) {
    final isVideo = asset.type == AssetType.video;
    final isScreenshot = BackupClassifier.detectScreenshot(
      title: asset.title,
      relativePath: asset.relativePath,
    );
    return PhotoManagerBackupAsset(
      entity: asset,
      assetId: asset.id,
      fileName: asset.title ?? '${asset.id}.${isVideo ? 'mp4' : 'jpg'}',
      modifiedTime: asset.modifiedDateTime,
      takenTime: asset.createDateTime,
      isVideo: isVideo,
      isScreenshot: isScreenshot,
    );
  }
}

class PhotoManagerBackupAsset extends BackupAsset {
  PhotoManagerBackupAsset({
    required super.assetId,
    required super.fileName,
    required super.modifiedTime,
    required super.takenTime,
    required super.isVideo,
    required super.isScreenshot,
    required this.entity,
  });

  final AssetEntity entity;

  @override
  Future<File?> originFile() => entity.originFile;
}

/// 清理 photo_backup/ 临时目录中超过 maxAgeHours 的残留副本
Future<void> _cleanupStaleTemp(int maxAgeHours) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/photo_backup');
  if (!await dir.exists()) return;
  final cutoff = DateTime.now().subtract(Duration(hours: maxAgeHours));
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final stat = await entity.stat();
    if (stat.modified.isBefore(cutoff)) {
      try {
        await entity.delete();
      } catch (_) {
        // 单个清理失败不影响其余
      }
    }
  }
}

/// engine 可直接调用的公共清理入口
Future<void> cleanupStaleTempFiles(int maxAgeHours) => _cleanupStaleTemp(maxAgeHours);

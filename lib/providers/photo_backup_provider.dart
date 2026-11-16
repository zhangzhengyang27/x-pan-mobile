import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/photo/backup_background.dart';
import '../core/photo/backup_record_store.dart';
import '../core/photo/photo_asset_source.dart';
import '../core/photo/photo_backup_engine.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';
import 'upload_provider.dart';

/// 相册备份总开关（SP 持久化）
final photoBackupEnabledProvider =
    StateNotifierProvider<PhotoBackupEnabledNotifier, bool>((ref) {
  return PhotoBackupEnabledNotifier();
});

class PhotoBackupEnabledNotifier extends StateNotifier<bool> {
  PhotoBackupEnabledNotifier() : super(false) {
    _restore();
  }

  static const String _key = 'photo_backup_enabled';

  Future<void> _restore() async {
    final sp = await SharedPreferences.getInstance();
    if (mounted) state = sp.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, value);
    // 后台周期任务随开关注册/取消
    await setPhotoBackupWork(value);
  }
}

/// 备份运行状态（设置卡片展示）
class PhotoBackupRunState {
  const PhotoBackupRunState({
    this.scanning = false,
    this.lastMessage = '',
    this.lastNeedsPermission = false,
  });

  final bool scanning;
  final String lastMessage;
  final bool lastNeedsPermission;

  PhotoBackupRunState copyWith({
    bool? scanning,
    String? lastMessage,
    bool? lastNeedsPermission,
  }) {
    return PhotoBackupRunState(
      scanning: scanning ?? this.scanning,
      lastMessage: lastMessage ?? this.lastMessage,
      lastNeedsPermission: lastNeedsPermission ?? this.lastNeedsPermission,
    );
  }
}

final photoBackupRunProvider =
    StateNotifierProvider<PhotoBackupRunNotifier, PhotoBackupRunState>((ref) {
  return PhotoBackupRunNotifier(ref);
});

class PhotoBackupRunNotifier extends StateNotifier<PhotoBackupRunState> {
  PhotoBackupRunNotifier(this._ref) : super(const PhotoBackupRunState());

  final Ref _ref;

  /// 组装 engine（前台通道：经 UploadManager 串行队列，传输页可见）
  PhotoBackupEngine _buildEngine() {
    final recordStore = BackupRecordStore();
    return PhotoBackupEngine(
      assetSource: PhotoManagerAssetSource(),
      recordStore: recordStore,
      dirResolver: _resolveDir,
      enqueuer: (file, parentId) =>
          _ref.read(uploadManagerProvider.notifier).addFile(file, parentId),
    );
  }

  /// 相册备份目录解析：逐级检索/创建（"相册备份" → 子目录），结果缓存在本次会话
  final Map<String, String> _dirIdCache = {};

  Future<String> _resolveDir(String relativeDir) async {
    if (_dirIdCache.containsKey(relativeDir)) return _dirIdCache[relativeDir]!;
    final rootId = _ref.read(authProvider).user?.rootFileId;
    if (rootId == null || rootId.isEmpty) {
      throw Exception('未获取到根目录，无法备份');
    }
    final segments = relativeDir.split('/');
    var parentId = rootId;
    for (final name in segments) {
      final existing = await _findChildFolder(parentId, name);
      if (existing != null) {
        parentId = existing;
      } else {
        await FileService.instance.createFolder(parentId: parentId, filename: name);
        final created = await _findChildFolder(parentId, name);
        if (created == null) {
          throw Exception('备份目录创建失败：$name');
        }
        parentId = created;
      }
    }
    _dirIdCache[relativeDir] = parentId;
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

  /// 手动"立即备份"
  Future<void> runNow() async {
    if (state.scanning) return;
    state = state.copyWith(scanning: true, lastMessage: '');
    try {
      final engine = _buildEngine();
      final result = await engine.scanAndEnqueue(force: true);
      if (result.needsPermission) {
        state = state.copyWith(
          lastNeedsPermission: true,
          lastMessage: '需要相册权限，请在系统设置中授权',
        );
      } else if (result.error == 'another-backup-running') {
        state = state.copyWith(lastMessage: '已有备份任务在进行中');
      } else if (result.enqueued == 0) {
        state = state.copyWith(lastMessage: '相册已是最新，没有需要备份的内容');
      } else {
        state = state.copyWith(
            lastMessage: '已加入备份队列 ${result.enqueued} 项，可在传输页查看进度');
      }
    } on Exception catch (e) {
      state = state.copyWith(lastMessage: '备份失败：${e.toString()}');
    } finally {
      state = state.copyWith(scanning: false);
    }
  }
}

/// 备份临时文件清扫（App 启动时调用一次）
Future<void> cleanupPhotoBackupTemp() async {
  await cleanupStaleTempFiles(24);
}

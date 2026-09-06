import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/http_client.dart';
import '../services/upload_service.dart';

/// 上传任务状态
///
/// 说明：paused 为预留状态（当前队列无手动暂停功能，恢复场景直接重传），
/// 传输页状态映射与「已暂停」文案、取消按钮条件均已引用，保留枚举值。
enum UploadStatus { waiting, uploading, paused, completed, failed, cancelled }

/// copyWith 的「未传参」哨兵（区分「不修改」与「置为 null」）
const Object _unset = Object();

/// 上传任务
class UploadTask {
  UploadTask({
    required this.id,
    required this.filename,
    required this.filePath,
    required this.parentId,
    this.resumeIdentifier,
    this.progress = 0,
    this.status = UploadStatus.waiting,
    this.error,
    this.cancelled = false,
  });

  final String id;
  final String filename;
  final String filePath;
  final String parentId;

  /// 跨重启恢复时的 identifier（跳过 MD5 计算）
  final String? resumeIdentifier;

  double progress;
  UploadStatus status;
  String? error;

  /// 是否已取消（取消标志，供 UploadService 检查）
  bool cancelled = false;

  /// 不可变更新：返回替换用的新实例
  ///
  /// Riverpod 状态快照要求不可变语义：更新任务时用 copyWith 生成新对象
  /// 替换列表项，而不是原地修改已有实例（旧快照会被同步篡改）。
  UploadTask copyWith({
    double? progress,
    UploadStatus? status,
    Object? error = _unset,
    bool? cancelled,
  }) {
    return UploadTask(
      id: id,
      filename: filename,
      filePath: filePath,
      parentId: parentId,
      resumeIdentifier: resumeIdentifier,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error == _unset ? this.error : error as String?,
      cancelled: cancelled ?? this.cancelled,
    );
  }

  String get statusText {
    switch (status) {
      case UploadStatus.waiting:
        return '等待中';
      case UploadStatus.uploading:
        return '上传中';
      case UploadStatus.paused:
        return '已暂停';
      case UploadStatus.completed:
        return '已完成';
      case UploadStatus.failed:
        return '失败';
      case UploadStatus.cancelled:
        return '已取消';
    }
  }
}

/// 上传队列状态
class UploadQueueState {
  const UploadQueueState({this.tasks = const []});

  final List<UploadTask> tasks;

  UploadQueueState copyWith({List<UploadTask>? tasks}) {
    return UploadQueueState(tasks: tasks ?? this.tasks);
  }
}

/// 上传队列管理器
///
/// 串行上传（一次一个），支持添加/暂停/恢复/取消/移除。
class UploadManager extends StateNotifier<UploadQueueState> {
  UploadManager(this._uploadService) : super(const UploadQueueState());

  final UploadService _uploadService;

  int _idSeq = 0;
  bool _processing = false;

  /// 添加文件到上传队列
  ///
  /// [resumeIdentifier]：跨重启恢复时传入已计算的 identifier（跳过 MD5 计算）。
  Future<void> addFile(
    File file,
    String parentId, {
    String? resumeIdentifier,
  }) async {
    final task = UploadTask(
      id: '${++_idSeq}',
      filename: file.uri.pathSegments.last,
      filePath: file.path,
      parentId: parentId,
      resumeIdentifier: resumeIdentifier,
    );
    state = state.copyWith(tasks: [...state.tasks, task]);
    _drain();
  }

  /// 串行处理队列
  Future<void> _drain() async {
    if (_processing) return;
    _processing = true;
    try {
      while (true) {
        final task = state.tasks.firstWhere(
          (t) => t.status == UploadStatus.waiting,
          orElse: () => _emptyTask(),
        );
        if (task.id.isEmpty) break;
        await _process(task);
      }
    } finally {
      _processing = false;
    }
  }

  UploadTask _emptyTask() => UploadTask(
        id: '',
        filename: '',
        filePath: '',
        parentId: '',
        status: UploadStatus.completed,
      );

  UploadTask? _taskById(String id) {
    for (final t in state.tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 用 updater 生成的新实例替换列表中对应任务（不可变更新）
  void _updateTask(String id, UploadTask Function(UploadTask) updater) {
    final tasks = List<UploadTask>.from(state.tasks);
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = updater(tasks[idx]);
    state = state.copyWith(tasks: tasks);
  }

  Future<void> _process(UploadTask task) async {
    _updateTask(task.id, (t) => t.copyWith(status: UploadStatus.uploading));
    // 进度回调按 id 从最新 state 取任务（cancel 用 copyWith 替换实例后，
    // 旧引用的 cancelled 标志不会更新，必须读最新快照）
    _uploadService.onProgress = (p) => _setProgress(task, p);
    _uploadService.onCheckCancel = () => _taskById(task.id)?.cancelled ?? false;

    try {
      await _uploadService.uploadFile(
        file: File(task.filePath),
        parentId: task.parentId,
        resumeIdentifier: task.resumeIdentifier,
      );
      _updateTask(task.id, (t) => t.copyWith(status: UploadStatus.completed));
    } on ApiException catch (e) {
      if (e.code == UploadService.cancelException.code) {
        _updateTask(
          task.id,
          (t) => t.copyWith(status: UploadStatus.cancelled),
        );
      } else {
        _updateTask(
          task.id,
          (t) => t.copyWith(status: UploadStatus.failed, error: e.message),
        );
      }
    } catch (e) {
      _updateTask(
        task.id,
        (t) => t.copyWith(status: UploadStatus.failed, error: e.toString()),
      );
    } finally {
      _uploadService.onProgress = null;
      _uploadService.onCheckCancel = null;
    }
  }

  void _setProgress(UploadTask task, double progress) {
    _updateTask(task.id, (t) => t.copyWith(progress: progress));
  }

  /// 取消任务
  void cancel(String id) {
    final task = _taskById(id);
    if (task == null) return;
    if (task.status == UploadStatus.waiting) {
      _updateTask(
        id,
        (t) => t.copyWith(status: UploadStatus.cancelled, cancelled: true),
      );
    } else if (task.status == UploadStatus.uploading) {
      _updateTask(id, (t) => t.copyWith(cancelled: true));
      // 立即中断在途的分片/合并请求（分片间 onCheckCancel 轮询兜底）
      _uploadService.cancelActiveUpload();
    }
  }

  /// 移除任务
  void remove(String id) {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );
  }

  /// 重试失败/取消的任务
  void retry(String id) {
    final task = _taskById(id);
    if (task == null) return;
    _updateTask(
      id,
      (t) => t.copyWith(
        status: UploadStatus.waiting,
        progress: 0,
        cancelled: false,
        error: null,
      ),
    );
    _drain();
  }
}

final uploadManagerProvider =
    StateNotifierProvider<UploadManager, UploadQueueState>((ref) {
  return UploadManager(UploadService.instance);
});

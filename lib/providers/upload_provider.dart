import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/http_client.dart';
import '../services/upload_service.dart';

/// 上传任务状态
enum UploadStatus { waiting, uploading, paused, completed, failed, cancelled }

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

  Future<void> _process(UploadTask task) async {
    _setStatus(task, UploadStatus.uploading);
    _uploadService.onProgress = (p) => _setProgress(task, p);
    _uploadService.onCheckCancel = () => task.cancelled;

    try {
      await _uploadService.uploadFile(
        file: File(task.filePath),
        parentId: task.parentId,
        resumeIdentifier: task.resumeIdentifier,
      );
      _setStatus(task, UploadStatus.completed);
    } on ApiException catch (e) {
      if (e.code == UploadService.cancelException.code) {
        _setStatus(task, UploadStatus.cancelled);
      } else {
        task.error = e.message;
        _setStatus(task, UploadStatus.failed);
      }
    } catch (e) {
      task.error = e.toString();
      _setStatus(task, UploadStatus.failed);
    } finally {
      _uploadService.onProgress = null;
      _uploadService.onCheckCancel = null;
    }
  }

  void _setStatus(UploadTask task, UploadStatus status) {
    final tasks = List<UploadTask>.from(state.tasks);
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;
    tasks[idx].status = status;
    state = state.copyWith(tasks: tasks);
  }

  void _setProgress(UploadTask task, double progress) {
    final tasks = List<UploadTask>.from(state.tasks);
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;
    tasks[idx].progress = progress;
    state = state.copyWith(tasks: tasks);
  }

  /// 取消任务
  void cancel(String id) {
    final tasks = List<UploadTask>.from(state.tasks);
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    if (tasks[idx].status == UploadStatus.waiting) {
      tasks[idx].status = UploadStatus.cancelled;
      tasks[idx].cancelled = true;
    } else if (tasks[idx].status == UploadStatus.uploading) {
      tasks[idx].cancelled = true;
    }
    state = state.copyWith(tasks: tasks);
  }

  /// 移除任务
  void remove(String id) {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );
  }

  /// 重试失败/取消的任务
  void retry(String id) {
    final tasks = List<UploadTask>.from(state.tasks);
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx].status = UploadStatus.waiting;
    tasks[idx].progress = 0;
    tasks[idx].cancelled = false;
    tasks[idx].error = null;
    state = state.copyWith(tasks: tasks);
    _drain();
  }
}

final uploadManagerProvider =
    StateNotifierProvider<UploadManager, UploadQueueState>((ref) {
  return UploadManager(UploadService.instance);
});

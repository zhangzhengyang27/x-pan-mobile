import '../core/network/http_client.dart';

/// 在线压缩任务（与解压共用 task 结构，字段以归档接口实际返回为准）。
class ArchiveTask {
  const ArchiveTask({
    required this.taskId,
    required this.status,
    this.zipName,
    this.errorMsg,
  });

  final String taskId;
  final int status;
  final String? zipName;
  final String? errorMsg;

  factory ArchiveTask.fromJson(Map<String, dynamic> json) {
    return ArchiveTask(
      taskId: json['taskId']?.toString() ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      zipName: json['zipName'] as String?,
      errorMsg: json['errorMsg'] as String?,
    );
  }
}

/// 在线压缩 API。
///
/// 后端支持文件与文件夹 ID，异步任务在统一任务中心查看进度；
/// 客户端不轮询、不推断状态，避免与后端状态机分叉。
class ArchiveService {
  ArchiveService._();

  static final ArchiveService instance = ArchiveService._();

  final HttpClient _http = HttpClient.instance;

  Future<ArchiveTask> archive({
    required List<String> fileIds,
    String? targetParentId,
    String? zipName,
  }) {
    return _http.request<ArchiveTask>(
      '/file/archive',
      method: 'POST',
      data: {
        'fileIds': fileIds,
        if (targetParentId != null) 'targetParentId': targetParentId,
        if (zipName != null && zipName.trim().isNotEmpty) 'zipName': zipName.trim(),
      },
      dataDecoder: (json) => ArchiveTask.fromJson(json as Map<String, dynamic>),
    );
  }
}

import '../core/network/http_client.dart';

/// 解压结果文件
class ExtractedFile {
  const ExtractedFile({
    required this.filename,
    required this.fileSize,
    required this.fileSizeDesc,
    required this.fileType,
    required this.isDir,
  });

  final String filename;
  final int fileSize;
  final String fileSizeDesc;
  final int fileType;
  final bool isDir;

  factory ExtractedFile.fromJson(Map<String, dynamic> json) {
    return ExtractedFile(
      filename: json['filename'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      fileSizeDesc: json['fileSizeDesc'] as String? ?? '',
      fileType: json['fileType'] as int? ?? 1,
      isDir: json['isDir'] as bool? ?? false,
    );
  }
}

/// 解压任务（状态 0 待开始 1 解压中 2 完成 3 失败）
class ExtractTask {
  const ExtractTask({
    required this.taskId,
    required this.status,
    required this.statusText,
    required this.totalCount,
    required this.processedCount,
    required this.progress,
    this.errorMsg,
    this.result,
  });

  final String taskId;
  final int status;
  final String statusText;
  final int totalCount;
  final int processedCount;
  final double progress;
  final String? errorMsg;
  final List<ExtractedFile>? result;

  factory ExtractTask.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'] as List<dynamic>?;
    return ExtractTask(
      taskId: json['taskId'] as String? ?? '',
      status: json['status'] as int? ?? 0,
      statusText: json['statusText'] as String? ?? '',
      totalCount: json['totalCount'] as int? ?? 0,
      processedCount: json['processedCount'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      errorMsg: json['errorMsg'] as String?,
      result: rawResult
          ?.map((e) => ExtractedFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 在线解压 API，对齐后端 ExtractController
class ExtractService {
  ExtractService._();

  static final ExtractService instance = ExtractService._();

  final HttpClient _http = HttpClient.instance;

  /// 创建在线解压任务
  Future<ExtractTask> extract(String fileId, {String? targetParentId}) {
    return _http.request<ExtractTask>(
      '/file/extract',
      method: 'POST',
      data: {
        'fileId': fileId,
        if (targetParentId != null) 'targetParentId': targetParentId,
      },
      dataDecoder: (json) => ExtractTask.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 查询解压任务进度
  Future<ExtractTask> progress(String taskId) {
    return _http.request<ExtractTask>(
      '/file/extract/progress',
      query: {'taskId': taskId},
      dataDecoder: (json) => ExtractTask.fromJson(json as Map<String, dynamic>),
    );
  }
}

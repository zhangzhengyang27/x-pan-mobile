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

/// 压缩包内条目（选择解压用）
class ExtractEntry {
  const ExtractEntry({
    required this.path,
    required this.name,
    required this.size,
    required this.sizeDesc,
    required this.isDir,
  });

  final String path;
  final String name;
  final int size;
  final String sizeDesc;
  final bool isDir;

  factory ExtractEntry.fromJson(Map<String, dynamic> json) {
    return ExtractEntry(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      sizeDesc: json['sizeDesc'] as String? ?? '',
      isDir: json['isDir'] as bool? ?? false,
    );
  }
}

/// 在线解压 API，对齐后端 ExtractController
class ExtractService {
  ExtractService._();

  static final ExtractService instance = ExtractService._();

  final HttpClient _http = HttpClient.instance;

  /// 创建在线解压任务
  ///
  /// [entries] 为空表示整包解压；选择部分条目时只解压选中路径。
  Future<ExtractTask> extract(
    String fileId, {
    String? targetParentId,
    List<String>? entries,
  }) {
    return _http.request<ExtractTask>(
      '/file/extract',
      method: 'POST',
      data: {
        'fileId': fileId,
        if (targetParentId != null) 'targetParentId': targetParentId,
        if (entries != null && entries.isNotEmpty) 'entries': entries,
      },
      dataDecoder: (json) => ExtractTask.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 列出压缩包内条目；只把 path 原样回传给解压接口，不暴露真实文件 ID
  Future<List<ExtractEntry>> entries(String fileId) {
    return _http.request<List<ExtractEntry>>(
      '/file/extract/entries',
      query: {'fileId': fileId},
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => ExtractEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 重试失败的解压任务；后端按检查点跳过已完成条目
  Future<ExtractTask> retry(String taskId) {
    return _http.request<ExtractTask>(
      '/file/extract/retry',
      method: 'POST',
      query: {'taskId': taskId},
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

import '../core/network/http_client.dart';

/// 离线任务状态：0=待开始 1=下载中 2=已完成 3=失败 4=已取消
class OfflineTask {
  const OfflineTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.status,
    required this.progress,
    required this.createTime,
    this.totalSize = 0,
    this.downloadedSize = 0,
    this.errorMsg,
  });

  final String id;
  final String url;
  final String filename;
  final int status;
  final double progress;
  final int totalSize;
  final int downloadedSize;
  final String? errorMsg;
  final String createTime;

  String get statusText {
    switch (status) {
      case 0:
        return '待开始';
      case 1:
        return '下载中';
      case 2:
        return '已完成';
      case 3:
        return '失败';
      case 4:
        return '已取消';
      default:
        return '未知';
    }
  }

  factory OfflineTask.fromJson(Map<String, dynamic> json) {
    return OfflineTask(
      id: (json['id'] ?? json['taskId'] ?? '') as String,
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      status: json['status'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      totalSize: json['totalSize'] as int? ?? 0,
      downloadedSize: json['downloadedSize'] as int? ?? 0,
      errorMsg: json['errorMsg'] ?? json['errorMessage'] as String?,
      createTime: json['createTime'] as String? ?? '',
    );
  }
}

/// 离线下载 API（对齐前端 offlineService）
class OfflineService {
  OfflineService._();

  static final OfflineService instance = OfflineService._();

  final HttpClient _http = HttpClient.instance;

  /// 创建离线下载任务
  Future<dynamic> create({required String url, String? targetFolderId}) {
    return _http.request<dynamic>(
      '/offline/create',
      method: 'POST',
      data: {
        'url': url,
        if (targetFolderId != null) 'targetFolderId': targetFolderId,
      },
    );
  }

  /// 离线任务列表
  Future<List<OfflineTask>> list({String? status}) {
    return _http.request<List<OfflineTask>>(
      '/offline/list',
      query: {if (status != null) 'status': status},
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => OfflineTask.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 取消任务
  Future<dynamic> cancel(String taskId) {
    return _http.request<dynamic>(
      '/offline/cancel',
      method: 'POST',
      query: {'taskId': taskId},
    );
  }

  /// 删除任务
  Future<dynamic> delete(String taskId) {
    return _http.request<dynamic>(
      '/offline',
      method: 'DELETE',
      query: {'taskId': taskId},
    );
  }
}

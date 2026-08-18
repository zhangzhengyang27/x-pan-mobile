import '../core/network/http_client.dart';

/// 预览任务状态：0 待处理 1 转换中 2 完成 3 失败
class PreviewTask {
  const PreviewTask({
    required this.taskId,
    required this.status,
    this.previewUrl = '',
    this.errorMsg = '',
  });

  final String taskId;
  final int status;
  final String previewUrl;
  final String errorMsg;

  factory PreviewTask.fromJson(Map<String, dynamic> json) {
    return PreviewTask(
      taskId: json['taskId'] as String? ?? '',
      status: json['status'] as int? ?? 0,
      previewUrl: json['previewUrl'] as String? ?? '',
      errorMsg: json['errorMsg'] as String? ?? '',
    );
  }
}

/// 文档预览服务（对齐前端 previewService）
///
/// 后端异步任务模型：
/// - POST /preview/office/{fileId}?targetType=pdf  创建/获取预览任务
/// - GET  /preview/url/{taskId}                    轮询预览直链
class PreviewService {
  PreviewService._();

  static final PreviewService instance = PreviewService._();

  final HttpClient _http = HttpClient.instance;

  /// 创建 / 获取文档预览任务
  Future<PreviewTask> office(String fileId, {String targetType = 'pdf'}) {
    return _http.request<PreviewTask>(
      '/preview/office/${Uri.encodeComponent(fileId)}',
      method: 'POST',
      query: {'targetType': targetType},
      dataDecoder: (json) => PreviewTask.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 轮询预览直链
  Future<PreviewTask> url(String taskId) {
    return _http.request<PreviewTask>(
      '/preview/url/${Uri.encodeComponent(taskId)}',
      dataDecoder: (json) => PreviewTask.fromJson(json as Map<String, dynamic>),
    );
  }
}

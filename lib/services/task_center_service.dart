import '../core/network/http_client.dart';
import '../models/api_response.dart';

/// 统一任务中心条目，对齐后端 TaskCenterItemVO。
///
/// taskId 是后端加密串，客户端只原样回传给取消/重试接口，不参与解密。
class TaskCenterItem {
  const TaskCenterItem({
    required this.taskId,
    required this.taskType,
    required this.taskName,
    required this.status,
    required this.createTime,
    this.progress,
    this.errorMsg,
    this.updateTime,
    this.finishTime,
    this.resultFileId,
  });

  final String taskId;
  final String taskType;
  final String taskName;
  final int status;
  final int? progress;
  final String? errorMsg;
  final String createTime;
  final String? updateTime;
  final String? finishTime;
  final String? resultFileId;

  bool get canCancel => status == 0 || status == 1;
  bool get canRetry => status == 3;
  bool get canCancelOffline => taskType == 'offline' && canCancel;
  bool get canRetryArchive => taskType == 'archive' && canRetry;
  bool get canRetryExtract => taskType == 'extract' && canRetry;
  bool get canCancelArchive => taskType == 'archive' && canCancel;

  String get statusText {
    switch (status) {
      case 0:
        return '等待中';
      case 1:
        return '进行中';
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

  String get typeText {
    switch (taskType) {
      case 'offline':
        return '离线下载';
      case 'extract':
        return '在线解压';
      case 'preview':
        return '预览转换';
      case 'archive':
        return '在线压缩';
      default:
        return taskType;
    }
  }

  factory TaskCenterItem.fromJson(Map<String, dynamic> json) {
    return TaskCenterItem(
      taskId: json['taskId'] as String? ?? '',
      taskType: json['taskType'] as String? ?? '',
      taskName: json['taskName'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toInt(),
      errorMsg: json['errorMsg'] as String?,
      createTime: json['createTime'] as String? ?? '',
      updateTime: json['updateTime'] as String?,
      finishTime: json['finishTime'] as String?,
      resultFileId: json['resultFileId'] as String?,
    );
  }
}

/// 统一任务中心 API。
class TaskCenterService {
  TaskCenterService._();

  static final TaskCenterService instance = TaskCenterService._();

  final HttpClient _http = HttpClient.instance;

  Future<PageVO<TaskCenterItem>> list({
    String? types,
    int? status,
    int page = 1,
    int pageSize = 20,
  }) {
    return _http.request<PageVO<TaskCenterItem>>(
      '/tasks/center',
      query: {
        if (types != null && types.isNotEmpty) 'types': types,
        if (status != null) 'status': status,
        'page': page,
        'pageSize': pageSize,
      },
      dataDecoder: (json) => PageVO.fromJson(
        json as Map<String, dynamic>,
        (e) => TaskCenterItem.fromJson(e as Map<String, dynamic>),
      ),
    );
  }

  Future<void> cancelOffline(String taskId) {
    return _http.request<dynamic>(
      '/tasks/center/offline/${Uri.encodeComponent(taskId)}/cancel',
      method: 'POST',
    );
  }

  Future<void> retryArchive(String taskId) {
    return _http.request<dynamic>(
      '/tasks/center/archive/${Uri.encodeComponent(taskId)}/retry',
      method: 'POST',
    );
  }

  Future<void> cancelArchive(String taskId) {
    return _http.request<dynamic>(
      '/tasks/center/archive/${Uri.encodeComponent(taskId)}/cancel',
      method: 'POST',
    );
  }
}

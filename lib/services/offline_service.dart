import 'package:flutter/material.dart';

import '../core/network/http_client.dart';
import '../core/theme/app_tokens.dart';

/// 离线下载任务状态：
/// 0=待开始 1=下载中 2=已完成 3=失败 4=已取消
/// 5=云解压中（下载完成后云端自动解压） 6=做种中（BT/磁力下载后保种）
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
    this.seedSpeed = 0,
    this.peers = 0,
  });

  final String id;
  final String url;
  final String filename;
  final int status;
  final double progress;
  final int totalSize;
  final int downloadedSize;
  final String? errorMsg;
  final int seedSpeed; // 做种速度 bytes/s（status==6 时有效）
  final int peers; // 做种连接的对端数（status==6 时有效）
  final String createTime;

  /// 下载态是否处于"进行中"分类（含下载、云解压、做种）
  bool get isActive =>
      status == 1 || status == 5 || status == 6 || status == 0;

  /// 是否为终端态（已完成/失败/已取消）
  bool get isTerminal => status == 2 || status == 3 || status == 4;

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
      case 5:
        return '云解压中';
      case 6:
        return '做种中';
      default:
        return '未知';
    }
  }

  /// 状态对应的主题色（用于标签与进度条）
  Color statusColor(Brightness brightness) {
    final brand =
        brightness == Brightness.dark ? AppTokens.brandPrimaryDark : AppTokens.brandPrimary;
    switch (status) {
      case 1:
        return brand;
      case 5:
        return Colors.orange;
      case 6:
        return Colors.green;
      case 2:
        return AppTokens.textSecondary(brightness);
      case 3:
        return Colors.red;
      case 4:
        return AppTokens.textSecondary(brightness);
      default:
        return AppTokens.textSecondary(brightness);
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
      seedSpeed: json['seedSpeed'] as int? ?? 0,
      peers: json['peers'] as int? ?? 0,
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

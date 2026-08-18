import '../core/network/http_client.dart';
import '../models/file_vo.dart';

/// 保险箱状态
class VaultStatus {
  const VaultStatus({required this.hasPassword, required this.unlocked});

  final bool hasPassword;
  final bool unlocked;

  factory VaultStatus.fromJson(Map<String, dynamic> json) {
    return VaultStatus(
      hasPassword: json['hasPassword'] as bool? ?? false,
      unlocked: json['unlocked'] as bool? ?? false,
    );
  }
}

/// 隐私保险箱 API，对齐后端 VaultController
class VaultService {
  VaultService._();

  static final VaultService instance = VaultService._();

  final HttpClient _http = HttpClient.instance;

  /// 查询保险箱状态
  Future<VaultStatus> status() {
    return _http.request<VaultStatus>(
      '/vault/status',
      dataDecoder: (json) => VaultStatus.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 首次设置保险箱密码
  Future<dynamic> setup(String password) {
    return _http.request<dynamic>(
      '/vault/setup',
      method: 'POST',
      data: {'password': password},
    );
  }

  /// 解锁保险箱
  Future<dynamic> unlock(String password) {
    return _http.request<dynamic>(
      '/vault/unlock',
      method: 'POST',
      data: {'password': password},
    );
  }

  /// 锁定保险箱
  Future<dynamic> lock() {
    return _http.request<dynamic>('/vault/lock', method: 'POST');
  }

  /// 保险箱文件列表
  Future<List<FileVO>> list() {
    return _http.request<List<FileVO>>(
      '/vault/files',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FileVO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 移入保险箱（fileIds 逗号分隔）
  Future<dynamic> move(String fileIds) {
    return _http.request<dynamic>(
      '/vault/move',
      method: 'POST',
      data: {'fileIds': fileIds},
    );
  }

  /// 移出保险箱到原目录
  Future<dynamic> moveOut(String fileId) {
    return _http.request<dynamic>(
      '/vault/file/${Uri.encodeComponent(fileId)}/out',
      method: 'POST',
    );
  }

  /// 永久删除保险箱文件
  Future<dynamic> destroy(String fileId) {
    return _http.request<dynamic>(
      '/vault/file/${Uri.encodeComponent(fileId)}',
      method: 'DELETE',
    );
  }
}

import '../core/network/http_client.dart';

/// 登录设备信息，对齐前端 DeviceInfo
class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.browser,
    required this.os,
    required this.ip,
    required this.location,
    required this.lastLoginTime,
    required this.isCurrent,
  });

  final String deviceId;
  final String deviceName;
  final String browser;
  final String os;
  final String ip;
  final String location;
  final String lastLoginTime;
  final bool isCurrent;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      browser: json['browser'] as String? ?? '',
      os: json['os'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      location: json['location'] as String? ?? '',
      lastLoginTime: json['lastLoginTime'] as String? ?? '',
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }
}

/// 设备管理 API，对齐后端 DeviceController
class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  final HttpClient _http = HttpClient.instance;

  /// 获取当前用户登录设备列表
  Future<List<DeviceInfo>> list() {
    return _http.request<List<DeviceInfo>>(
      '/device/list',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 远程下线指定设备
  Future<dynamic> logout(String deviceId) {
    return _http.request<dynamic>(
      '/device/logout',
      method: 'POST',
      data: {'deviceId': deviceId},
    );
  }
}

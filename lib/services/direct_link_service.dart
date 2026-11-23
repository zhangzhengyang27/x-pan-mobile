import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/http_client.dart';

/// 直链列表项，对齐后端 XPanDirectLinkVO（id 为加密字符串，禁止转 int）
class DirectLinkVO {
  const DirectLinkVO({
    required this.id,
    required this.fileId,
    required this.filename,
    required this.token,
    required this.enableFlag,
    required this.createTime,
    this.operatorUserId,
    this.expireTime,
  });

  final String id;
  final String fileId;
  final String filename;
  final String token;
  final int enableFlag;
  final String? expireTime;
  final String createTime;
  final String? operatorUserId;

  factory DirectLinkVO.fromJson(Map<String, dynamic> json) {
    return DirectLinkVO(
      id: json['id']?.toString() ?? '',
      fileId: json['fileId'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      token: json['token'] as String? ?? '',
      enableFlag: (json['enableFlag'] as num?)?.toInt() ?? 0,
      expireTime: json['expireTime'] as String?,
      createTime: json['createTime'] as String? ?? '',
      operatorUserId: json['operatorUserId']?.toString(),
    );
  }

  /// 复制到剪贴板/外部浏览器使用的完整 URL。
  /// 必须带 API 前缀，默认部署只反代 /api/，拼 origin 会 404。
  String get url {
    final prefix = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return '$prefix/direct-link/stream?token=$token';
  }
}

/// 文件直链 API，对齐后端 DirectLinkController
class DirectLinkService {
  DirectLinkService._();

  static final DirectLinkService instance = DirectLinkService._();
  final _http = HttpClient.instance;

  Future<DirectLinkVO> create(String fileId) {
    return _http.request<DirectLinkVO>(
      '/direct-link/create',
      method: 'POST',
      data: {'fileId': fileId},
      dataDecoder: (json) => DirectLinkVO.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<DirectLinkVO>> list() {
    return _http.request<List<DirectLinkVO>>(
      '/direct-link/list',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => DirectLinkVO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> toggle(String id, int enableFlag) async {
    await _http.request<dynamic>(
      '/direct-link/toggle',
      method: 'POST',
      data: {'id': id, 'enableFlag': enableFlag},
    );
  }

  Future<void> delete(String id) async {
    await _http.request<dynamic>(
      '/direct-link/delete',
      method: 'POST',
      data: {'id': id},
    );
  }
}

/// 仅用于 debug 打印，避免把 token 完整写进日志。
String maskDirectLinkToken(String token) {
  if (!kDebugMode) return '';
  if (token.length <= 8) return token;
  return '${token.substring(0, 4)}…${token.substring(token.length - 4)}';
}

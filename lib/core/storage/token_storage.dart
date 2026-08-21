import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token 本地安全存储
///
/// 对齐前端 cookie 工具：login_token / share_token
/// 使用 Keychain（iOS）/ Keystore（Android）加密存储，避免明文 token 泄露。
class TokenStorage {
  TokenStorage._();

  static const String _loginTokenKey = 'login_token';
  static const String _shareTokenKey = 'share_token';
  static const String _clientIdKey = 'client_id';

  // flutter_secure_storage 本身使用 Android Keystore / iOS Keychain 加密。
  // 不使用 encryptedSharedPreferences，避免要求 minSdk 23。
  static const _storage = FlutterSecureStorage();

  static Future<void> setToken(String token) async {
    await _storage.write(key: _loginTokenKey, value: token);
  }

  static Future<String> getToken() async {
    return await _storage.read(key: _loginTokenKey) ?? '';
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _loginTokenKey);
  }

  static Future<void> setShareToken(String token) async {
    await _storage.write(key: _shareTokenKey, value: token);
  }

  static Future<String> getShareToken() async {
    return await _storage.read(key: _shareTokenKey) ?? '';
  }

  static Future<void> clearShareToken() async {
    await _storage.delete(key: _shareTokenKey);
  }

  /// 读取本端稳定 clientId（多端并存登录时区分会话）。
  /// 首次调用时生成并持久化，与 token 独立，登出不清除。
  static Future<String> getClientId() async {
    final existing = await _storage.read(key: _clientIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final id = 'app-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    await _storage.write(key: _clientIdKey, value: id);
    return id;
  }
}

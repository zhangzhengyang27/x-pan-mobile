import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// 平台接口为传递依赖，仅用于探测平台实例变化（见 [_ensureCacheOwner]）
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

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

  // ── 内存缓存 ─────────────────────────────────────────
  // 每个请求都要读 token/clientId，直读平台通道开销大；
  // Dart 单线程模型下静态字段无可见性问题，写入/清除时同步更新缓存。
  // null 表示尚未从磁盘加载过。
  static String? _tokenCache;

  static String? _clientIdCache;

  /// 首次并发获取 clientId 时复用同一 Future，保证只生成一次
  static Future<String>? _clientIdFuture;

  /// 缓存归属的平台实例：生产环境实例不变，缓存全程有效；
  /// 测试中 setMockInitialValues 会替换平台实例，据此自动失效全部缓存，
  /// 避免静态缓存跨用例读到已被重置的存储。
  static Object? _cacheOwner;

  static void _ensureCacheOwner() {
    final owner = FlutterSecureStoragePlatform.instance;
    if (!identical(owner, _cacheOwner)) {
      _cacheOwner = owner;
      _tokenCache = null;
      _clientIdCache = null;
      _clientIdFuture = null;
    }
  }

  static Future<void> setToken(String token) async {
    _ensureCacheOwner();
    _tokenCache = token;
    await _storage.write(key: _loginTokenKey, value: token);
  }

  static Future<String> getToken() async {
    _ensureCacheOwner();
    final cached = _tokenCache;
    if (cached != null) return cached;
    final token = await _storage.read(key: _loginTokenKey) ?? '';
    _tokenCache = token;
    return token;
  }

  static Future<void> clearToken() async {
    _ensureCacheOwner();
    _tokenCache = '';
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
  ///
  /// 并发安全：首次调用复用同一 [Future] 完成 read-then-write，
  /// 避免并发请求各自生成不同 id 互相覆盖。
  static Future<String> getClientId() {
    _ensureCacheOwner();
    return _clientIdFuture ??= _loadOrCreateClientId();
  }

  static Future<String> _loadOrCreateClientId() async {
    final cached = _clientIdCache;
    if (cached != null) return cached;
    final existing = await _storage.read(key: _clientIdKey);
    if (existing != null && existing.isNotEmpty) {
      _clientIdCache = existing;
      return existing;
    }
    final id = 'app-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    await _storage.write(key: _clientIdKey, value: id);
    _clientIdCache = id;
    return id;
  }
}

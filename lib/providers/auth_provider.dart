import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../models/user_info.dart';
import '../services/user_service.dart';
import 'notification_provider.dart';

/// 认证状态
enum AuthStatus { unknown, unauthenticated, authenticated }

/// 认证状态数据
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
  });

  final AuthStatus status;
  final UserInfo? user;

  AuthState copyWith({AuthStatus? status, UserInfo? user}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
    );
  }
}

/// 认证状态控制器
///
/// [ref] 为可选项：测试中可直接 `AuthNotifier(fakeService)` 构造，
/// 此时跳过通知联动与全局 relogin 联动之外的引用读取。
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._userService, [this._ref]) : super(const AuthState()) {
    // 订阅全局重新登录事件：任一请求遇到 code=10（token 失效）时，
    // 统一清理登录态，路由 redirect 自动跳回登录页
    _reloginSub = HttpClient.onNeedRelogin.listen((_) {
      unawaited(forceRelogin());
    });
  }

  final UserService _userService;
  final Ref? _ref;
  StreamSubscription<void>? _reloginSub;

  /// 启动时恢复登录态
  Future<void> bootstrap() async {
    final token = await TokenStorage.getToken();
    if (token.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _userService.info();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on NeedReloginException {
      // token 已失效：清 token 回登录页
      await forceRelogin();
    } on ApiException catch (e) {
      if (e.code == 401) {
        // 明确鉴权失败：清 token 回登录页
        await forceRelogin();
      } else {
        // 网络超时/连接异常等：保留 token，先进入已登录（离线态），
        // 不误清本地登录态，下次启动再验证
        state = state.copyWith(status: AuthStatus.authenticated);
      }
    }
  }

  /// 登录
  ///
  /// 登录接口返回的是 JWT token，先保存 token，再拉取用户信息。
  /// 若拉取用户信息失败，回滚已写入的 token，避免本地残留孤儿 token。
  Future<void> login(String username, String password) async {
    final token =
        await _userService.login(username: username, password: password);
    await TokenStorage.setToken(token);
    try {
      final user = await _userService.info();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      await TokenStorage.clearToken();
      rethrow;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _userService.exit();
    } catch (_) {
      // 忽略登出接口错误，本地仍清理
    }
    // 停止实时通知并复位（收敛在此统一处理，使下次登录 start() 能完整重建连接）
    _ref?.read(notificationProvider.notifier).stop();
    await TokenStorage.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// 强制重新登录（token 失效统一出口）
  ///
  /// 清理本地登录态并停止通知；不调用服务端登出接口（token 已失效，避免循环触发）。
  Future<void> forceRelogin() async {
    // 已在未登录态则跳过，避免并发 code=10 触发重复处理
    if (state.status == AuthStatus.unauthenticated) return;
    _ref?.read(notificationProvider.notifier).stop();
    await TokenStorage.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    _reloginSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(UserService.instance, ref);
});

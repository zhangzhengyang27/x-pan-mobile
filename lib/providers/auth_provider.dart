import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/token_storage.dart';
import '../models/user_info.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

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
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._userService) : super(const AuthState());

  final UserService _userService;

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
    } catch (_) {
      await TokenStorage.clearToken();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// 登录
  Future<void> login(String username, String password) async {
    final user = await _userService.login(username: username, password: password);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _userService.exit();
    } catch (_) {
      // 忽略登出接口错误，本地仍清理
    }
    // 断开实时通知连接（避免用失效 token 保持连接）
    NotificationService.instance.disconnect();
    await TokenStorage.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(UserService.instance);
});

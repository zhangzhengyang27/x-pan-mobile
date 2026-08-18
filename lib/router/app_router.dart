import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../providers/auth_provider.dart';

/// 应用路由（基于 go_router）
///
/// 通过 refreshListenable 在认证状态变化时自动 redirect
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authStatus = ref.read(authProvider).status;

      final loggingIn = state.matchedLocation == '/login';
      final registering = state.matchedLocation == '/register';

      // 启动阶段：尚未确定登录态，放行由各页面自行处理
      if (authStatus == AuthStatus.unknown) return null;

      if (authStatus == AuthStatus.unauthenticated) {
        // 未登录：仅允许访问登录/注册页，其余跳登录
        return (loggingIn || registering) ? null : '/login';
      }

      // 已登录：访问登录/注册页则回主页
      return (loggingIn || registering) ? '/' : null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
    ],
  );

  // 认证状态变化时刷新路由
  ref.listen(authProvider, (_, __) {
    router.refresh();
  });

  return router;
});

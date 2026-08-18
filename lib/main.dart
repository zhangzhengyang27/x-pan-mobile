import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'router/app_router.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化本地通知（后台系统推送）
  await LocalNotificationService.instance.init();
  runApp(const ProviderScope(child: XPanApp()));
}

class XPanApp extends ConsumerStatefulWidget {
  const XPanApp({super.key});

  @override
  ConsumerState<XPanApp> createState() => _XPanAppState();
}

class _XPanAppState extends ConsumerState<XPanApp> {
  @override
  void initState() {
    super.initState();
    // 启动时恢复登录态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'R Pan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

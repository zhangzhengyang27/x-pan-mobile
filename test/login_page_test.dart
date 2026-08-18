import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:x_pan_mobile/models/user_info.dart';
import 'package:x_pan_mobile/pages/login_page.dart';
import 'package:x_pan_mobile/providers/auth_provider.dart';
import 'package:x_pan_mobile/services/user_service.dart';

/// 测试用 Fake AuthNotifier，模拟登录，不触发真实网络
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier() : super(_FakeUserService());

  bool loginCalled = false;
  String? lastUsername;
  String? lastPassword;
  bool shouldFail = false;

  @override
  Future<void> login(String username, String password) async {
    loginCalled = true;
    lastUsername = username;
    lastPassword = password;
    if (shouldFail) {
      throw Exception('登录失败');
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      user: UserInfo(
        userId: 'u1',
        username: username,
        rootFileId: 'root',
        rootFilename: '全部文件',
        usedSize: 0,
        totalSize: 1000,
      ),
    );
  }

  @override
  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// 测试用空 UserService（不触发网络）
class _FakeUserService extends UserService {
  _FakeUserService();
}

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: LoginPage()),
  );
}

void main() {
  late FakeAuthNotifier fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthNotifier();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => fakeAuth),
      ],
    );
  }

  testWidgets('渲染登录页关键元素', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(_wrap(container));

    expect(find.text('R Pan'), findsOneWidget);
    expect(find.text('个人分布式存储'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    expect(find.text('没有账号？去注册'), findsOneWidget);
    expect(find.text('忘记密码？'), findsOneWidget);

    container.dispose();
  });

  testWidgets('空用户名/密码时点击登录不调用 login', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(_wrap(container));

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();

    expect(fakeAuth.loginCalled, isFalse);

    container.dispose();
  });

  testWidgets('填写表单后登录调用 login 并携带参数', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(_wrap(container));

    await tester.enterText(find.byType(TextFormField).at(0), 'zhang');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();

    expect(fakeAuth.loginCalled, isTrue);
    expect(fakeAuth.lastUsername, 'zhang');
    expect(fakeAuth.lastPassword, '12345678');

    container.dispose();
  });

  testWidgets('登录失败时显示错误 SnackBar', (tester) async {
    fakeAuth.shouldFail = true;
    final container = makeContainer();
    await tester.pumpWidget(_wrap(container));

    await tester.enterText(find.byType(TextFormField).at(0), 'zhang');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();
    await tester.pump(); // 等待 SnackBar 动画

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('登录失败'), findsOneWidget);

    container.dispose();
  });

  testWidgets('密码可见性切换', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(_wrap(container));

    // 初始为隐藏（obscure），密码框对应第 2 个 TextField
    final passwordFields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    // 密码框有 obscureText=true
    final initialObscure = passwordFields.any((e) => e.obscureText);
    expect(initialObscure, isTrue);

    // 点击眼睛图标切换
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    final afterFields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    final afterObscure = afterFields.any((e) => e.obscureText);
    expect(afterObscure, isFalse);

    container.dispose();
  });

  testWidgets('点击注册跳转注册页', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(_wrap(container));

    await tester.tap(find.text('没有账号？去注册'));
    await tester.pumpAndSettle();

    expect(find.text('注册'), findsWidgets);

    container.dispose();
  });
}

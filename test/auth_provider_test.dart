import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:x_pan_mobile/core/storage/token_storage.dart';
import 'package:x_pan_mobile/models/user_info.dart';
import 'package:x_pan_mobile/providers/auth_provider.dart';
import 'package:x_pan_mobile/services/user_service.dart';

/// 测试用 Fake UserService：login 返回 token，info 返回用户信息
class _FakeUserService extends UserService {
  _FakeUserService();

  String? lastLoginUsername;
  String? lastLoginPassword;
  int loginCalls = 0;
  int infoCalls = 0;
  bool failLogin = false;

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    lastLoginUsername = username;
    lastLoginPassword = password;
    if (failLogin) throw Exception('登录失败');
    return 'jwt-token';
  }

  @override
  Future<UserInfo> info() async {
    infoCalls++;
    return const UserInfo(
      userId: 'u1',
      username: 'zhang',
      rootFileId: 'root',
      rootFilename: '全部文件',
      usedSize: 0,
      totalSize: 1000,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  late _FakeUserService fakeService;

  setUp(() {
    fakeService = _FakeUserService();
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('login 保存 token 并拉取用户信息', () async {
    final notifier = AuthNotifier(fakeService);
    await notifier.login('zhang', '12345678');

    // token 被保存
    expect(await TokenStorage.getToken(), 'jwt-token');
    // 调用 login 与 info
    expect(fakeService.loginCalls, 1);
    expect(fakeService.infoCalls, 1);
    expect(fakeService.lastLoginUsername, 'zhang');
    expect(fakeService.lastLoginPassword, '12345678');
    // 状态为已登录且携带用户信息
    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.user?.username, 'zhang');
  });

  test('login 失败时不写入登录态', () async {
    fakeService.failLogin = true;
    final notifier = AuthNotifier(fakeService);

    await expectLater(notifier.login('zhang', '12345678'), throwsException);
    // 状态仍为 unknown
    expect(notifier.state.status, AuthStatus.unknown);
  });

  test('bootstrap 无 token 时为未登录', () async {
    final notifier = AuthNotifier(fakeService);
    await notifier.bootstrap();
    expect(notifier.state.status, AuthStatus.unauthenticated);
  });
}

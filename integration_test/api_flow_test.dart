import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:x_pan_mobile/core/storage/token_storage.dart';
import 'package:x_pan_mobile/models/user_info.dart';
import 'package:x_pan_mobile/services/offline_service.dart';
import 'package:x_pan_mobile/services/share_service.dart';
import 'package:x_pan_mobile/services/upload_service.dart';
import 'package:x_pan_mobile/services/user_service.dart';

/// 真实后端全链路集成测试：登录 → 上传 → 分享 → 离线任务创建/取消。
///
/// 运行前置：
/// - 后端已启动，且被测账号已注册；
/// - Android 模拟器用 `X_PAN_API_BASE_URL=http://10.0.2.2:<port>` 指向宿主机；
/// - 通过 `--dart-define=XPAN_IT_USERNAME/XPAN_IT_PASSWORD` 注入测试账号。
///
/// 不写死账号密码：CI 在 job 内注册临时账号后注入，本地不配置时整组跳过，
/// 避免把真实凭据提交进仓库。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const username = String.fromEnvironment('XPAN_IT_USERNAME');
  const password = String.fromEnvironment('XPAN_IT_PASSWORD');
  final skipReason = username.isEmpty || password.isEmpty
      ? '未设置 XPAN_IT_USERNAME/XPAN_IT_PASSWORD，跳过真实后端集成测试'
      : null;

  group('移动端真实后端链路', () {
    test('登录 → 上传 → 分享 → 离线任务创建/取消', () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'it-$stamp.txt';
      UserInfo? user;
      String? uploadedFileId;
      ShareVO? share;
      OfflineTask? offlineTask;

      try {
        // 1. 登录并保存 token（与 AuthNotifier.login 一致，先存 token 再取用户信息）
        final token = await UserService.instance.login(
          username: username,
          password: password,
        );
        await TokenStorage.setToken(token);
        user = await UserService.instance.info();
        expect(user.rootFileId, isNotEmpty);

        // 2. 上传一个小文件到根目录，随后从列表确认落库
        final tempDir = await Directory.systemTemp.createTemp('xpan-it-');
        final localFile = File('${tempDir.path}/$filename');
        await localFile.writeAsString('x-pan integration test $stamp\n');
        await UploadService.instance.uploadFile(
          file: localFile,
          parentId: user.rootFileId,
        );

        final rootList = await FileService.instance.list(
          parentId: user.rootFileId,
          keyword: filename,
          pageSize: 20,
        );
        final uploaded = rootList.records.firstWhere(
          (f) => f.filename == filename,
          orElse: () => throw StateError('上传后列表未找到 $filename'),
        );
        uploadedFileId = uploaded.fileId;
        expect(uploaded.folderFlag, 0);

        // 3. 创建分享并确认分享列表可见（shareType=1 表示文件分享）
        share = await ShareService.instance.create(
          shareName: 'IT-$stamp',
          fileIds: [uploadedFileId],
          shareDayType: 0,
        );
        expect(share.shareId, isNotEmpty);
        final shares = await ShareService.instance.list();
        expect(shares.any((s) => s.shareId == share!.shareId), isTrue);

        // 4. 离线任务：只验证创建/列表/取消链路，不依赖真实下载完成。
        //    example.com 仅作为合法公网 URL，任务会由后端异步处理。
        await OfflineService.instance.create(
          url: 'https://example.com/x-pan-it-$stamp.html',
          targetFolderId: user.rootFileId,
        );
        final tasks = await OfflineService.instance.list();
        offlineTask = tasks.firstWhere(
          (t) => t.url.contains('x-pan-it-$stamp'),
          orElse: () => throw StateError('离线任务列表未找到本次任务'),
        );
        await OfflineService.instance.cancel(offlineTask.id);
      } finally {
        // 清理失败不影响断言结果，但会打印，便于排查残留数据
        try {
          if (share != null) {
            await ShareService.instance.cancel([share.shareId]);
          }
        } catch (e) {
          // ignore: avoid_print
          print('清理分享失败: $e');
        }
        try {
          if (uploadedFileId != null) {
            await FileService.instance.delete([uploadedFileId]);
          }
        } catch (e) {
          // ignore: avoid_print
          print('清理文件失败: $e');
        }
        try {
          if (offlineTask != null) {
            await OfflineService.instance.delete(offlineTask.id);
          }
        } catch (e) {
          // ignore: avoid_print
          print('清理离线任务失败: $e');
        }
        await TokenStorage.clearToken();
      }
    }, skip: skipReason);
  });
}

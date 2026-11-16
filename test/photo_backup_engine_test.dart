import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:x_pan_mobile/core/photo/backup_record_store.dart';
import 'package:x_pan_mobile/core/photo/photo_asset_source.dart';
import 'package:x_pan_mobile/core/photo/photo_backup_engine.dart';

class FakeAssetSource implements PhotoAssetSource {
  FakeAssetSource(this.assets, {this.permission = true});
  final List<BackupAsset> assets;
  final bool permission;
  int permissionCalls = 0;

  @override
  Future<bool> ensurePermission() async {
    permissionCalls++;
    return permission;
  }

  @override
  Future<List<BackupAsset>> recentAssets() async => assets;
}

/// fake 资产：toFile 返回预生成的真实临时文件（size 由文件内容决定）
class FakeBackupAsset extends BackupAsset {
  FakeBackupAsset({
    required String id,
    required File file,
    required DateTime modified,
    bool screenshot = false,
    bool video = false,
  }) : super(
          assetId: id,
          fileName: file.uri.pathSegments.last,
          modifiedTime: modified,
          takenTime: modified,
          isVideo: video,
          isScreenshot: screenshot,
        ) {
    _file = file;
  }

  File? _file;

  @override
  Future<File?> toFile() async => _file;

  @override
  Future<File?> originFile() async => _file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BackupRecordStore store;
  late List<(File, String)> enqueued;

  File writeAssetFile(String name, List<int> bytes) {
    final f = File('${tempDir.path}/$name')..writeAsBytesSync(bytes);
    return f;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('photo_backup_engine_test');
    store = BackupRecordStore();
    enqueued = [];
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  PhotoBackupEngine buildEngine(FakeAssetSource source) {
    return PhotoBackupEngine(
      assetSource: source,
      recordStore: store,
      dirResolver: (rel) async => 'folder-${rel.hashCode}',
      enqueuer: (file, parentId) async => enqueued.add((file, parentId)),
      tempRoot: tempDir,
    );
  }

  test('新资产入队且分类正确（截图→截图目录、照片→月份目录）', () async {
    final source = FakeAssetSource([
      FakeBackupAsset(id: 'p1', file: writeAssetFile('photo1.jpg', [1, 2, 3]), modified: DateTime(2026, 11, 10)),
      FakeBackupAsset(id: 's1', file: writeAssetFile('shot1.jpg', [4]), screenshot: true, modified: DateTime(2026, 11, 11)),
    ]);
    final result = await buildEngine(source).scanAndEnqueue(force: true);

    expect(result.enqueued, 2);
    expect(result.needsPermission, isFalse);
    final dirs = enqueued.map((e) => e.$2).toSet();
    expect(dirs, contains('folder-${'相册备份/2026-11'.hashCode}'));
    expect(dirs, contains('folder-${'相册备份/截图'.hashCode}'));
    // 文件名保留原文件名
    expect(enqueued.map((e) => e.$1.uri.pathSegments.last), containsAll(['photo1.jpg', 'shot1.jpg']));
  });

  test('已备份（三元组一致）资产跳过且清理临时文件', () async {
    final f = writeAssetFile('again.jpg', [9, 9]);
    final source = FakeAssetSource([
      FakeBackupAsset(id: 'x1', file: f, modified: DateTime(2026, 11, 16)),
    ]);
    final engine = buildEngine(source);
    await engine.scanAndEnqueue(force: true);
    expect(enqueued.length, 1);
    await store.markBackedUp('x1', DateTime(2026, 11, 16).millisecondsSinceEpoch, 2);

    final result = await engine.scanAndEnqueue(force: true);
    expect(result.skipped, 1);
    expect(enqueued.length, 1); // 已备份资产不得重复入队
  });

  test('权限拒绝 → needsPermission，不入队不解析目录', () async {
    final source = FakeAssetSource([
      FakeBackupAsset(id: 'p1', file: writeAssetFile('p.jpg', [1]), modified: DateTime(2026, 11, 1)),
    ], permission: false);
    final result = await buildEngine(source).scanAndEnqueue(force: true);

    expect(result.needsPermission, isTrue);
    expect(result.enqueued, 0);
    expect(source.permissionCalls, 1); // 每次扫描都应检查权限
  });

  test('前后台并发互斥：标记被占用（未过期）→ 本次全部跳过', () async {
    final sp = SharedPreferences.getInstance();
    await (await sp).setString('photo_backup_running', DateTime.now().toIso8601String());

    final source = FakeAssetSource([
      FakeBackupAsset(id: 'p1', file: writeAssetFile('p.jpg', [1]), modified: DateTime(2026, 11, 1)),
    ]);
    final result = await buildEngine(source).scanAndEnqueue(force: true);

    expect(result.error, 'another-backup-running');
    expect(enqueued, isEmpty);
    expect(result.enqueued, 0);
  });

  test('分批入队：21 个新资产首批 20 个，剩余留待下次扫描', () async {
    final assets = <BackupAsset>[];
    for (var i = 0; i < 21; i++) {
      assets.add(FakeBackupAsset(
        id: 'a$i',
        file: writeAssetFile('a$i.jpg', [i]),
        modified: DateTime(2026, 10, 1 + i % 28),
      ));
    }
    final result = await buildEngine(FakeAssetSource(assets)).scanAndEnqueue(force: true);

    expect(result.enqueued, kBatchSize); // 首批仅入队 20 个
    expect(result.skipped, 1); // 超出批量的部分留待下次扫描
    expect(enqueued.length, kBatchSize);
  });

  test('节流：距上次扫描 < 10 分钟且未 force → 跳过', () async {
    final source = FakeAssetSource([
      FakeBackupAsset(id: 'p1', file: writeAssetFile('p.jpg', [1]), modified: DateTime(2026, 11, 1)),
    ]);
    final engine = buildEngine(source);
    await engine.scanAndEnqueue(force: true);
    final firstCount = enqueued.length;

    final result = await engine.scanAndEnqueue(); // 无 force
    expect(result.enqueued, 0); // 节流期内非强制扫描应跳过
    expect(enqueued.length, firstCount);
  });
}

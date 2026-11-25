import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:x_pan_mobile/core/storage/upload_task_storage.dart';

/// 上传任务持久化并发回归测试
///
/// 背景：save/remove 都是"读全部 → 修改 → 整串写回"，并发调用时
/// 后写覆盖先写——恢复上传进行中用户又操作另一条记录会丢失更新
/// （任务记录凭空消失，下次启动不再提示续传）。
///
/// 契约：写操作经内部队列串行化，并发 save/remove 全部生效、互不覆盖。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  UploadTaskRecord record(String identifier, {String name = 'file.txt'}) {
    return UploadTaskRecord(
      filePath: '/tmp/$identifier',
      filename: name,
      parentId: 'root',
      identifier: identifier,
      totalSize: 100,
      totalChunks: 1,
    );
  }

  test('并发 save 多条记录全部保留，互不覆盖', () async {
    await Future.wait([
      UploadTaskStorage.save(record('a')),
      UploadTaskStorage.save(record('b')),
      UploadTaskStorage.save(record('c')),
      UploadTaskStorage.save(record('d')),
      UploadTaskStorage.save(record('e')),
    ]);

    final all = await UploadTaskStorage.getAll();
    final ids = all.map((r) => r.identifier).toSet();
    // 并发写全部生效（旧实现读改写竞态会互相覆盖丢记录）
    expect(ids, containsAll(['a', 'b', 'c', 'd', 'e']));
  });

  test('并发 save 与 remove 混合，结果与串行语义一致', () async {
    await UploadTaskStorage.save(record('keep-1'));
    await UploadTaskStorage.save(record('keep-2'));
    await UploadTaskStorage.save(record('doomed'));

    await Future.wait([
      UploadTaskStorage.save(record('added')),
      UploadTaskStorage.remove('doomed'),
      UploadTaskStorage.remove('doomed'), // 幂等
    ]);

    final ids = (await UploadTaskStorage.getAll()).map((r) => r.identifier).toSet();
    expect(ids, {'keep-1', 'keep-2', 'added'});
    expect(ids.contains('doomed'), isFalse);
  });

  test('clear 清空全部待续传记录', () async {
    await UploadTaskStorage.save(record('old-a'));
    await UploadTaskStorage.save(record('old-b'));

    await UploadTaskStorage.clear();

    expect(await UploadTaskStorage.getAll(), isEmpty);
  });

  test('同 identifier 并发 save 幂等去重', () async {
    await Future.wait([
      UploadTaskStorage.save(record('dup', name: 'v1.txt')),
      UploadTaskStorage.save(record('dup', name: 'v2.txt')),
    ]);
    final all = await UploadTaskStorage.getAll();
    // 同 identifier 只保留一条
    expect(all.where((r) => r.identifier == 'dup').length, 1);
  });
}

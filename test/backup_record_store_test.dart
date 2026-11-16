import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:x_pan_mobile/core/photo/backup_record_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('标记后判定为已备份（三元组一致）', () async {
    final store = BackupRecordStore();
    expect(store.isBackedUp('a1', 1700000000000, 1024), isFalse);
    await store.markBackedUp('a1', 1700000000000, 1024);
    expect(store.isBackedUp('a1', 1700000000000, 1024), isTrue);
    expect(store.count, 1);
  });

  test('同 assetId 内容变更（mtime 或 size 不同）视为未备份 → 自动重传', () async {
    final store = BackupRecordStore();
    await store.markBackedUp('a1', 1700000000000, 1024);
    expect(store.isBackedUp('a1', 1700000001000, 1024), isFalse, reason: 'mtime 变化须重传');
    expect(store.isBackedUp('a1', 1700000000000, 2048), isFalse, reason: 'size 变化须重传');
  });

  test('记录跨实例持久化（SP 落盘）', () async {
    final store = BackupRecordStore();
    await store.markBackedUp('a1', 1700000000000, 1024);
    final store2 = BackupRecordStore();
    await store2.load();
    expect(store2.isBackedUp('a1', 1700000000000, 1024), isTrue);
  });

  test('clear() 清空全部记录', () async {
    final store = BackupRecordStore();
    await store.markBackedUp('a1', 1, 1);
    await store.clear();
    expect(store.count, 0);
  });
}

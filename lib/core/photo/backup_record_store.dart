import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 相册备份记录库：assetId → {mtime, size} 三元组。
/// 判定"已备份"= 记录存在且 mtime/size 均一致（内容变更必然改变二者 → 自动重传）。
class BackupRecordStore {
  static const String _key = 'photo_backup_records';

  /// 内存缓存：assetId → "mtimeMillis|size"（一次 SP 读全量载入）
  final Map<String, String> _records = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _records
        ..clear()
        ..addAll(decoded.cast<String, String>());
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(_records));
  }

  Future<void> markBackedUp(String assetId, int mtimeMillis, int size) async {
    await load();
    _records[assetId] = '$mtimeMillis|$size';
    await _persist();
  }

  bool isBackedUp(String assetId, int mtimeMillis, int size) {
    return _records[assetId] == '$mtimeMillis|$size';
  }

  int get count => _records.length;

  Future<void> clear() async {
    _records.clear();
    await _persist();
  }
}

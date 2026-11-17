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
    // M1：批量模式下单次扫描结束后统一落盘（由 engine 调 flushPending），
    // 单条调用时仍立即持久化
    if (_batchMode) {
      _dirty = true;
    } else {
      await _persist();
    }
  }

  /// 批量持久化模式：扫描开始/结束配对调用，避免 20 条逐条重写 SP
  bool _batchMode = false;
  bool _dirty = false;

  void beginBatch() { _batchMode = true; }
  Future<void> endBatch() async {
    _batchMode = false;
    if (_dirty) { await _persist(); _dirty = false; }
  }

  /// M1：清理已不在相册中的过期记录（简单按数量裁剪：>50000 条时保留最新 25000 条）
  Future<void> prune() async {
    if (_records.length <= 50000) return;
    final sorted = _records.entries.toList()
      ..sort((a, b) => b.value.split('|')[0].compareTo(a.value.split('|')[0]));
    _records
      ..clear()
      ..addEntries(sorted.take(25000));
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

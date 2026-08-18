import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 未完成的上传任务元信息（用于跨 App 重启恢复）
class UploadTaskRecord {
  const UploadTaskRecord({
    required this.filePath,
    required this.filename,
    required this.parentId,
    required this.identifier,
    required this.totalSize,
    required this.totalChunks,
  });

  final String filePath;
  final String filename;
  final String parentId;
  final String identifier;
  final int totalSize;
  final int totalChunks;

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'filename': filename,
        'parentId': parentId,
        'identifier': identifier,
        'totalSize': totalSize,
        'totalChunks': totalChunks,
      };

  factory UploadTaskRecord.fromJson(Map<String, dynamic> json) {
    return UploadTaskRecord(
      filePath: json['filePath'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      parentId: json['parentId'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      totalSize: json['totalSize'] as int? ?? 0,
      totalChunks: json['totalChunks'] as int? ?? 0,
    );
  }
}

/// 上传任务持久化存储
///
/// 保存未完成的上传任务，App 重启后可恢复（断点续传）。
class UploadTaskStorage {
  UploadTaskStorage._();

  static const String _key = 'pending_upload_tasks';

  static Future<void> save(UploadTaskRecord record) async {
    final sp = await SharedPreferences.getInstance();
    final list = await getAll();
    // 用 identifier 去重（同一文件覆盖）
    list.removeWhere((r) => r.identifier == record.identifier);
    list.add(record);
    await sp.setString(
      _key,
      jsonEncode(list.map((r) => r.toJson()).toList()),
    );
  }

  static Future<List<UploadTaskRecord>> getAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => UploadTaskRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 移除已完成/取消的任务
  static Future<void> remove(String identifier) async {
    final sp = await SharedPreferences.getInstance();
    final list = await getAll();
    list.removeWhere((r) => r.identifier == identifier);
    await sp.setString(
      _key,
      jsonEncode(list.map((r) => r.toJson()).toList()),
    );
  }
}

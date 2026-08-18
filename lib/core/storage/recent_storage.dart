import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 最近访问记录项
class RecentItem {
  const RecentItem({
    required this.fileId,
    required this.filename,
    required this.fileType,
    required this.visitTime,
  });

  final String fileId;
  final String filename;
  final int fileType;
  final String visitTime;

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'filename': filename,
        'fileType': fileType,
        'visitTime': visitTime,
      };

  factory RecentItem.fromJson(Map<String, dynamic> json) {
    return RecentItem(
      fileId: json['fileId'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      fileType: json['fileType'] as int? ?? 1,
      visitTime: json['visitTime'] as String? ?? '',
    );
  }
}

/// 最近访问记录存储
///
/// 对齐网页版 useRecent（localStorage），移动端用 SharedPreferences。
/// 最多保存 20 条。
class RecentStorage {
  RecentStorage._();

  static const String _key = 'recent_files';
  static const int _maxCount = 20;

  static Future<void> add(RecentItem item) async {
    final sp = await SharedPreferences.getInstance();
    final list = await getAll();
    // 去重：同一文件只保留最新
    list.removeWhere((r) => r.fileId == item.fileId);
    list.insert(0, item);
    if (list.length > _maxCount) {
      list.removeRange(_maxCount, list.length);
    }
    await sp.setString(
      _key,
      jsonEncode(list.map((r) => r.toJson()).toList()),
    );
  }

  static Future<List<RecentItem>> getAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RecentItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}

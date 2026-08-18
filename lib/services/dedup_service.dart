import '../core/network/http_client.dart';

/// 重复文件项，对齐前端 IDedupItemVO
class DedupItem {
  const DedupItem({
    required this.fileId,
    required this.filename,
    required this.parentId,
  });

  final String fileId;
  final String filename;
  final String parentId;

  factory DedupItem.fromJson(Map<String, dynamic> json) {
    return DedupItem(
      fileId: json['fileId'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      parentId: json['parentId'] as String? ?? '',
    );
  }
}

/// 重复文件分组，对齐前端 IDedupGroupVO
class DedupGroup {
  const DedupGroup({
    required this.realFileId,
    required this.fileSize,
    required this.fileSizeDesc,
    required this.refCount,
    required this.releasableBytes,
    required this.items,
  });

  final String realFileId;
  final int fileSize;
  final String fileSizeDesc;
  final int refCount;
  final int releasableBytes;
  final List<DedupItem> items;

  factory DedupGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return DedupGroup(
      realFileId: json['realFileId'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      fileSizeDesc: json['fileSizeDesc'] as String? ?? '',
      refCount: json['refCount'] as int? ?? 0,
      releasableBytes: json['releasableBytes'] as int? ?? 0,
      items: rawItems.map((e) => DedupItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// 去重统计，对齐前端 IDedupStatVO
class DedupStat {
  const DedupStat({
    required this.groupCount,
    required this.redundantCount,
    required this.releasableBytes,
    required this.releasableDesc,
  });

  final int groupCount;
  final int redundantCount;
  final int releasableBytes;
  final String releasableDesc;

  factory DedupStat.fromJson(Map<String, dynamic> json) {
    return DedupStat(
      groupCount: json['groupCount'] as int? ?? 0,
      redundantCount: json['redundantCount'] as int? ?? 0,
      releasableBytes: json['releasableBytes'] as int? ?? 0,
      releasableDesc: json['releasableDesc'] as String? ?? '',
    );
  }
}

/// 文件去重 API，对齐后端 FileDedupController
class DedupService {
  DedupService._();

  static final DedupService instance = DedupService._();

  final HttpClient _http = HttpClient.instance;

  /// 查询重复文件分组
  Future<List<DedupGroup>> list() {
    return _http.request<List<DedupGroup>>(
      '/file/dedup/list',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => DedupGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 去重统计
  Future<DedupStat> stat() {
    return _http.request<DedupStat>(
      '/file/dedup/stat',
      dataDecoder: (json) => DedupStat.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 释放冗余引用（保留指定文件）
  Future<dynamic> release(List<String> keepFileIds) {
    return _http.request<dynamic>(
      '/file/dedup/release',
      method: 'POST',
      data: {'keepFileIds': keepFileIds},
    );
  }
}

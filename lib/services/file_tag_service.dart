import '../core/network/http_client.dart';

/// 文件标签，对齐前端 FileTagItem
class FileTagItem {
  const FileTagItem({
    required this.id,
    required this.fileId,
    required this.tagName,
    required this.tagSource,
    required this.createTime,
  });

  final String id;
  final String fileId;
  final String tagName;
  final int tagSource; // 0 自动 1 手动
  final String createTime;

  bool get isAuto => tagSource == 0;

  factory FileTagItem.fromJson(Map<String, dynamic> json) {
    return FileTagItem(
      id: json['id'] as String? ?? '',
      fileId: json['fileId'] as String? ?? '',
      tagName: json['tagName'] as String? ?? '',
      tagSource: json['tagSource'] as int? ?? 1,
      createTime: json['createTime'] as String? ?? '',
    );
  }
}

/// 文件标签 API，对齐后端 FileTagController
class FileTagService {
  FileTagService._();

  static final FileTagService instance = FileTagService._();

  final HttpClient _http = HttpClient.instance;

  /// 自动打标（后端规则匹配，降级方案，无需 DeepSeek）
  Future<List<FileTagItem>> autoTag(String fileId) {
    return _http.request<List<FileTagItem>>(
      '/file/auto-tag',
      method: 'POST',
      data: {'fileId': fileId},
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FileTagItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 查询文件标签列表
  Future<List<FileTagItem>> list(String fileId) {
    return _http.request<List<FileTagItem>>(
      '/file/${Uri.encodeComponent(fileId)}/tags',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FileTagItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 手动添加标签
  Future<FileTagItem> addTag(String fileId, String tagName) {
    return _http.request<FileTagItem>(
      '/file/${Uri.encodeComponent(fileId)}/tags',
      method: 'POST',
      data: {'tagName': tagName},
      dataDecoder: (json) => FileTagItem.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 删除标签
  Future<dynamic> removeTag(String tagId) {
    return _http.request<dynamic>(
      '/file/tags/${Uri.encodeComponent(tagId)}',
      method: 'DELETE',
    );
  }
}

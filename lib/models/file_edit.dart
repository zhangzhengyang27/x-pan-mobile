/// 文件详情（在线编辑场景）
class FileDetail {
  const FileDetail({
    required this.fileId,
    required this.filename,
    required this.version,
    this.editable = false,
    this.fileSizeDesc,
    this.sizeBytes,
    this.contentHash,
  });

  final String fileId;
  final String filename;
  final int version;
  final bool editable;
  final String? fileSizeDesc;
  final int? sizeBytes;
  final String? contentHash;

  factory FileDetail.fromJson(Map<String, dynamic> json) {
    return FileDetail(
      fileId: json['fileId'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      editable: json['editable'] as bool? ?? false,
      fileSizeDesc: json['fileSizeDesc'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      contentHash: json['contentHash'] as String?,
    );
  }
}

/// 编辑锁会话
class EditSession {
  const EditSession({required this.lockToken, required this.version});

  final String lockToken;
  final int version;

  factory EditSession.fromJson(Map<String, dynamic> json) {
    return EditSession(
      lockToken: json['lockToken'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 文件内容保存结果
class FileContentSaveResult {
  const FileContentSaveResult({
    required this.version,
    required this.contentHash,
    required this.sizeBytes,
  });

  final int version;
  final String contentHash;
  final int sizeBytes;

  factory FileContentSaveResult.fromJson(Map<String, dynamic> json) {
    return FileContentSaveResult(
      version: (json['version'] as num?)?.toInt() ?? 1,
      contentHash: json['contentHash'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 文件版本信息，对齐前端 IFileVersionVO
class FileVersion {
  const FileVersion({
    required this.id,
    required this.fileId,
    required this.versionNumber,
    required this.filename,
    required this.fileSize,
    required this.realPath,
    required this.identifier,
    required this.operation,
    required this.operatorId,
    required this.current,
    required this.createTime,
    this.operatorName,
    this.comment,
  });

  final String id;
  final String fileId;
  final int versionNumber;
  final String filename;
  final String fileSize;
  final String realPath;
  final String identifier;
  final String operation;
  final String operatorId;
  final bool current;
  final String createTime;
  final String? operatorName;
  final String? comment;

  factory FileVersion.fromJson(Map<String, dynamic> json) {
    final rawSize = json['fileSize'];
    return FileVersion(
      id: json['id'] as String? ?? '',
      fileId: json['fileId'] as String? ?? '',
      versionNumber: json['versionNumber'] as int? ?? 0,
      filename: json['filename'] as String? ?? '',
      fileSize: rawSize?.toString() ?? '',
      realPath: json['realPath'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      operation: json['operation'] as String? ?? '',
      operatorId: json['operatorId'] as String? ?? '',
      current: json['current'] as bool? ?? false,
      createTime: json['createTime'] as String? ?? '',
      operatorName: json['operatorName'] as String?,
      comment: json['comment'] as String?,
    );
  }

  String get operationText {
    switch (operation) {
      case 'UPLOAD':
        return '上传';
      case 'ROLLBACK':
        return '回滚';
      case 'UPDATE':
        return '更新';
      case 'DELETE':
        return '删除';
      default:
        return operation;
    }
  }
}

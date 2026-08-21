/// 文件类型枚举，对齐后端 FileTypeEnum code
///
/// 0 文件夹 1 普通文件 2 压缩文件 3 excel 4 word 5 pdf 6 txt
/// 7 图片 8 音频 9 视频 10 ppt 11 源码 12 csv
enum FileType {
  folder(0),
  normal(1),
  archive(2),
  excel(3),
  word(4),
  pdf(5),
  txt(6),
  image(7),
  audio(8),
  video(9),
  ppt(10),
  code(11),
  csv(12);

  const FileType(this.value);

  final int value;

  static FileType fromCode(int code) {
    return FileType.values.firstWhere(
      (e) => e.value == code,
      orElse: () => FileType.normal,
    );
  }
}

/// 文件信息，对齐前端 IFileVO
class FileVO {
  const FileVO({
    required this.fileId,
    required this.parentId,
    required this.filename,
    required this.fileType,
    required this.folderFlag,
    required this.createTime,
    required this.updateTime,
    this.fileSize,
    this.fileCover,
    this.thumbnail,
    this.realPath,
    this.identifier,
    this.fileSizeDesc,
  });

  final String fileId;
  final String parentId;
  final String filename;
  final String? fileSize; // 后端字段类型为 string | number
  final FileType fileType;
  final String? fileCover;
  final String? thumbnail;
  final int folderFlag; // 0 | 1
  final String createTime;
  final String updateTime;
  final String? realPath;
  final String? identifier;
  final String? fileSizeDesc;

  bool get isFolder => fileType == FileType.folder || folderFlag == 1;

  factory FileVO.fromJson(Map<String, dynamic> json) {
    // 仅对数据库必有值的字段做强校验（fileId 主键、filename 文件名）：
    // 缺失时显式抛出解析异常，让接口契约问题在解析阶段暴露，避免后续
    // 因 fileId 为空导致分享/下载等操作出现更诡异的错误。
    // parentId 在回收站/搜索结果/跨目录等场景可能为空串（后端 IdEncryptSerializer
    // 对 null 输出 ""），因此 parentId 不参与强校验，允许为空。
    final fileId = json['fileId'] as String?;
    final parentId = json['parentId'] as String? ?? '';
    final filename = json['filename'] as String?;
    final fileType = json['fileType'] as int?;
    if (fileId == null || fileId.isEmpty) {
      throw FormatException('FileVO.fileId 缺失或为空');
    }
    if (filename == null || filename.isEmpty) {
      throw FormatException('FileVO.filename 缺失或为空');
    }
    final rawSize = json['fileSize'];
    return FileVO(
      fileId: fileId,
      parentId: parentId,
      filename: filename,
      fileSize: rawSize?.toString(),
      fileType: FileType.fromCode(fileType ?? 1),
      fileCover: json['fileCover'] as String?,
      thumbnail: json['thumbnail'] as String?,
      folderFlag: json['folderFlag'] as int? ?? 0,
      createTime: json['createTime'] as String? ?? '',
      updateTime: json['updateTime'] as String? ?? '',
      realPath: json['realPath'] as String?,
      identifier: json['identifier'] as String?,
      fileSizeDesc: json['fileSizeDesc'] as String?,
    );
  }
}

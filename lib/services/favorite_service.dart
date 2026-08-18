import '../core/network/http_client.dart';
import '../models/file_vo.dart';

/// 收藏文件，对齐前端 IFavoriteFileVO
class FavoriteFile {
  const FavoriteFile({
    required this.fileId,
    required this.parentId,
    required this.filename,
    required this.fileSizeDesc,
    required this.folderFlag,
    required this.fileType,
    required this.favoriteTime,
  });

  final String fileId;
  final String parentId;
  final String filename;
  final String fileSizeDesc;
  final int folderFlag;
  final FileType fileType;
  final String favoriteTime;

  factory FavoriteFile.fromJson(Map<String, dynamic> json) {
    return FavoriteFile(
      fileId: json['fileId'] as String? ?? '',
      parentId: json['parentId'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      fileSizeDesc: json['fileSizeDesc'] as String? ?? '',
      folderFlag: json['folderFlag'] as int? ?? 0,
      fileType: FileType.fromCode(json['fileType'] as int? ?? 1),
      favoriteTime: json['favoriteTime'] as String? ?? '',
    );
  }
}

/// 收藏（星标）API，对齐后端 FavoriteController
class FavoriteService {
  FavoriteService._();

  static final FavoriteService instance = FavoriteService._();

  final HttpClient _http = HttpClient.instance;

  /// 批量收藏
  Future<dynamic> add(List<String> fileIdList) {
    return _http.request<dynamic>(
      '/favorite/add',
      method: 'POST',
      data: {'fileIdList': fileIdList},
    );
  }

  /// 批量取消收藏
  Future<dynamic> remove(List<String> fileIdList) {
    return _http.request<dynamic>(
      '/favorite/remove',
      method: 'POST',
      data: {'fileIdList': fileIdList},
    );
  }

  /// 收藏列表
  Future<List<FavoriteFile>> list() {
    return _http.request<List<FavoriteFile>>(
      '/favorite/list',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FavoriteFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

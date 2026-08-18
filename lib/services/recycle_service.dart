import '../core/network/http_client.dart';
import '../models/file_vo.dart';

/// 回收站 API（对齐前端 recycleService）
class RecycleService {
  RecycleService._();

  static final RecycleService instance = RecycleService._();

  final HttpClient _http = HttpClient.instance;

  /// 回收站文件列表
  Future<List<FileVO>> recycles() {
    return _http.request<List<FileVO>>(
      '/recycles',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FileVO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 恢复（fileIds 以 __,__ 分隔）
  Future<dynamic> restore(String fileIds) {
    return _http.request<dynamic>(
      '/recycle/restore',
      method: 'PUT',
      data: {'fileIds': fileIds},
    );
  }

  /// 彻底删除（fileIds 以 __,__ 分隔）
  Future<dynamic> deleteForever(String fileIds) {
    return _http.request<dynamic>(
      '/recycle',
      method: 'DELETE',
      data: {'fileIds': fileIds},
    );
  }
}

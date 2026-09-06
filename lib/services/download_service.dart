import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';

/// 文件下载服务
///
/// 移动端无浏览器 Cookie，下载需在请求头携带 Authorization，
/// 与后端 /file/download 接口对齐。
class DownloadService {
  DownloadService._();

  static final DownloadService instance = DownloadService._();

  /// 下载文件到临时目录并打开
  ///
  /// [onProgress] 为本次下载的局部进度回调（0.0 ~ 1.0），
  /// 避免全局回调与上传等并发任务相互覆盖。
  Future<void> downloadAndOpen({
    required String fileId,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final savePath = await download(
      fileId: fileId,
      filename: filename,
      onProgress: onProgress,
    );
    // 下载完成后打开
    await OpenFilex.open(savePath);
  }

  /// 下载文件到临时目录，返回本地文件路径（不自动打开）
  ///
  /// [onProgress] 为本次下载的局部进度回调。
  Future<String> download({
    required String fileId,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final token = await TokenStorage.getToken();
    final dio = HttpClient.instance.dio;

    final dir = await getTemporaryDirectory();
    final safeName = _sanitizeFilename(filename);
    final savePath = '${dir.path}/$safeName';

    await dio.download(
      '/file/download',
      savePath,
      queryParameters: {'fileId': fileId},
      options: Options(
        headers: {'Authorization': token},
        responseType: ResponseType.stream,
      ),
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return savePath;
  }

  /// 文件名消毒：过滤路径分隔符与控制字符，防止目录逃逸；
  /// 消毒后为空则回退为时间戳文件名
  String _sanitizeFilename(String raw) {
    final cleaned = raw
        // 路径分隔符与文件系统非法字符 → 下划线
        .replaceAll(RegExp(r'[\\/]+'), '_')
        .replaceAll(RegExp(r'[:*?"<>|]'), '_')
        // 控制字符（含 \x00-\x1f 与 DEL）直接删除
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
    return cleaned;
  }
}

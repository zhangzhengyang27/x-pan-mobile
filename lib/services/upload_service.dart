import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/http_client.dart';
import '../core/storage/upload_task_storage.dart';
import '../utils/md5_hash.dart';
import 'user_service.dart';

/// 分片上传服务
///
/// 对齐前端 simple-uploader.js 的分片协议：
/// - 5MB 分片（identifier 为整个文件的 MD5）
/// - POST /file/chunk-upload 上传分片，返回 data.uploadedChunks 标识已上传分片
/// - 上传完成后 POST /file/merge 合并
class UploadService {
  UploadService._();

  static final UploadService instance = UploadService._();

  /// 上传进度回调（0.0 ~ 1.0）
  void Function(double progress)? onProgress;

  /// 取消检查回调（返回 true 表示已取消，中断上传）
  bool Function()? onCheckCancel;

  /// 取消异常
  static const cancelException = ApiException(-2, '已取消');

  /// 当前上传任务的取消令牌（串行队列同一时刻至多一个任务在上传）
  ///
  /// 取消时调用 [cancelActiveUpload]，在途的分片/合并请求会被立即中断。
  CancelToken? _activeCancelToken;

  /// 取消当前上传任务的在途请求（分片上传/合并）
  void cancelActiveUpload() {
    _activeCancelToken?.cancel();
    _activeCancelToken = null;
  }

  /// 上传单个文件（完整流程：计算 MD5 → 秒传检测 → 断点检测 → 分片上传 → 合并）
  ///
  /// [resumeIdentifier]：跨重启恢复时传入已计算的 identifier，跳过 MD5 计算。
  Future<void> uploadFile({
    required File file,
    required String parentId,
    String? resumeIdentifier,
  }) async {
    final filename = file.uri.pathSegments.last;
    final totalSize = await file.length();

    // 大小校验
    if (totalSize > AppConfig.maxFileSize) {
      throw ApiException(-1, '文件大小超过最大限制（3GB）');
    }

    // 计算文件 MD5 作为 identifier（恢复场景跳过）
    final identifier = resumeIdentifier ?? await _computeMd5(file);
    _checkCancel();
    onProgress?.call(0);

    // 每个任务独立的取消令牌：分片上传与合并请求都携带，
    // cancelActiveUpload() 可立即中断在途 HTTP 请求
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    final chunkSize = AppConfig.chunkSize;
    final totalChunks = (totalSize / chunkSize).ceil();

    // 持久化任务（支持跨重启断点续传）
    await UploadTaskStorage.save(
      UploadTaskRecord(
        filePath: file.path,
        filename: filename,
        parentId: parentId,
        identifier: identifier,
        totalSize: totalSize,
        totalChunks: totalChunks,
      ),
    );

    try {
      // 1. 秒传检测
      final secResult = await _trySecUpload(
        filename: filename,
        identifier: identifier,
        parentId: parentId,
      );
      if (secResult == true) {
        // 秒传成功，无需上传
        await UploadTaskStorage.remove(identifier);
        onProgress?.call(1);
        return;
      }

      // 2. 断点检测：GET 请求获取已上传分片号列表（1-based chunkNumber）
      final uploadedChunks = await _queryUploadedChunks(
        parentId: parentId,
        identifier: identifier,
        filename: filename,
        totalSize: totalSize,
        totalChunks: totalChunks,
        cancelToken: cancelToken,
      );

      // 全部已上传：直接合并（中断后重传的场景）
      if (uploadedChunks.length == totalChunks) {
        await _merge(
          identifier: identifier,
          filename: filename,
          parentId: parentId,
          totalSize: totalSize,
          cancelToken: cancelToken,
        );
        await UploadTaskStorage.remove(identifier);
        onProgress?.call(1);
        return;
      }

      var uploadedCount = uploadedChunks.length;
      for (var chunkNumber = 1; chunkNumber <= totalChunks; chunkNumber++) {
        _checkCancel();

        // 跳过已上传的分片
        if (uploadedChunks.contains(chunkNumber)) {
          continue;
        }

        final start = (chunkNumber - 1) * chunkSize;
        final end = (chunkNumber * chunkSize) > totalSize
            ? totalSize
            : chunkNumber * chunkSize;
        final currentChunkSize = end - start;

        final bytes = await _readChunk(file, start, end);
        await _uploadChunk(
          parentId: parentId,
          identifier: identifier,
          filename: filename,
          totalSize: totalSize,
          chunkNumber: chunkNumber,
          totalChunks: totalChunks,
          currentChunkSize: currentChunkSize,
          bytes: bytes,
          cancelToken: cancelToken,
        );

        uploadedCount++;
        onProgress?.call(uploadedCount / totalChunks);
      }

      // 3. 合并
      await _merge(
        identifier: identifier,
        filename: filename,
        parentId: parentId,
        totalSize: totalSize,
        cancelToken: cancelToken,
      );
      await UploadTaskStorage.remove(identifier);
      onProgress?.call(1);
    } finally {
      // 上传失败：保留任务记录，等待下次恢复（异常向上抛出由队列标记失败）
      if (identical(_activeCancelToken, cancelToken)) {
        _activeCancelToken = null;
      }
    }
  }

  /// 获取未完成的上传任务（App 启动时调用）
  Future<List<UploadTaskRecord>> pendingTasks() {
    return UploadTaskStorage.getAll();
  }

  /// 恢复上传任务（跨重启断点续传）
  Future<void> resume(UploadTaskRecord record) async {
    final file = File(record.filePath);
    if (!await file.exists()) {
      // 文件已被删除，清理任务
      await UploadTaskStorage.remove(record.identifier);
      throw ApiException(-1, '源文件已不存在，无法恢复上传');
    }
    await uploadFile(
      file: file,
      parentId: record.parentId,
      resumeIdentifier: record.identifier,
    );
  }

  /// 秒传检测；命中返回 true（无需上传）
  ///
  /// 后端语义（FileController#secUpload）：命中返回 R.success()（code=0）；
  /// 未命中返回 R.fail("文件唯一标识不存在，请手动执行文件上传")，
  /// 对应业务 code = ResponseCode.ERROR = 1。
  /// 仅 code=1 视为「未命中」回退分片上传；code=10（登录失效，
  /// NeedReloginException）与 5xx 等一律上抛，不再吞异常。
  Future<bool> _trySecUpload({
    required String filename,
    required String identifier,
    required String parentId,
  }) async {
    try {
      await FileService.instance.secUpload(
        filename: filename,
        identifier: identifier,
        parentId: parentId,
      );
      return true;
    } on ApiException catch (e) {
      if (e.code == 1) return false;
      rethrow;
    }
  }

  /// 断点检测：GET 请求获取已上传分片号列表
  ///
  /// 对齐 simple-uploader 的 testChunks 机制：GET /file/chunk-upload
  /// 携带 identifier 等参数，后端返回 data.uploadedChunks（1-based chunkNumber 数组）。
  ///
  /// 容错白名单同样收窄：仅业务错误（code=1）回退为全量上传；
  /// code=10（NeedReloginException）与 5xx 等一律上抛，
  /// 避免登录失效/服务器故障被静默吞掉导致断点续传长期失效。
  Future<Set<int>> _queryUploadedChunks({
    required String parentId,
    required String identifier,
    required String filename,
    required int totalSize,
    required int totalChunks,
    required CancelToken cancelToken,
  }) async {
    try {
      return await _requestWithCancel<Set<int>>(
        '/file/chunk-upload',
        query: {
          'parentId': parentId,
          'identifier': identifier,
          'filename': filename,
          'totalSize': totalSize,
          'totalChunks': totalChunks,
        },
        cancelToken: cancelToken,
        dataDecoder: (json) {
          if (json is Map) {
            final map = json.cast<String, dynamic>();
            final list = (map['uploadedChunks'] as List<dynamic>?) ?? const [];
            return list.map((e) => (e as num).toInt()).toSet();
          }
          return <int>{};
        },
      );
    } on ApiException catch (e) {
      if (e.code == 1) {
        debugPrint('[upload_service] 断点检测业务失败(code=1)，回退为全量上传');
        return <int>{};
      }
      rethrow;
    }
  }

  /// 合并分片（与 FileService.merge 同接口，额外携带取消令牌）
  Future<void> _merge({
    required String identifier,
    required String filename,
    required String parentId,
    required int totalSize,
    required CancelToken cancelToken,
  }) {
    return _requestWithCancel<dynamic>(
      '/file/merge',
      method: 'POST',
      data: {
        'identifier': identifier,
        'filename': filename,
        'parentId': parentId,
        'totalSize': totalSize,
      },
      cancelToken: cancelToken,
    );
  }

  /// 携带 CancelToken 的业务请求（与 HttpClient.request 相同的统一响应解析）
  ///
  /// HttpClient.request 暂未透传 cancelToken（公共网络层由其他并行任务维护，
  /// 此处不改动），上传链路需要任务级取消能力，故基于同一共享 Dio 实例发起：
  /// 拦截器（token 注入/续期/trace-id）依然生效，仅本地补充统一响应解析。
  Future<T> _requestWithCancel<T>(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Object? data,
    T Function(dynamic json)? dataDecoder,
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await HttpClient.instance.dio.request<dynamic>(
        path,
        queryParameters: query,
        data: data,
        options: Options(method: method),
        cancelToken: cancelToken,
      );

      final body = response.data;
      final Map<String, dynamic> map;
      if (body is Map<String, dynamic>) {
        map = body;
      } else if (body is Map) {
        map = body.cast<String, dynamic>();
      } else {
        throw ApiException(-1, '响应格式错误');
      }

      final code = map['code'] as int? ?? -1;
      final message = map['message'] as String? ?? '';
      if (code == 10) throw const NeedReloginException();
      if (code != 0) throw ApiException(code, message);

      final rawData = map['data'];
      if (dataDecoder != null) return dataDecoder(rawData);
      return rawData as T;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || cancelToken.isCancelled) {
        throw cancelException;
      }
      throw ApiException(
        e.response?.statusCode ?? -1,
        '请求失败（${e.response?.statusCode ?? '网络异常'}）',
      );
    }
  }

  /// 上传单个分片
  Future<void> _uploadChunk({
    required String parentId,
    required String identifier,
    required String filename,
    required int totalSize,
    required int chunkNumber,
    required int totalChunks,
    required int currentChunkSize,
    required Uint8List bytes,
    required CancelToken cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    await _requestWithCancel<dynamic>(
      '/file/chunk-upload',
      method: 'POST',
      query: {
        'parentId': parentId,
        'identifier': identifier,
        'filename': filename,
        'totalSize': totalSize,
        'chunkNumber': chunkNumber,
        'totalChunks': totalChunks,
        'currentChunkSize': currentChunkSize,
      },
      data: formData,
      cancelToken: cancelToken,
    );
  }

  /// 读取文件分片
  Future<Uint8List> _readChunk(File file, int start, int end) async {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      final length = end - start;
      final bytes = await raf.read(length);
      return bytes;
    } finally {
      await raf.close();
    }
  }

  /// 计算文件 MD5（后台 isolate 执行，不阻塞 UI）
  ///
  /// 保持现状说明：MD5 已通过 computeFileMd5 在 isolate 中计算，
  /// 不阻塞 UI 线程；isolate 内部不可取消（中断成本高于收益），
  /// 取消检查在 MD5 完成后的 _checkCancel() 处生效。
  Future<String> _computeMd5(File file) {
    return computeFileMd5(file.path);
  }

  /// 检查是否已取消
  void _checkCancel() {
    if (onCheckCancel?.call() == true) {
      throw cancelException;
    }
  }
}

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
      );

      // 全部已上传：直接合并（中断后重传的场景）
      if (uploadedChunks.length == totalChunks) {
        await FileService.instance.merge(
          identifier: identifier,
          filename: filename,
          parentId: parentId,
          totalSize: totalSize,
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
        );

        uploadedCount++;
        onProgress?.call(uploadedCount / totalChunks);
      }

      // 3. 合并
      await FileService.instance.merge(
        identifier: identifier,
        filename: filename,
        parentId: parentId,
        totalSize: totalSize,
      );
      await UploadTaskStorage.remove(identifier);
      onProgress?.call(1);
    } catch (e) {
      // 上传失败：保留任务记录，等待下次恢复
      rethrow;
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
      // 未命中秒传（后端返回特定 code），继续走分片上传
      if (e.code == 0) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 断点检测：GET 请求获取已上传分片号列表
  ///
  /// 对齐 simple-uploader 的 testChunks 机制：GET /file/chunk-upload
  /// 携带 identifier 等参数，后端返回 data.uploadedChunks（1-based chunkNumber 数组）。
  ///
  /// 通过 HttpClient.request 发起，自动处理 token 注入与续期。
  Future<Set<int>> _queryUploadedChunks({
    required String parentId,
    required String identifier,
    required String filename,
    required int totalSize,
    required int totalChunks,
  }) async {
    try {
      final uploadedChunks = await HttpClient.instance.request<Set<int>>(
        '/file/chunk-upload',
        query: {
          'parentId': parentId,
          'identifier': identifier,
          'filename': filename,
          'totalSize': totalSize,
          'totalChunks': totalChunks,
        },
        dataDecoder: (json) {
          if (json is Map) {
            final map = json.cast<String, dynamic>();
            final list = (map['uploadedChunks'] as List<dynamic>?) ?? const [];
            return list.map((e) => (e as num).toInt()).toSet();
          }
          return <int>{};
        },
      );
      return uploadedChunks;
    } catch (e) {
      // 断点检测失败：回退为全量上传（保证上传可继续）是合理容错，
      // 但必须记录日志，避免断点续传长期静默失效导致大量流量重复上传却不自知。
      // 注意：对大文件而言断点失效意味着已传分片全部重新上传，成本较高，值得被观测到。
      debugPrint('[upload_service] 断点检测失败，回退为全量上传: $e');
      return <int>{};
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
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    // 通过 HttpClient.request 发起，自动处理 token 注入与续期
    await HttpClient.instance.request<dynamic>(
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

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/network/http_client.dart';

/// 挂载点视图，对齐后端 MountVO（secretKey 永不回传）
class MountVO {
  const MountVO({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.bucket,
    required this.accessKey,
    required this.enabled,
    this.basePrefix = '',
    this.createTime = '',
  });

  final int id;
  final String name;
  final String endpoint;
  final String bucket;
  final String accessKey;
  final String basePrefix;
  final bool enabled;
  final String createTime;

  factory MountVO.fromJson(Map<String, dynamic> json) {
    return MountVO(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      bucket: json['bucket'] as String? ?? '',
      accessKey: json['accessKey'] as String? ?? '',
      basePrefix: json['basePrefix'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      createTime: json['createTime'] as String? ?? '',
    );
  }
}

/// 外部 S3 兼容对象条目
class MountEntry {
  const MountEntry({required this.key, required this.display, required this.size, required this.dir});

  final String key;
  final String display;
  final int size;
  final bool dir;

  factory MountEntry.fromJson(Map<String, dynamic> json) {
    return MountEntry(
      key: json['key'] as String? ?? '',
      display: json['display'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      dir: json['dir'] as bool? ?? false,
    );
  }
}

/// 挂载保存参数；编辑时 secretKey 留空 = 不修改
class MountSave {
  const MountSave({
    this.id,
    required this.name,
    required this.endpoint,
    required this.bucket,
    required this.accessKey,
    this.secretKey,
    this.basePrefix = '',
    this.enabled = true,
  });

  final int? id;
  final String name;
  final String endpoint;
  final String bucket;
  final String accessKey;
  final String? secretKey;
  final String basePrefix;
  final bool enabled;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'endpoint': endpoint,
        'bucket': bucket,
        'accessKey': accessKey,
        if (secretKey != null && secretKey!.isNotEmpty) 'secretKey': secretKey,
        'basePrefix': basePrefix,
        'enabled': enabled,
      };
}

/// 外部存储挂载 API，对齐后端 MountController
class MountService {
  MountService._();

  static final MountService instance = MountService._();
  final _http = HttpClient.instance;

  Future<List<MountVO>> list() {
    return _http.request<List<MountVO>>(
      '/mount/manage/list',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => MountVO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<int> create(MountSave po) async {
    final id = await _http.request<dynamic>('/mount/manage/create', method: 'POST', data: po.toJson());
    return (id as num).toInt();
  }

  Future<void> update(MountSave po) async {
    await _http.request<dynamic>('/mount/manage/update', method: 'PUT', data: po.toJson());
  }

  Future<void> delete(int id) async {
    await _http.request<dynamic>('/mount/manage/$id', method: 'DELETE');
  }

  Future<String> testSaved(int id) {
    return _http.request<String>('/mount/manage/$id/test', method: 'POST');
  }

  Future<String> testRaw(MountSave po) {
    return _http.request<String>('/mount/manage/test', method: 'POST', data: po.toJson());
  }

  Future<List<MountEntry>> browse(int id, String path) {
    return _http.request<List<MountEntry>>(
      '/mount/$id/list',
      query: {'path': path, 'maxKeys': 200},
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => MountEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> upload(int id, String path, String filePath, String filename) async {
    // 浏览路径带尾部 "/"，后端 upload 会再补一个 "/"；先去掉，避免落到 dir//name。
    final cleanPath = path.replaceAll(RegExp(r'/+$'), '');
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
      if (cleanPath.isNotEmpty) 'path': cleanPath,
    });
    await _http.request<dynamic>(
      '/mount/$id/upload',
      method: 'POST',
      data: form,
      extraHeaders: {'Content-Type': 'multipart/form-data'},
    );
  }

  Future<void> makeDir(int id, String path) async {
    await _http.request<dynamic>(
      '/mount/$id/dir',
      method: 'PUT',
      query: {'path': path},
    );
  }

  Future<List<String>> deleteObject(int id, String path, bool isDir) async {
    final failed = await _http.request<dynamic>(
      '/mount/$id',
      method: 'DELETE',
      query: {'path': path, 'dir': isDir},
    );
    return (failed as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
  }

  /// 流式下载到临时目录；文件名取自对象 key 的末段，避免路径穿越
  Future<File> download(int id, MountEntry entry) async {
    final dir = await getTemporaryDirectory();
    final safeName = entry.key.split('/').last.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final target = File('${dir.path}/mount_${id}_$safeName');
    await _http.dio.download(
      '/mount/$id/download',
      target.path,
      queryParameters: {'path': entry.key},
    );
    return target;
  }
}

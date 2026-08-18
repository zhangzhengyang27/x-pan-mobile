import '../core/config/app_config.dart';
import '../core/network/http_client.dart';
import '../models/api_response.dart';
import '../models/file_version.dart';
import '../models/file_vo.dart';
import '../models/folder_node.dart';
import '../models/user_info.dart';

/// 面包屑项，对齐前端 BreadcrumbItem
class BreadcrumbItem {
  const BreadcrumbItem({required this.id, required this.name});

  final String id;
  final String name;

  factory BreadcrumbItem.fromJson(Map<String, dynamic> json) {
    return BreadcrumbItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

/// 用户相关 API，对齐前端 userService
class UserService {
  /// 公开构造（含测试子类化），单例用 [instance]
  UserService();

  static final UserService instance = UserService();

  final HttpClient _http = HttpClient.instance;

  /// 登录
  Future<UserInfo> login({
    required String username,
    required String password,
  }) {
    return _http.request<UserInfo>(
      '/user/login',
      method: 'POST',
      data: {'username': username, 'password': password},
      dataDecoder: (json) => UserInfo.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 注册
  Future<dynamic> register({
    required String username,
    required String password,
    String? email,
    String? answer,
  }) {
    return _http.request<dynamic>(
      '/user/register',
      method: 'POST',
      data: {
        'username': username,
        'password': password,
        if (email != null) 'email': email,
        if (answer != null) 'answer': answer,
      },
    );
  }

  /// 获取当前用户信息
  Future<UserInfo> info() {
    return _http.request<UserInfo>(
      '/user/',
      dataDecoder: (json) => UserInfo.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 检查用户名是否可用
  Future<dynamic> checkUsername(String username) {
    return _http.request<dynamic>(
      '/user/username/check',
      method: 'POST',
      data: {'username': username},
    );
  }

  /// 退出登录
  Future<dynamic> exit() {
    return _http.request<dynamic>('/user/exit', method: 'POST');
  }

  /// 校验密保答案（忘记密码第一步）
  Future<dynamic> checkAnswer({
    required String username,
    required String answer,
  }) {
    return _http.request<dynamic>(
      '/user/answer/check',
      method: 'POST',
      data: {'username': username, 'answer': answer},
    );
  }

  /// 重置密码（忘记密码第二步）
  Future<dynamic> resetPassword({
    required String username,
    required String answer,
    required String newPassword,
  }) {
    return _http.request<dynamic>(
      '/user/password/reset',
      method: 'POST',
      data: {
        'username': username,
        'answer': answer,
        'newPassword': newPassword,
      },
    );
  }

  /// 修改密码（登录态）
  Future<dynamic> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _http.request<dynamic>(
      '/user/password/change',
      method: 'POST',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }
}

/// 文件相关 API，对齐前端 fileService（首期覆盖核心能力）
class FileService {
  FileService._();

  static final FileService instance = FileService._();

  final HttpClient _http = HttpClient.instance;

  /// 文件列表
  Future<PageVO<FileVO>> list({
    required String parentId,
    String? fileTypes,
    int pageNum = 1,
    int pageSize = 50,
    String? keyword,
    String? orderBy,
    String? order,
  }) {
    return _http.request<PageVO<FileVO>>(
      '/files',
      query: {
        'parentId': parentId,
        if (fileTypes != null) 'fileTypes': fileTypes,
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (orderBy != null) 'orderBy': orderBy,
        if (order != null) 'order': order,
      },
      dataDecoder: (json) => PageVO.fromJson(
        json as Map<String, dynamic>,
        (e) => FileVO.fromJson(e as Map<String, dynamic>),
      ),
    );
  }

  /// 新建文件夹
  Future<dynamic> createFolder({
    required String parentId,
    required String filename,
  }) {
    return _http.request<dynamic>(
      '/file/folder',
      method: 'POST',
      data: {'parentId': parentId, 'filename': filename},
    );
  }

  /// 重命名 / 移动
  Future<dynamic> update({
    required String fileId,
    String? filename,
    String? parentId,
  }) {
    return _http.request<dynamic>(
      '/file',
      method: 'PUT',
      data: {
        'fileId': fileId,
        if (filename != null) 'filename': filename,
        if (parentId != null) 'parentId': parentId,
      },
    );
  }

  /// 删除（fileIds 以 __,__ 分隔）
  Future<dynamic> delete(String fileIds) {
    return _http.request<dynamic>(
      '/file',
      method: 'DELETE',
      data: {'fileIds': fileIds},
    );
  }

  /// 移动
  Future<dynamic> transfer({
    required String fileIds,
    required String targetParentId,
  }) {
    return _http.request<dynamic>(
      '/file/transfer',
      method: 'POST',
      data: {'fileIds': fileIds, 'targetParentId': targetParentId},
    );
  }

  /// 复制
  Future<dynamic> copy({
    required String fileIds,
    required String targetParentId,
  }) {
    return _http.request<dynamic>(
      '/file/copy',
      method: 'POST',
      data: {'fileIds': fileIds, 'targetParentId': targetParentId},
    );
  }

  /// 获取文件夹树（用于移动/复制目标选择）
  Future<List<FolderNode>> getFolderTree() {
    return _http.request<List<FolderNode>>(
      '/file/folder/tree',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FolderNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 搜索
  Future<List<FileVO>> search({
    required String keyword,
    String? fileTypes,
    String? extensions,
    String? dateFrom,
    String? dateTo,
    num? sizeMin,
    num? sizeMax,
  }) {
    return _http.request<List<FileVO>>(
      '/file/search',
      query: {
        'keyword': keyword,
        if (fileTypes != null) 'fileTypes': fileTypes,
        if (extensions != null) 'extensions': extensions,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (sizeMin != null) 'sizeMin': sizeMin,
        if (sizeMax != null) 'sizeMax': sizeMax,
      },
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FileVO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 面包屑
  Future<List<BreadcrumbItem>> getBreadcrumbs(String fileId) {
    return _http.request<List<BreadcrumbItem>>(
      '/file/breadcrumbs',
      query: {'fileId': fileId},
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => BreadcrumbItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 秒传检测
  Future<dynamic> secUpload({
    required String filename,
    required String identifier,
    required String parentId,
  }) {
    return _http.request<dynamic>(
      '/file/sec-upload',
      method: 'POST',
      data: {
        'filename': filename,
        'identifier': identifier,
        'parentId': parentId,
      },
    );
  }

  /// 合并分片
  Future<dynamic> merge({
    required String identifier,
    required String filename,
    required String parentId,
    required int totalSize,
  }) {
    return _http.request<dynamic>(
      '/file/merge',
      method: 'POST',
      data: {
        'identifier': identifier,
        'filename': filename,
        'parentId': parentId,
        'totalSize': totalSize,
      },
    );
  }

  /// 解析预览直链（对齐前端 resolvePreviewUrl）
  ///
  /// POST /file/preview/url?fileId=xxx 返回相对路径（带 ptoken），
  /// 这里拼接为完整 URL。移动端无 Cookie，需在请求头携带 Authorization。
  Future<String> resolvePreviewUrl(
    String fileId, {
    int? width,
    int? height,
  }) async {
    final query = <String, dynamic>{
      'fileId': fileId,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };
    final path = await _http.request<String>(
      '/file/preview/url',
      method: 'POST',
      query: query,
      dataDecoder: (json) => json as String,
    );
    // 后端返回相对路径，拼接为完整地址
    if (path.startsWith('http')) return path;
    return '${AppConfig.apiBaseUrl}$path';
  }

  /// 提取文件纯文本（对齐前端 textExtract 接口）
  ///
  /// 后端已完成编码识别（UTF-8/GBK 等），适合文本/代码/Markdown 预览。
  Future<TextExtractResult> textExtract(String fileId) {
    return _http.request<TextExtractResult>(
      '/file/$fileId/text-extract',
      dataDecoder: (json) =>
          TextExtractResult.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 文件版本历史列表
  Future<List<FileVersion>> listVersions(String fileId) {
    return _http.request<List<FileVersion>>(
      '/file/versions',
      query: {'fileId': fileId},
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FileVersion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 获取单个版本详情
  Future<FileVersion> getVersion(String id) {
    return _http.request<FileVersion>(
      '/file/version',
      query: {'id': id},
      dataDecoder: (json) => FileVersion.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 回滚到指定版本
  Future<dynamic> rollback({
    required String id,
    required String fileId,
  }) {
    return _http.request<dynamic>(
      '/file/rollback',
      method: 'POST',
      query: {'id': id, 'fileId': fileId},
    );
  }

  /// 删除指定版本
  Future<dynamic> deleteVersion({
    required String id,
    required String fileId,
  }) {
    return _http.request<dynamic>(
      '/file/version',
      method: 'DELETE',
      query: {'id': id, 'fileId': fileId},
    );
  }
}

/// 文本提取结果，对齐前端 TextExtractVO
class TextExtractResult {
  const TextExtractResult({
    required this.text,
    required this.truncated,
    this.extractedBy = '',
    this.totalChars = 0,
  });

  final String text;
  final bool truncated;
  final String extractedBy;
  final int totalChars;

  factory TextExtractResult.fromJson(Map<String, dynamic> json) {
    return TextExtractResult(
      text: json['text'] as String? ?? '',
      truncated: json['truncated'] as bool? ?? false,
      extractedBy: json['extractedBy'] as String? ?? '',
      totalChars: json['totalChars'] as int? ?? 0,
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../core/network/http_client.dart';
import '../models/api_response.dart';
import '../models/file_vo.dart';

/// 将任意 Map 安全转为 `Map<String, dynamic>`
Map<String, dynamic> _castMap(dynamic json) {
  if (json is Map<String, dynamic>) return json;
  if (json is Map) return json.cast<String, dynamic>();
  return <String, dynamic>{};
}

/// 分享链接列表项，对齐后端 XPanShareUrlListVO
class ShareVO {
  const ShareVO({
    required this.shareId,
    required this.shareName,
    required this.shareUrl,
    required this.shareStatus,
    required this.shareType,
    required this.shareDayType,
    required this.createTime,
    this.shareCode = '',
    this.shareEndTime,
    this.reportHidden = false,
    this.reportHiddenTime,
    this.downloadCount = 0,
    this.downloadLimit = 0,
    this.visitCount = 0,
    this.saveCount = 0,
    this.forbidReshare = false,
    this.collectEnabled = false,
    this.e2ee = false,
  });

  final String shareId;
  final String shareName;
  final String shareUrl;
  final String shareCode;
  final int shareStatus;
  final int shareType;
  final int shareDayType;
  final String? shareEndTime;
  final String createTime;
  final bool reportHidden;
  final String? reportHiddenTime;
  final int downloadCount;
  final int downloadLimit;
  final int visitCount;
  final int saveCount;
  final bool forbidReshare;
  final bool collectEnabled;
  final bool e2ee;

  factory ShareVO.fromJson(Map<String, dynamic> json) {
    return ShareVO(
      shareId: json['shareId'] as String? ?? '',
      shareName: json['shareName'] as String? ?? '',
      shareUrl: json['shareUrl'] as String? ?? '',
      shareCode: json['shareCode'] as String? ?? '',
      shareStatus: json['shareStatus'] as int? ?? 0,
      shareType: json['shareType'] as int? ?? 0,
      shareDayType: json['shareDayType'] as int? ?? 0,
      shareEndTime: json['shareEndTime'] as String?,
      createTime: json['createTime'] as String? ?? '',
      reportHidden: (json['reportHidden'] as num?)?.toInt() == 1,
      reportHiddenTime: json['reportHiddenTime'] as String?,
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      downloadLimit: (json['downloadLimit'] as num?)?.toInt() ?? 0,
      visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      forbidReshare: (json['forbidReshare'] as num?)?.toInt() == 1,
      collectEnabled: (json['collectEnabled'] as num?)?.toInt() == 1,
      e2ee: (json['e2ee'] as num?)?.toInt() == 1,
    );
  }
}

/// 分享者信息，对齐后端 ShareUserInfoVO
class ShareUserInfo {
  const ShareUserInfo({required this.userId, required this.username});

  final String userId;
  final String username;

  factory ShareUserInfo.fromJson(Map<String, dynamic> json) {
    return ShareUserInfo(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
    );
  }
}

/// 分享申诉状态，对齐后端 ShareAppealVO
class ShareAppeal {
  const ShareAppeal({
    required this.appealId,
    required this.shareId,
    required this.status,
    this.reason = '',
    this.adminNote = '',
    this.createTime,
    this.updateTime,
  });

  final String appealId;
  final String shareId;
  final int status;
  final String reason;
  final String adminNote;
  final String? createTime;
  final String? updateTime;

  bool get pending => status == 0;
  bool get approved => status == 1;
  bool get rejected => status == 2;

  factory ShareAppeal.fromJson(Map<String, dynamic> json) {
    return ShareAppeal(
      appealId: json['appealId'] as String? ?? '',
      shareId: json['shareId'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
      adminNote: json['adminNote'] as String? ?? '',
      createTime: json['createTime'] as String?,
      updateTime: json['updateTime'] as String?,
    );
  }
}

/// 分享简单详情，对齐后端 ShareSimpleDetailVO
class ShareSimpleDetail {
  const ShareSimpleDetail({
    required this.shareId,
    required this.shareName,
    required this.shareUserInfo,
    this.hasShareCode = false,
    this.downloadLimit = 0,
    this.downloadCount = 0,
    this.visitCount = 0,
    this.saveCount = 0,
    this.forbidReshare = false,
    this.collectEnabled = false,
    this.e2ee = false,
  });

  final String shareId;
  final String shareName;
  final ShareUserInfo shareUserInfo;
  final bool hasShareCode;
  final int downloadLimit;
  final int downloadCount;
  final int visitCount;
  final int saveCount;
  final bool forbidReshare;
  final bool collectEnabled;
  final bool e2ee;

  factory ShareSimpleDetail.fromJson(Map<String, dynamic> json) {
    return ShareSimpleDetail(
      shareId: json['shareId'] as String? ?? '',
      shareName: json['shareName'] as String? ?? '',
      shareUserInfo: ShareUserInfo.fromJson(
        _castMap(json['shareUserInfoVO']),
      ),
      hasShareCode: json['hasShareCode'] as bool? ?? false,
      downloadLimit: (json['downloadLimit'] as num?)?.toInt() ?? 0,
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      forbidReshare: (json['forbidReshare'] as num?)?.toInt() == 1,
      collectEnabled: (json['collectEnabled'] as num?)?.toInt() == 1,
      e2ee: (json['e2ee'] as num?)?.toInt() == 1,
    );
  }
}

/// 分享详情，对齐后端 ShareDetailVO
class ShareDetail {
  const ShareDetail({
    required this.shareId,
    required this.shareName,
    required this.createTime,
    required this.shareDay,
    required this.files,
    required this.shareUserInfo,
    this.shareEndTime,
    this.downloadCount = 0,
    this.downloadLimit = 0,
    this.visitCount = 0,
    this.saveCount = 0,
    this.forbidReshare = false,
    this.collectEnabled = false,
    this.e2ee = false,
  });

  final String shareId;
  final String shareName;
  final String createTime;
  final int shareDay;
  final String? shareEndTime;
  final List<FileVO> files;
  final ShareUserInfo shareUserInfo;
  final int downloadCount;
  final int downloadLimit;
  final int visitCount;
  final int saveCount;
  final bool forbidReshare;
  final bool collectEnabled;
  final bool e2ee;

  factory ShareDetail.fromJson(Map<String, dynamic> json) {
    // 后端 Jackson 实际序列化名为 xpanUserFileVOList；兼容前端历史类型的 xPan...
    final rawFiles = (json['xpanUserFileVOList'] ?? json['xPanUserFileVOList'])
            as List<dynamic>? ??
        const [];
    return ShareDetail(
      shareId: json['shareId'] as String? ?? '',
      shareName: json['shareName'] as String? ?? '',
      createTime: json['createTime'] as String? ?? '',
      shareDay: json['shareDay'] as int? ?? 0,
      shareEndTime: json['shareEndTime'] as String?,
      files: rawFiles
          .map((e) => FileVO.fromJson(e as Map<String, dynamic>))
          .toList(),
      shareUserInfo: ShareUserInfo.fromJson(
        _castMap(json['shareUserInfoVO']),
      ),
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      downloadLimit: (json['downloadLimit'] as num?)?.toInt() ?? 0,
      visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      forbidReshare: (json['forbidReshare'] as num?)?.toInt() == 1,
      collectEnabled: (json['collectEnabled'] as num?)?.toInt() == 1,
      e2ee: (json['e2ee'] as num?)?.toInt() == 1,
    );
  }
}

/// 分享 API（对齐后端 ShareController）
class ShareService {
  ShareService._();

  static final ShareService instance = ShareService._();

  final HttpClient _http = HttpClient.instance;

  /// 创建分享
  ///
  /// 后端 CreateShareUrlPO 字段：shareName / shareType / shareDayType / shareFileIds。
  /// 当前后端只定义 shareType=0（有提取码）这一种类型，调用方不要再传 1；
  /// 不传 shareCode 时后端会自动生成 6 位随机码，创建响应返回明文供本次展示。
  Future<ShareVO> create({
    required String shareName,
    required List<String> fileIds,
    int shareType = 0,
    int shareDayType = 0,
    String? shareCode,
    int? downloadLimit,
    bool forbidReshare = false,
    bool collectEnabled = false,
    bool e2ee = false,
  }) {
    return _http.request<ShareVO>(
      '/share',
      method: 'POST',
      data: {
        'shareName': shareName,
        'shareType': shareType,
        'shareDayType': shareDayType,
        'shareFileIds': fileIds,
        if (shareCode != null && shareCode.isNotEmpty) 'shareCode': shareCode,
        if (downloadLimit != null) 'downloadLimit': downloadLimit,
        if (forbidReshare) 'forbidReshare': true,
        if (collectEnabled) 'collectEnabled': true,
        if (e2ee) 'e2ee': true,
      },
      dataDecoder: (json) => ShareVO.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 批量取消分享（shareIds 为加密分享ID数组）
  Future<dynamic> cancel(List<String> shareIds) {
    return _http.request<dynamic>(
      '/share',
      method: 'DELETE',
      data: {'shareIds': shareIds},
    );
  }

  /// 我的分享列表（返回数组）
  Future<List<ShareVO>> list() {
    return _http.request<List<ShareVO>>(
      '/shares',
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => ShareVO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 分享简单详情（无需登录、无需提取码）
  Future<ShareSimpleDetail> simpleDetail(String shareId) {
    return _http.request<ShareSimpleDetail>(
      '/share/simple',
      query: {'shareId': shareId},
      dataDecoder: (json) =>
          ShareSimpleDetail.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 校验提取码，返回 shareToken（无需登录）
  Future<String> checkShareCode({
    required String shareId,
    required String shareCode,
  }) {
    return _http.request<String>(
      '/share/code/check',
      method: 'POST',
      data: {'shareId': shareId, 'shareCode': shareCode},
      dataDecoder: (json) => json as String,
    );
  }

  /// 分享详情（需 Share-Token 头）
  Future<ShareDetail> detail(String shareToken) {
    return _http.request<ShareDetail>(
      '/share',
      extraHeaders: {'Share-Token': shareToken},
      dataDecoder: (json) => ShareDetail.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 分享文件列表（需 Share-Token 头；按目录一层分页）
  Future<PageVO<FileVO>> fileList({
    required String parentId,
    required String shareToken,
    int pageNum = 1,
    int pageSize = 100,
  }) {
    return _http.request<PageVO<FileVO>>(
      '/share/file/list',
      query: {
        'parentId': parentId,
        'pageNum': pageNum,
        'pageSize': pageSize,
      },
      extraHeaders: {'Share-Token': shareToken},
      dataDecoder: (json) => PageVO.fromJson(
        json as Map<String, dynamic>,
        (e) => FileVO.fromJson(e as Map<String, dynamic>),
      ),
    );
  }

  /// 上传 E2EE 密文副本，返回密文 fileId（服务端固定落到隐藏目录 -3）
  ///
  /// identifier 对密文没有秒传价值，使用随机 hex 阻止按大小/摘要去重探测。
  Future<String> uploadCipher({
    required File file,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final random = Random.secure();
    final identifier = List<String>.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: filename),
      'filename': filename,
      'identifier': identifier,
      'totalSize': await file.length(),
    });
    final response = await _http.dio.post<dynamic>(
      '/file/upload-cipher',
      data: form,
      // 20GB 大文件上传不设总超时；连接/接收超时由 BaseOptions 控制
      options: Options(
        contentType: 'multipart/form-data',
        // 20GB 密文上传耗时不可预估；Dio 的 0 表示不设超时
        sendTimeout: Duration.zero,
        receiveTimeout: Duration.zero,
      ),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    return _unwrap(response.data, (json) => json as String);
  }

  /// 下载分享密文到本地（需 Share-Token 头）
  Future<void> downloadCipher({
    required String fileId,
    required String shareToken,
    required String savePath,
    void Function(double progress)? onProgress,
  }) async {
    await _http.dio.download(
      '/share/file/download',
      savePath,
      queryParameters: {'fileId': fileId},
      options: Options(
        headers: {'Share-Token': shareToken},
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
    // 后端业务失败会返回 HTTP 200 + JSON，避免把错误体当密文继续解密
    final saved = File(savePath);
    if (await saved.length() <= 64 * 1024) {
      final head = utf8.decode(await saved.readAsBytes(), allowMalformed: true);
      final error = _tryParseBusinessError(head);
      if (error != null) {
        await saved.delete();
        final code = error['code'] as int;
        final message = error['message'] as String? ?? '下载失败';
        if (code == 10) {
          HttpClient.notifyNeedRelogin();
          throw const NeedReloginException();
        }
        throw ApiException(code, message);
      }
    }
  }

  /// 创建分享失败时清理已上传的密文，避免隐藏目录长期占配额
  Future<void> deleteCipher(String fileId) {
    return _http.request<dynamic>(
      '/file/cipher',
      method: 'DELETE',
      query: {'fileId': fileId},
    );
  }

  T _unwrap<T>(dynamic body, T Function(dynamic json) decoder) {
    final map = body is Map ? body.cast<String, dynamic>() : null;
    if (map == null) throw const ApiException(-1, '响应格式错误');
    final code = map['code'] as int? ?? -1;
    final message = map['message'] as String? ?? '';
    if (code == 10) {
      HttpClient.notifyNeedRelogin();
      throw const NeedReloginException();
    }
    if (code != 0) throw ApiException(code, message);
    return decoder(map['data']);
  }

  Map<String, dynamic>? _tryParseBusinessError(String head) {
    final trimmed = head.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final code = decoded['code'];
    if (code is! int) return null;
    return Map<String, dynamic>.from(decoded);
  }

  /// 举报公开分享（需登录，匿名分享页也可先登录再举报）
  Future<void> report({required String shareId, required String reason}) {
    return _http.request<dynamic>(
      '/share/report',
      method: 'POST',
      data: {'shareId': shareId, 'reason': reason},
    );
  }

  /// 属主申诉被举报隐藏的分享；管理员复核后才会恢复
  Future<void> appeal({required String shareId, required String reason}) {
    return _http.request<dynamic>(
      '/share/appeal',
      method: 'POST',
      data: {'shareId': shareId, 'reason': reason},
    );
  }

  /// 查询某条分享最新的申诉状态；没有申诉时后端返回 null
  Future<ShareAppeal?> getAppeal(String shareId) {
    return _http.request<ShareAppeal?>(
      '/share/appeal',
      query: {'shareId': shareId},
      dataDecoder: (json) {
        if (json == null) return null;
        return ShareAppeal.fromJson(json as Map<String, dynamic>);
      },
    );
  }

  /// 修改已有分享的文件收集开关；仅单个文件夹分享可开启
  Future<void> setCollect({
    required String shareId,
    required bool enabled,
  }) {
    return _http.request<dynamic>(
      '/share/${Uri.encodeComponent(shareId)}/collect',
      method: 'PUT',
      query: {'enabled': enabled},
    );
  }

  /// 文件收集上传：访问者向分享者开启收集的文件夹上传文件
  ///
  /// 服务端只从 Share-Token 中取 shareId，不接收请求体里的 shareId，避免 IDOR。
  Future<void> collect({
    required File file,
    required String shareToken,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.path.split(Platform.pathSeparator).last),
    });
    try {
      final response = await _http.dio.post<dynamic>(
        '/share/collect',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Share-Token': shareToken},
          sendTimeout: Duration.zero,
          receiveTimeout: Duration.zero,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      _unwrap<dynamic>(response.data, (json) => json);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? -1,
        e.response?.statusCode == 413 ? '文件过大（文件收集单文件上限 2GB）' : '上传失败',
      );
    }
  }

  /// 保存分享文件到网盘（需登录 + Share-Token 头）
  Future<dynamic> save({
    required List<String> fileIds,
    required String targetParentId,
    required String shareToken,
  }) {
    return _http.request<dynamic>(
      '/share/save',
      method: 'POST',
      data: {'fileIds': fileIds, 'targetParentId': targetParentId},
      extraHeaders: {'Share-Token': shareToken},
    );
  }
}

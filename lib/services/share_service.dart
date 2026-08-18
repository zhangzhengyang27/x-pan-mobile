import '../core/network/http_client.dart';
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

/// 分享简单详情，对齐后端 ShareSimpleDetailVO
class ShareSimpleDetail {
  const ShareSimpleDetail({
    required this.shareId,
    required this.shareName,
    required this.shareUserInfo,
    this.hasShareCode = false,
    this.downloadLimit = 0,
  });

  final String shareId;
  final String shareName;
  final ShareUserInfo shareUserInfo;
  final bool hasShareCode;
  final int downloadLimit;

  factory ShareSimpleDetail.fromJson(Map<String, dynamic> json) {
    return ShareSimpleDetail(
      shareId: json['shareId'] as String? ?? '',
      shareName: json['shareName'] as String? ?? '',
      shareUserInfo: ShareUserInfo.fromJson(
        _castMap(json['shareUserInfoVO']),
      ),
      hasShareCode: json['hasShareCode'] as bool? ?? false,
      downloadLimit: json['downloadLimit'] as int? ?? 0,
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

  factory ShareDetail.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['xPanUserFileVOList'] as List<dynamic>? ?? const [];
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
      downloadCount: json['downloadCount'] as int? ?? 0,
      downloadLimit: json['downloadLimit'] as int? ?? 0,
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
  /// 后端 CreateShareUrlPO 字段：shareName / shareType / shareDayType / shareFileIds
  /// shareDayType: 0=永久 1=7天 2=30天
  Future<ShareVO> create({
    required String shareName,
    required List<String> fileIds,
    int shareType = 1,
    int shareDayType = 0,
    String? shareCode,
    int? downloadLimit,
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

  /// 分享文件列表（需 Share-Token 头）
  Future<List<FileVO>> fileList({
    required String parentId,
    required String shareToken,
  }) {
    return _http.request<List<FileVO>>(
      '/share/file/list',
      query: {'parentId': parentId},
      extraHeaders: {'Share-Token': shareToken},
      dataDecoder: (json) => (json as List<dynamic>)
          .map((e) => FileVO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
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

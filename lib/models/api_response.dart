/// 后端统一响应结构 R&lt;T&gt;
///
/// 对齐前端 ApiResponse：{ code, message, data }
class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  final int code;
  final String message;
  final T? data;

  /// 是否成功（对齐后端 code === 0 为成功）
  bool get isSuccess => code == 0;

  /// 是否要求重新登录（对齐后端 code === 10）
  bool get needRelogin => code == 10;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? dataDecoder,
  ) {
    return ApiResponse(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? '',
      data: json['data'] == null
          ? null
          : (dataDecoder != null ? dataDecoder(json['data']) : json['data'] as T?),
    );
  }
}

/// 后端分页结构 PageVO&lt;T&gt;
class PageVO<T> {
  const PageVO({
    required this.total,
    required this.pageSize,
    required this.pageNum,
    required this.records,
    this.totalPages,
    this.hasMore,
  });

  final int total;
  final int pageSize;
  final int pageNum;
  final List<T> records;
  final int? totalPages;
  final bool? hasMore;

  factory PageVO.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) itemDecoder,
  ) {
    final rawRecords = json['records'] as List<dynamic>? ?? const [];
    return PageVO(
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int?,
      pageSize: json['pageSize'] as int? ?? 0,
      pageNum: json['pageNum'] as int? ?? 0,
      records: rawRecords.map((e) => itemDecoder(e)).toList(),
      hasMore: json['hasMore'] as bool?,
    );
  }
}

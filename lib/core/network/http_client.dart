import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// 业务异常：携带后端 code/message
class ApiException implements Exception {
  const ApiException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'ApiException($code): $message';
}

/// 需要重新登录的异常（后端 code === 10）
class NeedReloginException extends ApiException {
  const NeedReloginException() : super(10, '请重新登录');
}

/// HTTP 客户端封装
///
/// 对齐前端 http.ts 的拦截逻辑：
/// - 注入 Authorization / X-Pan-Trace-Id
/// - 响应头 new-access-token 自动续期
/// - code !== 0 抛 ApiException，code === 10 抛 NeedReloginException
class HttpClient {
  HttpClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.requestTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConfig.requestTimeoutMs),
        contentType: Headers.jsonContentType,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.getToken();
          if (token.isNotEmpty) {
            options.headers['Authorization'] = token;
          }
          options.headers['X-Pan-Trace-Id'] = genTraceId();
          handler.next(options);
        },
        onResponse: (response, handler) {
          // token 续期
          final newToken = response.headers.value('new-access-token');
          if (newToken != null && newToken.isNotEmpty) {
            TokenStorage.setToken(newToken);
          }
          handler.next(response);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  static final HttpClient instance = HttpClient._();

  late final Dio _dio;

  Dio get dio => _dio;

  /// 发起请求并解析为统一业务数据 T
  ///
  /// 成功（code === 0）返回 data；否则抛出异常。
  Future<T> request<T>(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Object? data,
    Map<String, dynamic>? extraHeaders,
    T Function(dynamic json)? dataDecoder,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: data,
        options: Options(
          method: method,
          headers: extraHeaders,
        ),
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
      if (dataDecoder != null) {
        return dataDecoder(rawData);
      }
      return rawData as T;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? -1,
        _dioErrorToMessage(e),
      );
    }
  }

  String _dioErrorToMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '请求超时';
      case DioExceptionType.connectionError:
        return '网络已断开，请检查网络';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) return '请重新登录';
        if (status == 403) return '无权访问';
        if (status == 413) return '文件过大';
        if (status != null && status >= 500) return '服务器错误，请稍后重试';
        return '请求失败（$status）';
      default:
        return '请求失败';
    }
  }

  String genTraceId() {
    final time = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'app-$time-$rand';
  }
}

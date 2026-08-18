import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 未配置 API Key
class LlmNotConfiguredException implements Exception {
  const LlmNotConfiguredException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// API Key 无效或过期
class LlmInvalidKeyException implements Exception {
  const LlmInvalidKeyException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// LLM 消息
class LLMMessage {
  const LLMMessage({required this.role, required this.content});

  final String role; // system / user / assistant
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// LLM 服务（DeepSeek，兼容 OpenAI Chat Completions 格式）
///
/// 对齐网页版 useLLM。API Key 存本地，个人网盘场景直连 DeepSeek。
class LLMService {
  LLMService._();

  static final LLMService instance = LLMService._();

  static const String _endpoint = 'https://api.deepseek.com/chat/completions';
  static const String _model = 'deepseek-chat';
  static const String _apiKeyStorage = 'xpan_ai_apikey';

  // 使用 Keychain/Keystore 加密存储 API Key（不要求 minSdk 23）
  static const _storage = FlutterSecureStorage();

  Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _apiKeyStorage);
    } else {
      await _storage.write(key: _apiKeyStorage, value: trimmed);
    }
  }

  Future<String> getApiKey() async {
    return await _storage.read(key: _apiKeyStorage) ?? '';
  }

  Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key.isNotEmpty;
  }

  /// 对话接口（非流式）
  Future<String> chat(
    List<LLMMessage> messages, {
    double temperature = 0.7,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      throw const LlmNotConfiguredException('未配置 API Key，请先到「AI 助手」设置');
    }

    final dio = Dio();
    try {
      final res = await dio.post<dynamic>(
        _endpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
        ),
        data: jsonEncode({
          'model': _model,
          'messages': messages.map((m) => m.toJson()).toList(),
          'temperature': temperature,
          'stream': false,
        }),
      );

      final data = res.data;
      if (data is Map) {
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'];
          return message?['content']?.toString() ?? '';
        }
      }
      return '';
    } on DioException catch (e) {
      var errMsg = '请求失败 (${e.response?.statusCode})';
      final errData = e.response?.data;
      if (errData is Map) {
        final err = errData['error'];
        if (err is Map && err['message'] != null) {
          errMsg = err['message'].toString();
        }
      }
      if (e.response?.statusCode == 401) {
        throw const LlmInvalidKeyException('API Key 无效或已过期，请到「AI 助手」重新配置');
      }
      if (e.response?.statusCode == 429) {
        throw const LlmNotConfiguredException('请求过于频繁，请稍后再试');
      }
      throw Exception(errMsg);
    }
  }
}

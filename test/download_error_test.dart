import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/services/download_service.dart';

/// 下载业务错误识别回归测试
///
/// 背景：`/file/download` 被登录切面包裹，token 失效或业务失败时后端返回
/// HTTP 200 + JSON（{"code":10,...}）——`dio.download` 会把错误 JSON 原样
/// 写进目标文件，进度走满 100% 并"打开"一个损坏文件。
///
/// 契约：小体积且解析出数字 code 的 JSON 内容识别为业务错误体；真实文件
/// （zip/文本/无 code 字段的 JSON）不误判。
void main() {
  group('DownloadService.tryParseBusinessError', () {
    test('业务错误 JSON 识别为错误体', () {
      final body = jsonEncode({'code': 1, 'message': '文件不存在', 'data': null});
      final parsed = DownloadService.tryParseBusinessError(body);
      expect(parsed, isNotNull);
      expect(parsed!['code'], 1);
      expect(parsed['message'], '文件不存在');
    });

    test('会话过期 code=10 识别为错误体', () {
      final body = jsonEncode({'code': 10, 'message': '请重新登录'});
      final parsed = DownloadService.tryParseBusinessError(body);
      expect(parsed, isNotNull);
      expect(parsed!['code'], 10);
    });

    test('zip 文件头不误判', () {
      final parsed = DownloadService.tryParseBusinessError('PK\x03\x04\x14\x00\x00\x00');
      expect(parsed, isNull);
    });

    test('非 JSON 文本不误判', () {
      expect(DownloadService.tryParseBusinessError('hello, world'), isNull);
      expect(DownloadService.tryParseBusinessError('[1,2,3]'), isNull);
    });

    test('无 code 字段的 JSON 不误判', () {
      final body = jsonEncode({'hello': 'world'});
      expect(DownloadService.tryParseBusinessError(body), isNull);
    });

    test('code 非数字不误判', () {
      final body = jsonEncode({'code': 'ok', 'message': 'data file'});
      expect(DownloadService.tryParseBusinessError(body), isNull);
    });
  });
}

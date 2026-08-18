import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/utils/format.dart';

void main() {
  group('translateFileSize', () {
    test('字节级', () {
      expect(translateFileSize(1024), '1.00K');
    });

    test('KB 级', () {
      expect(translateFileSize(1024 * 1024), '1.00M');
    });

    test('MB 级', () {
      expect(translateFileSize(1024 * 1024 * 1024), '1.00G');
    });

    test('小数保留两位', () {
      expect(translateFileSize(1024 * 1536), '1.50M');
    });
  });

  group('parseFileSize', () {
    test('字符串解析', () {
      expect(parseFileSize('2048'), 2048);
    });

    test('数字直通', () {
      expect(parseFileSize(2048), 2048);
    });

    test('null 返回 0', () {
      expect(parseFileSize(null), 0);
    });

    test('非法字符串返回 0', () {
      expect(parseFileSize('abc'), 0);
    });
  });
}

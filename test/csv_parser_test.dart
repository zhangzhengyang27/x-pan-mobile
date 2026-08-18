import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/utils/csv_parser.dart';

void main() {
  group('parseCsv', () {
    test('基本逗号分隔', () {
      final result = parseCsv('a,b,c\n1,2,3');
      expect(result.length, 2);
      expect(result[0], ['a', 'b', 'c']);
      expect(result[1], ['1', '2', '3']);
    });

    test('引号包裹的字段（含逗号）', () {
      final result = parseCsv('a,"b,c",d');
      expect(result.length, 1);
      expect(result[0], ['a', 'b,c', 'd']);
    });

    test('转义双引号', () {
      final result = parseCsv('"he said ""hi""",x');
      expect(result[0][0], 'he said "hi"');
    });

    test('制表符分隔', () {
      final result = parseCsv('a\tb\tc');
      expect(result[0], ['a', 'b', 'c']);
    });

    test('分号分隔', () {
      final result = parseCsv('a;b;c');
      expect(result[0], ['a', 'b', 'c']);
    });

    test('空行被忽略', () {
      final result = parseCsv('a,b\n\n1,2\n\n');
      expect(result.length, 2);
    });

    test('CRLF 换行', () {
      final result = parseCsv('a,b\r\n1,2\r\n');
      expect(result.length, 2);
      expect(result[1], ['1', '2']);
    });

    test('字段内含换行（引号内）', () {
      final result = parseCsv('"line1\nline2",x');
      expect(result[0][0], 'line1\nline2');
    });

    test('空字符串返回空列表', () {
      expect(parseCsv(''), isEmpty);
    });
  });
}

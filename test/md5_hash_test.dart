import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/utils/md5_hash.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xpan_md5_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('isolate MD5 与标准 crypto 一致（小文件）', () async {
    final content = 'hello x-pan';
    final file = File('${tempDir.path}/a.txt')..writeAsStringSync(content);

    final expected = md5.convert(content.codeUnits).toString();
    final actual = await computeFileMd5(file.path);

    expect(actual, expected);
  });

  test('isolate MD5 与标准 crypto 一致（空文件）', () async {
    final file = File('${tempDir.path}/empty.txt')..writeAsStringSync('');

    final expected = md5.convert(<int>[]).toString();
    final actual = await computeFileMd5(file.path);

    expect(actual, expected);
  });

  test('isolate MD5 与标准 crypto 一致（跨分块边界大文件）', () async {
    // 写入超过 1MB 的数据，测试分块逻辑（分块大小 1MB）
    final file = File('${tempDir.path}/big.bin');
    final raf = file.openSync(mode: FileMode.write);
    try {
      // 1.5MB 数据（每块 1KB，写 1536 次）
      final chunk = List<int>.filled(1024, 0x41); // 'A'
      for (var i = 0; i < 1536; i++) {
        raf.writeFromSync(chunk);
      }
    } finally {
      raf.closeSync();
    }

    final bytes = file.readAsBytesSync();
    final expected = md5.convert(bytes).toString();
    final actual = await computeFileMd5(file.path);

    expect(actual, expected);
    expect(bytes.length, greaterThan(1024 * 1024)); // 确保超过 1MB 分块
  });

  test('文件不存在时抛异常', () async {
    await expectLater(
      computeFileMd5('${tempDir.path}/nonexistent.bin'),
      throwsA(isA<FileSystemException>()),
    );
  });
}

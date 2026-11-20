import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:x_pan_mobile/utils/e2ee_share.dart';

void main() {
  test('v2 加密解密跨多块还原文件', () async {
    final dir = await Directory.systemTemp.createTemp('e2ee-test-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final source = File('${dir.path}/source.bin');
    // 超过默认 8MB 分块，确保真正走多块路径
    final bytes = Uint8List(8 * 1024 * 1024 + 1024);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = i % 251;
    }
    await source.writeAsBytes(bytes);

    final encrypted = await encryptFileForShare(source, outputDir: dir);
    final decrypted = await decryptE2eeFile(
      encrypted.file,
      keyBase64Url: encrypted.key,
      ivBase64Url: encrypted.iv,
      outputDir: dir,
    );
    expect(decrypted.name, 'source.bin');
    expect(decrypted.size, bytes.length);
    expect(await decrypted.file.readAsBytes(), bytes);
  });

  test('分享链接 fragment 可解析并拼回', () {
    final url = buildE2eeShareUrl('https://pan.example.com/share/abc', 'k1', 'iv1');
    final uri = Uri.parse(url);
    final parsed = parseE2eeFragment(uri.fragment);
    expect(parsed, {'key': 'k1', 'iv': 'iv1'});
    expect(parseE2eeFragment(''), isNull);
    expect(parseE2eeFragment('k=only'), isNull);
  });

  test('错误密钥无法通过 GCM 校验', () async {
    final dir = await Directory.systemTemp.createTemp('e2ee-test-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final source = File('${dir.path}/source.bin');
    await source.writeAsBytes(Uint8List.fromList(List.filled(100 * 1024, 9)));
    final encrypted = await encryptFileForShare(source, outputDir: dir);
    // 翻转 key 的一个字节，GCM tag 必须失败；任何异常都说明没有静默输出错误明文
    final wrongKey = encrypted.key.startsWith('A')
        ? 'B${encrypted.key.substring(1)}'
        : 'A${encrypted.key.substring(1)}';
    await expectLater(
      decryptE2eeFile(
        encrypted.file,
        keyBase64Url: wrongKey,
        ivBase64Url: encrypted.iv,
        outputDir: dir,
      ),
      throwsA(anything),
    );
  });

  test('密文截断时解密失败', () async {
    final dir = await Directory.systemTemp.createTemp('e2ee-test-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final source = File('${dir.path}/source.bin');
    await source.writeAsBytes(Uint8List.fromList(List.filled(100 * 1024, 7)));
    final encrypted = await encryptFileForShare(source, outputDir: dir);
    final truncated = File('${dir.path}/truncated.xpan');
    final cipher = await encrypted.file.readAsBytes();
    await truncated.writeAsBytes(cipher.sublist(0, cipher.length - 10));
    await expectLater(
      decryptE2eeFile(
        truncated,
        keyBase64Url: encrypted.key,
        ivBase64Url: encrypted.iv,
        outputDir: dir,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// 在后台 isolate 中计算文件 MD5（大文件不阻塞 UI）
///
/// 仅传递文件路径（File 对象不能跨 isolate 传递）。
/// 在 isolate 内通过流式读取（1MB 分块）计算，避免大文件占用过多内存。
Future<String> computeFileMd5(String filePath) {
  return Isolate.run(() async {
    final file = File(filePath);
    final stream = file.openRead();
    final digest = await md5.bind(stream).first;
    return digest.toString();
  });
}

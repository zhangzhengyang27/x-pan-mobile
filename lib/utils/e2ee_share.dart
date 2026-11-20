import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

/// E2EE 加密分享（移动端）
///
/// 与 Web 端使用完全相同的 v2 密文格式：MAGIC + 4 字节 header 长度 + JSON header +
/// 若干 `[4 字节密文长度][AES-GCM 密文+tag]` 块。每块 IV 由基础 IV 的最后 4 字节
/// 加块序号得到，header 原始字节 + 块序号作为 AAD，重排/截断/篡改 header 都会失败。
///
/// 移动端文件可能达到 20GB，因此全程使用 RandomAccessFile 逐块读写，不把整文件读入内存。
class E2eeCipherResult {
  const E2eeCipherResult({
    required this.file,
    required this.key,
    required this.iv,
    required this.filename,
  });

  final File file;
  final String key;
  final String iv;
  final String filename;

  Future<void> cleanup() async {
    if (await file.exists()) await file.delete();
  }
}

class E2eeDecryptedResult {
  const E2eeDecryptedResult({
    required this.file,
    required this.name,
    required this.type,
    required this.size,
  });

  final File file;
  final String name;
  final String type;
  final int size;
}

const _magicV2 = 'XPAN-E2EE-2';
const _headerLenBytes = 4;
const _gcmTagBytes = 16;
const _keyBytes = 32;
const _ivBytes = 12;
const _maxHeaderBytes = 64 * 1024;
const _chunkSize = 8 * 1024 * 1024;
const _maxChunkBytes = 16 * 1024 * 1024;
const _maxPlaintextBytes = 20 * 1024 * 1024 * 1024 - 1024 * 1024;

/// 明文上限（20GB 减 1MB，为 header 与分块 framing 留余量）
const int e2eeMaxPlaintextBytes = _maxPlaintextBytes;
const _maxChunks = 1000000;

final _aes = AesGcm.with256bits();

int _be32(Uint8List bytes, int offset) {
  final data = ByteData.sublistView(bytes, offset, offset + 4);
  return data.getUint32(0, Endian.big);
}

Uint8List _uint32(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List _concat(List<int> a, List<int> b) {
  final out = Uint8List(a.length + b.length);
  out.setRange(0, a.length, a);
  out.setRange(a.length, out.length, b);
  return out;
}

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _fromBase64Url(String value) {
  final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  final pad = (4 - normalized.length % 4) % 4;
  return base64.decode(normalized + '=' * pad);
}

Uint8List _deriveIv(List<int> baseIv, int index) {
  final iv = Uint8List(baseIv.length);
  iv.setRange(0, iv.length, baseIv);
  final view = ByteData.sublistView(iv);
  final next = (view.getUint32(8, Endian.big) + index) & 0xffffffff;
  view.setUint32(8, next, Endian.big);
  return iv;
}

Uint8List _chunkAad(List<int> headerBytes, int index) {
  final out = Uint8List(headerBytes.length + 4);
  out.setRange(0, headerBytes.length, headerBytes);
  final view = ByteData.sublistView(out);
  view.setUint32(headerBytes.length, index, Endian.big);
  return out;
}

String _cipherFilename(String name) {
  final base = (name.isEmpty ? 'file' : name).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return '${base.length > 200 ? base.substring(0, 200) : base}.xpan';
}

Future<Uint8List> _readExact(RandomAccessFile file, int count) async {
  final out = Uint8List(count);
  var offset = 0;
  while (offset < count) {
    final chunk = await file.read(count - offset);
    if (chunk.isEmpty) throw const FormatException('密文被截断');
    out.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return out;
}

/// 加密本地文件，返回临时密文文件的路径与 key/iv。
Future<E2eeCipherResult> encryptFileForShare(
  File source, {
  void Function(double progress)? onProgress,
  Directory? outputDir,
}) async {
  final sourceSize = await source.length();
  if (sourceSize <= 0) throw const FormatException('空文件不能加密分享');
  if (sourceSize > _maxPlaintextBytes) throw const FormatException('加密分享暂支持 20GB 以内文件');

  final chunkCount = (sourceSize + _chunkSize - 1) ~/ _chunkSize;
  if (chunkCount > _maxChunks) throw const FormatException('文件分块数量过多');

  final secretKey = SecretKeyData.random(length: _keyBytes);
  final baseIv = Uint8List.fromList(
    List<int>.generate(_ivBytes, (_) => Random.secure().nextInt(256)),
  );
  final header = utf8.encode(jsonEncode({
    'v': 2,
    'name': source.path.split(Platform.pathSeparator).last,
    'type': 'application/octet-stream',
    'size': sourceSize,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'chunkSize': _chunkSize,
    'chunkCount': chunkCount,
  }));
  if (header.length > _maxHeaderBytes) throw const FormatException('文件元数据过大');

  final prefix = _concat(_concat(utf8.encode(_magicV2), _uint32(header.length)), header);
  final tempDir = outputDir ?? await getTemporaryDirectory();
  final output = File('${tempDir.path}/e2ee-${DateTime.now().microsecondsSinceEpoch}.xpan');
  RandomAccessFile? input;
  IOSink? sink;
  try {
    input = await source.open(mode: FileMode.read);
    sink = output.openWrite();
    sink.add(prefix);
    var offset = 0;
    for (var index = 0; index < chunkCount; index++) {
      final len = min(_chunkSize, sourceSize - offset);
      final plain = await input.read(len);
      if (plain.length != len) throw const FormatException('原文件读取不完整');
      final box = await _aes.encrypt(
        plain,
        secretKey: secretKey,
        nonce: _deriveIv(baseIv, index),
        aad: _chunkAad(header, index),
      );
      final cipher = _concat(box.cipherText, box.mac.bytes);
      sink.add(_uint32(cipher.length));
      sink.add(cipher);
      offset += plain.length;
      onProgress?.call(offset / sourceSize);
    }
    await sink.flush();
    await sink.close();
    sink = null;
    await input.close();
    input = null;
    final keyBytes = await secretKey.extractBytes();
    return E2eeCipherResult(
      file: output,
      key: _base64Url(keyBytes),
      iv: _base64Url(baseIv),
      filename: _cipherFilename(source.path.split(Platform.pathSeparator).last),
    );
  } catch (_) {
    if (sink != null) await sink.close().catchError((_) {});
    if (input != null) await input.close().catchError((_) {});
    if (await output.exists()) await output.delete();
    rethrow;
  }
}

/// 解密 v2 密文到临时文件；返回的 File 由调用方负责打开或清理。
Future<E2eeDecryptedResult> decryptE2eeFile(
  File cipherFile, {
  required String keyBase64Url,
  required String ivBase64Url,
  void Function(double progress)? onProgress,
  Directory? outputDir,
}) async {
  final secretKey = SecretKeyData(_fromBase64Url(keyBase64Url));
  final baseIv = _fromBase64Url(ivBase64Url);
  if (baseIv.length != _ivBytes) throw const FormatException('解密 IV 长度不正确');

  final cipherSize = await cipherFile.length();
  RandomAccessFile? input;
  IOSink? sink;
  File? output;
  try {
    input = await cipherFile.open(mode: FileMode.read);
    final prefix = await _readExact(input, utf8.encode(_magicV2).length);
    if (utf8.decode(prefix) != _magicV2) throw const FormatException('密文格式不正确');
    final headerLen = _be32(await _readExact(input, _headerLenBytes), 0);
    if (headerLen <= 0 || headerLen > _maxHeaderBytes) throw const FormatException('密文头部损坏');
    final headerBytes = await _readExact(input, headerLen);
    final Map<String, dynamic> header;
    try {
      header = jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('密文头部损坏');
    }
    final size = (header['size'] as num?)?.toInt() ?? -1;
    final chunkSize = (header['chunkSize'] as num?)?.toInt() ?? 0;
    final chunkCount = (header['chunkCount'] as num?)?.toInt() ?? 0;
    final name = header['name'] as String? ?? 'download';
    final type = header['type'] as String? ?? 'application/octet-stream';
    if (size <= 0 ||
        chunkSize < 64 * 1024 ||
        chunkSize > _maxChunkBytes ||
        chunkCount <= 0 ||
        chunkCount != (size + chunkSize - 1) ~/ chunkSize) {
      throw const FormatException('密文头部分块信息损坏');
    }

    final tempDir = outputDir ?? await getTemporaryDirectory();
    output = File('${tempDir.path}/decrypted-${DateTime.now().microsecondsSinceEpoch}');
    sink = output.openWrite();
    var written = 0;
    for (var index = 0; index < chunkCount; index++) {
      final cipherLen = _be32(await _readExact(input, 4), 0);
      final expectedPlain = min(chunkSize, size - written);
      if (cipherLen != expectedPlain + _gcmTagBytes) throw const FormatException('密文分块长度不一致');
      final cipher = await _readExact(input, cipherLen);
      final box = SecretBox(
        cipher.sublist(0, cipher.length - _gcmTagBytes),
        nonce: _deriveIv(baseIv, index),
        mac: Mac(cipher.sublist(cipher.length - _gcmTagBytes)),
      );
      final plain = await _aes.decrypt(
        box,
        secretKey: secretKey,
        aad: _chunkAad(headerBytes, index),
      );
      if (plain.length != expectedPlain) throw const FormatException('密文分块长度不一致');
      sink.add(plain);
      written += plain.length;
      onProgress?.call(written / size);
    }
    if (written != size || await input.length() != cipherSize) {
      throw const FormatException('明文长度与头部声明不一致');
    }
    await sink.flush();
    await sink.close();
    sink = null;
    await input.close();
    input = null;
    return E2eeDecryptedResult(file: output, name: name, type: type, size: size);
  } catch (_) {
    if (sink != null) await sink.close().catchError((_) {});
    if (input != null) await input.close().catchError((_) {});
    if (output != null && await output.exists()) await output.delete();
    rethrow;
  }
}

/// 分享链接 fragment：`#k=<base64url key>&iv=<base64url iv>`。
Map<String, String>? parseE2eeFragment(String hash) {
  final raw = hash.startsWith('#') ? hash.substring(1) : hash;
  if (raw.isEmpty) return null;
  final params = Uri.splitQueryString(raw);
  final key = params['k'] ?? '';
  final iv = params['iv'] ?? '';
  if (key.isEmpty || iv.isEmpty) return null;
  return {'key': key, 'iv': iv};
}

String buildE2eeShareUrl(String baseUrl, String key, String iv) =>
    '$baseUrl#k=${Uri.encodeComponent(key)}&iv=${Uri.encodeComponent(iv)}';

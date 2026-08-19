import 'package:flutter/material.dart';

import '../core/storage/recent_storage.dart';
import '../models/file_vo.dart';
import '../pages/csv_preview_page.dart';
import '../pages/office_preview_page.dart';
import '../pages/pdf_preview_page.dart';
import '../pages/text_preview_page.dart';
import '../pages/video_preview_page.dart';
import '../pages/audio_preview_page.dart';
import '../pages/xmind_preview_page.dart';
import '../services/download_service.dart';
import '../services/user_service.dart';
import '../core/theme/app_tokens.dart';

/// 根据文件类型打开对应预览页或下载（对齐 home_page._openFile）。
///
/// [images] 为同分类的文件列表，用于图片预览时在多图间滑动。
/// 点击文件夹不会进入此函数（分类页均为文件）。
void openFileByType(
  BuildContext context,
  FileVO file, {
  List<FileVO> images = const [],
}) {
  _recordRecent(file);

  if (file.filename.toLowerCase().endsWith('.xmind')) {
    Navigator.of(context).push(AppTokens.route(XmindPreviewPage(file: file)));
    return;
  }

  final route = switch (file.fileType) {
    FileType.video => AppTokens.route(VideoPreviewPage(file: file)),
    FileType.audio => AppTokens.route(AudioPreviewPage(file: file)),
    FileType.pdf => AppTokens.route(PDFPreviewPage(file: file)),
    FileType.csv => AppTokens.route(CsvPreviewPage(file: file)),
    FileType.txt || FileType.code =>
      AppTokens.route(TextPreviewPage(file: file)),
    FileType.word || FileType.excel || FileType.ppt =>
      AppTokens.route(OfficePreviewPage(file: file)),
    _ => null,
  };

  if (route != null) {
    Navigator.of(context).push(route);
    return;
  }
  _download(context, file);
}

/// 记录最近访问（异步，不阻塞 UI）
void _recordRecent(FileVO file) {
  final now = DateTime.now();
  final timeStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  RecentStorage.add(
    RecentItem(
      fileId: file.fileId,
      filename: file.filename,
      fileType: file.fileType.value,
      visitTime: timeStr,
    ),
  );
}

Future<void> _download(BuildContext context, FileVO file) async {
  try {
    await DownloadService.instance.downloadAndOpen(
      fileId: file.fileId,
      filename: file.filename,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败：$e')),
      );
    }
  }
}

/// 解析缩略图/封面直链（带尺寸参数，对齐前端 resolvePreviewUrl）。
///
/// 优先使用后端返回的 `thumbnail`/`fileCover`，否则按需解析预览直链。
/// 音频无封面直链意义，直接返回 null（由调用方降级为类型图标）。
Future<String?> resolveCoverUrl(
  FileVO file, {
  int width = 320,
  int height = 320,
}) async {
  if (file.fileType == FileType.audio) return null;
  final cached = file.thumbnail ?? file.fileCover;
  if (cached != null && cached.isNotEmpty) return cached;
  if (file.fileType != FileType.image && file.fileType != FileType.video) {
    return null;
  }
  try {
    return await FileService.instance.resolvePreviewUrl(
      file.fileId,
      width: width,
      height: height,
    );
  } catch (_) {
    return null;
  }
}

/// 将文件按创建时间归组为时间轴分组（今天/昨天/本周/本月/更早）
/// 返回 [标签, 文件列表] 的列表，按时间由近到远排序。
List<(String, List<FileVO>)> groupByTimeline(List<FileVO> files) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthAgo = today.subtract(const Duration(days: 30));

  String labelFor(DateTime t) {
    if (t.isAfter(today)) return '今天';
    if (t.isAfter(yesterday)) return '昨天';
    if (t.isAfter(weekAgo)) return '本周';
    if (t.isAfter(monthAgo)) return '本月';
    return '更早';
  }

  final map = <String, List<FileVO>>{};
  for (final f in files) {
    final t = _parseTime(f.createTime) ?? now;
    final label = labelFor(DateTime(t.year, t.month, t.day));
    map.putIfAbsent(label, () => []).add(f);
  }

  const order = ['今天', '昨天', '本周', '本月', '更早'];
  final groups = <(String, List<FileVO>)>[];
  for (final label in order) {
    final list = map[label];
    if (list != null && list.isNotEmpty) {
      list.sort((a, b) => b.createTime.compareTo(a.createTime));
      groups.add((label, list));
    }
  }
  return groups;
}

DateTime? _parseTime(String s) {
  try {
    return DateTime.parse(s.replaceFirst(' ', 'T'));
  } catch (_) {
    return null;
  }
}

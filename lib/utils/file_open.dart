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

/// 时间线分组粒度（对齐前端 ImageTimeline）。
///
/// - [smart]：相对分组（今天/昨天/本周/本月/更早），用于文档等时间跨度大的分类。
/// - [day]  ：按 年月日 精确分组（2026年03月05日）。
/// - [month]：按 年月 精确分组（2026年03月）。
/// - [year] ：按 年 精确分组（2026年）。
enum TimelineMode { smart, day, month, year }

/// 单个时间线分组。
class TimelineGroup {
  const TimelineGroup(this.label, this.files);
  final String label;
  final List<FileVO> files;
}

/// 按 [mode] 将文件归组为时间轴分组，组内按时间由近到远、组间由近到远排序。
///
/// [smart] 模式兼容旧版文档视图的模糊分组（今天/昨天/本周/本月/更早）。
List<TimelineGroup> groupByTimeline(
  List<FileVO> files, [
  TimelineMode mode = TimelineMode.smart,
]) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  String labelFor(DateTime t) {
    if (mode != TimelineMode.smart) {
      final y = t.year;
      final m = t.month.toString().padLeft(2, '0');
      final d = t.day.toString().padLeft(2, '0');
      switch (mode) {
        case TimelineMode.year:
          return '$y年';
        case TimelineMode.month:
          return '$y年$m月';
        case TimelineMode.day:
          if (t.isAtSameMomentAs(today)) return '今天';
          final yesterday = today.subtract(const Duration(days: 1));
          if (t.isAtSameMomentAs(yesterday)) return '昨天';
          if (t.year == now.year) return '$m月$d日';
          return '$y年$m月$d日';
        default:
          break;
      }
    }
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));
    if (t.isAfter(today)) return '今天';
    if (t.isAfter(yesterday)) return '昨天';
    if (t.isAfter(weekAgo)) return '本周';
    if (t.isAfter(monthAgo)) return '本月';
    return '更早';
  }

  // 用 int 排序 key：smart 模式用固定权重（小在前），精确模式用 -时间戳（取负后倒序，最新在前）。
  final groupsMap = <String, TimelineGroup>{};
  final orderList = <(int, String)>[];
  final seen = <String>{};

  for (final f in files) {
    final t = _parseTime(f.createTime) ?? now;
    final dayKey = DateTime(t.year, t.month, t.day);
    final label = labelFor(dayKey);
    if (!seen.contains(label)) {
      seen.add(label);
      groupsMap[label] = TimelineGroup(label, []);
      final sortKey = mode == TimelineMode.smart
          ? _smartOrder(label)
          : -dayKey.millisecondsSinceEpoch;
      orderList.add((sortKey, label));
    }
    groupsMap[label]!.files.add(f);
  }

  // 统一升序排序：smart 权重小在前；精确分组 -时间戳 使最新组排最前。
  orderList.sort((a, b) => a.$1.compareTo(b.$1));

  final result = <TimelineGroup>[];
  for (final (_, label) in orderList) {
    final g = groupsMap[label]!;
    g.files.sort((a, b) => b.createTime.compareTo(a.createTime));
    result.add(g);
  }
  return result;
}

/// smart 模式下的固定排序权重（越小越靠前）。
int _smartOrder(String label) {
  const order = ['今天', '昨天', '本周', '本月', '更早'];
  final i = order.indexOf(label);
  return i == -1 ? order.length : i;
}

DateTime? _parseTime(String s) {
  try {
    return DateTime.parse(s.replaceFirst(' ', 'T'));
  } catch (_) {
    return null;
  }
}

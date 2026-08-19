import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/user_service.dart';
import '../utils/csv_parser.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

/// CSV 表格预览页
///
/// 通过后端 text-extract 获取文本（后端已做编码识别），
/// 前端解析 CSV 并渲染为表格（对齐网页版 CsvPreviewer 逻辑）。
class CsvPreviewPage extends ConsumerStatefulWidget {
  const CsvPreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  ConsumerState<CsvPreviewPage> createState() => _CsvPreviewPageState();
}

class _CsvPreviewPageState extends ConsumerState<CsvPreviewPage> {
  List<String> _headers = [];
  List<List<String>> _rows = [];
  List<double> _colWidths = [];
  bool _loading = true;
  bool _truncated = false;
  String? _error;

  static const int _maxRows = 5000;
  static const int _maxCells = 200;
  static const double _indexColWidth = 52;
  static const double _minColWidth = 56;
  static const double _maxColWidth = 240;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final result =
          await FileService.instance.textExtract(widget.file.fileId);
      final text = result.text;
      if (text.trim().isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final data = parseCsv(text);
      if (data.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final header = data[0].take(_maxCells).toList();
      final body = <List<String>>[];
      for (var r = 1; r < data.length && r < _maxRows; r++) {
        body.add(data[r].take(_maxCells).toList());
      }
      if (mounted) {
        setState(() {
          _headers = header;
          _rows = body;
          _colWidths = _computeColWidths(header, body);
          _truncated = data.length > _maxRows || result.truncated;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.file.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const _CsvSkeleton();
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: _error,
      );
    }
    if (_headers.isEmpty) {
      return const EmptyState(
        icon: Icons.table_view_outlined,
        title: '空文件',
      );
    }

    return Column(
      children: [
        if (_truncated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space16,
              vertical: AppTokens.space8,
            ),
            color: AppTokens.brandPrimary.withValues(alpha: 0.08),
            child: Text(
              '数据量较大，仅展示部分行，请下载完整文件查看',
              style: AppTokens.bodySmall.copyWith(
                color: AppTokens.brandPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Expanded(
          child: _buildTable(),
        ),
      ],
    );
  }

  /// 根据表头与采样数据行预估各列宽度（虚拟化布局需要稳定列宽）
  List<double> _computeColWidths(
    List<String> header,
    List<List<String>> rows,
  ) {
    final widths = List<double>.filled(header.length, 0);
    for (var i = 0; i < header.length; i++) {
      widths[i] =
          _estimateTextWidth(header[i].isEmpty ? '列 ${i + 1}' : header[i]);
    }
    // 采样前 200 行即可，避免超大表全量扫描的开销
    final sampleEnd = rows.length < 200 ? rows.length : 200;
    for (var r = 0; r < sampleEnd; r++) {
      final row = rows[r];
      for (var c = 0; c < header.length && c < row.length; c++) {
        final w = _estimateTextWidth(row[c]);
        if (w > widths[c]) widths[c] = w;
      }
    }
    return [
      for (final w in widths)
        (w + AppTokens.space12 * 2).clamp(_minColWidth, _maxColWidth),
    ];
  }

  /// 文本宽度粗估：CJK 约 13px/字，ASCII 约 7px/字（字号 13）
  double _estimateTextWidth(String text) {
    var w = 0.0;
    for (final unit in text.codeUnits) {
      w += unit > 0x2E80 ? 13 : 7;
    }
    return w;
  }

  Widget _buildTable() {
    final brightness = Theme.of(context).brightness;
    final tableWidth =
        _indexColWidth + _colWidths.fold<double>(0, (sum, w) => sum + w);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            _buildHeaderRow(brightness),
            Expanded(
              // 数据行虚拟化：仅构建可见行，5000 行大表不卡顿
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (ctx, r) => _buildDataRow(r, brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(Brightness b) {
    return Container(
      decoration: BoxDecoration(
        // 表头：品牌色背景 + 白字
        color: AppTokens.brandPrimary,
        border: Border(
          bottom: BorderSide(
            color: AppTokens.divider(b).withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _headerCell('#', _indexColWidth),
          for (var i = 0; i < _headers.length; i++)
            _headerCell(
              _headers[i].isEmpty ? '列 ${i + 1}' : _headers[i],
              _colWidths[i],
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow(int r, Brightness b) {
    // 斑马纹：奇数行 neutral50，偶数行 neutral0（暗色对应 surface 层级）
    final zebraColor = b == Brightness.dark
        ? AppTokens.darkSurfaceElevated
        : AppTokens.neutral50;
    final row = _rows[r];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.isOdd ? zebraColor : AppTokens.surface(b),
        border: Border(
          bottom: BorderSide(
            color: AppTokens.divider(b).withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _indexCell(r + 1, b),
          for (var c = 0; c < _headers.length; c++)
            _dataCell(c < row.length ? row[c] : '', b, _colWidths[c]),
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space8,
      ),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppTokens.neutral0,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _indexCell(int index, Brightness b) {
    return Container(
      width: _indexColWidth,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space8,
      ),
      color: b == Brightness.dark
          ? AppTokens.darkSurfaceElevated
          : AppTokens.neutral100,
      child: Text(
        '$index',
        style: TextStyle(
          fontSize: 12,
          color: AppTokens.textTertiary(b),
        ),
      ),
    );
  }

  Widget _dataCell(String text, Brightness b, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space8,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: AppTokens.divider(b).withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: AppTokens.textPrimary(b),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// 表格骨架屏
class _CsvSkeleton extends StatelessWidget {
  const _CsvSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTokens.space20),
      itemCount: 10,
      separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space12),
      itemBuilder: (_, i) => SkeletonBox(height: i == 0 ? 36 : 20),
    );
  }
}

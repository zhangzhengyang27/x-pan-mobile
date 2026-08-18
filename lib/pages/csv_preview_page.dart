import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_vo.dart';
import '../services/user_service.dart';
import '../utils/csv_parser.dart';

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
  bool _loading = true;
  bool _truncated = false;
  String? _error;

  static const int _maxRows = 5000;
  static const int _maxCells = 200;

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
        title: Text(widget.file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }
    if (_headers.isEmpty) {
      return const Center(child: Text('空文件'));
    }

    return Column(
      children: [
        if (_truncated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            child: const Text(
              '数据量较大，仅展示部分行，请下载完整文件查看',
              style: TextStyle(fontSize: 12),
            ),
          ),
        Expanded(
          child: _buildTable(),
        ),
      ],
    );
  }

  Widget _buildTable() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          border: TableBorder.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            // 表头
            TableRow(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
              children: [
                _headerCell('#'),
                for (var h in _headers)
                  _headerCell(h.isEmpty ? '列 ${_headers.indexOf(h) + 1}' : h),
              ],
            ),
            // 数据行
            for (var r = 0; r < _rows.length; r++)
              TableRow(
                children: [
                  _indexCell(r + 1),
                  for (var c = 0; c < _headers.length; c++)
                    _dataCell(c < _rows[r].length ? _rows[r][c] : ''),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _indexCell(int index) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: scheme.surfaceContainerHighest,
      child: Text(
        '$index',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _dataCell(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

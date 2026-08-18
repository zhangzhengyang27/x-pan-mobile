import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/file_vo.dart';
import '../services/user_service.dart';

/// 文本 / 代码 / Markdown 预览页
///
/// 通过后端 text-extract 接口获取纯文本（后端已做编码识别），
/// Markdown 用 flutter_markdown 渲染，代码/文本用等宽字体展示。
class TextPreviewPage extends StatefulWidget {
  const TextPreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  State<TextPreviewPage> createState() => _TextPreviewPageState();
}

class _TextPreviewPageState extends State<TextPreviewPage> {
  String? _content;
  String? _error;
  bool _loading = true;
  bool _truncated = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  bool get _isMarkdown {
    final name = widget.file.filename.toLowerCase();
    return name.endsWith('.md') || name.endsWith('.markdown');
  }

  Future<void> _init() async {
    try {
      final result =
          await FileService.instance.textExtract(widget.file.fileId);
      if (mounted) {
        setState(() {
          _content = result.text;
          _truncated = result.truncated;
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
    if (_content == null || _content!.isEmpty) {
      return const Center(child: Text('文件内容为空'));
    }

    return Column(
      children: [
        if (_truncated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            child: const Text(
              '内容过长，已截断显示',
              style: TextStyle(fontSize: 12),
            ),
          ),
        Expanded(
          child: _isMarkdown
              ? Markdown(
                  data: _content!,
                  selectable: true,
                  padding: const EdgeInsets.all(16),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _content!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

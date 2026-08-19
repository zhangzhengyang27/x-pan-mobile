import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/user_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

/// 文本 / 代码 / Markdown 预览页
///
/// 通过后端 text-extract 接口获取纯文本（后端已做编码识别），
/// Markdown 用 flutter_markdown 渲染，代码用等宽字体 + 行号展示。
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

  static const Set<String> _codeExtensions = {
    '.dart', '.js', '.ts', '.jsx', '.tsx', '.py', '.java', '.kt', '.swift',
    '.go', '.rs', '.c', '.cpp', '.h', '.hpp', '.cs', '.rb', '.php', '.sh',
    '.json', '.yaml', '.yml', '.xml', '.html', '.css', '.sql', '.gradle',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  bool get _isMarkdown {
    final name = widget.file.filename.toLowerCase();
    return name.endsWith('.md') || name.endsWith('.markdown');
  }

  bool get _isCode {
    final name = widget.file.filename.toLowerCase();
    return _codeExtensions.any(name.endsWith);
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
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const _TextSkeleton();
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: _error,
      );
    }
    if (_content == null || _content!.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: '文件内容为空',
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
              '内容过长，已截断显示',
              style: AppTokens.bodySmall.copyWith(
                color: AppTokens.brandPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Expanded(
          child: _isMarkdown
              ? Markdown(
                  data: _content!,
                  selectable: true,
                  padding: const EdgeInsets.all(AppTokens.space16),
                )
              : _isCode
                  ? _buildCode(brightness)
                  : _buildPlainText(brightness),
        ),
      ],
    );
  }

  /// 代码视图：neutral50 背景 + 等宽字体 + 行号
  Widget _buildCode(Brightness b) {
    final lines = LineSplitter.split(_content!).toList();
    final codeBg = b == Brightness.dark
        ? AppTokens.darkSurfaceElevated
        : AppTokens.neutral50;
    return Padding(
      padding: const EdgeInsets.all(AppTokens.space12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: ColoredBox(
          color: codeBg,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space16,
            ),
            itemCount: lines.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                        color: AppTokens.neutral400,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: SelectableText(
                      lines[i].isEmpty ? ' ' : lines[i],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                        color: AppTokens.textPrimary(b),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 普通文本视图：surface 卡片 + bodyLarge
  Widget _buildPlainText(Brightness b) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.space16),
        decoration: BoxDecoration(
          color: AppTokens.surface(b),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: AppTokens.divider(b).withValues(alpha: 0.6)),
          boxShadow: AppTokens.shadowSm(b),
        ),
        child: SelectableText(
          _content!,
          style: AppTokens.bodyLarge.copyWith(
            color: AppTokens.textPrimary(b),
          ),
        ),
      ),
    );
  }
}

/// 文本预览骨架屏
class _TextSkeleton extends StatelessWidget {
  const _TextSkeleton();

  @override
  Widget build(BuildContext context) {
    const widths = <double>[0.92, 0.78, 0.86, 0.6, 0.95, 0.72, 0.88, 0.5, 0.8];
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTokens.space20),
      itemCount: widths.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space14),
      itemBuilder: (_, i) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widths[i],
        child: const SkeletonBox(height: 14),
      ),
    );
  }
}

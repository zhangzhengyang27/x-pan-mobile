import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/download_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/pdf_preview_view.dart';
import '../widgets/skeleton.dart';

/// PDF 预览页
///
/// 下载到临时文件后用 [PdfPreviewView]（pdfx）渲染。
class PDFPreviewPage extends StatefulWidget {
  const PDFPreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  State<PDFPreviewPage> createState() => _PDFPreviewPageState();
}

class _PDFPreviewPageState extends State<PDFPreviewPage> {
  String? _localPath;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final path = await DownloadService.instance.download(
        fileId: widget.file.fileId,
        filename: widget.file.filename,
      );
      if (mounted) {
        setState(() {
          _localPath = path;
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
      return const _PdfSkeleton();
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: _error,
      );
    }
    return PdfPreviewView(filePath: _localPath!);
  }
}

/// PDF 文档骨架屏
class _PdfSkeleton extends StatelessWidget {
  const _PdfSkeleton();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const widths = <double>[0.7, 0.95, 0.88, 0.92, 0.6, 0.9, 0.82, 0.95, 0.55];
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppTokens.space20),
        padding: const EdgeInsets.all(AppTokens.space20),
        decoration: BoxDecoration(
          color: AppTokens.surface(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          boxShadow: AppTokens.shadowSm(brightness),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 140, height: 18),
            const SizedBox(height: AppTokens.space20),
            for (final w in widths) ...[
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: w,
                child: const SkeletonBox(height: 12),
              ),
              const SizedBox(height: AppTokens.space12),
            ],
          ],
        ),
      ),
    );
  }
}

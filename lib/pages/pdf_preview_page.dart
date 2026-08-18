import 'package:flutter/material.dart';

import '../models/file_vo.dart';
import '../services/download_service.dart';
import '../widgets/pdf_preview_view.dart';

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
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }
    return PdfPreviewView(filePath: _localPath!);
  }
}

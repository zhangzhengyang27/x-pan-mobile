import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// 可复用的 PDF 预览视图（基于本地文件路径）
///
/// 统一用 pdfx 渲染（桌面 + 移动端）：
/// - macOS / iOS / Android：`PdfViewPinch`（支持缩放）
/// - Windows：`PdfView`（`PdfViewPinch` 不支持 Windows）
class PdfPreviewView extends StatefulWidget {
  const PdfPreviewView({super.key, required this.filePath});

  /// 本地 PDF 文件绝对路径
  final String filePath;

  @override
  State<PdfPreviewView> createState() => _PdfPreviewViewState();
}

class _PdfPreviewViewState extends State<PdfPreviewView> {
  PdfController? _controller;
  PdfControllerPinch? _pinchController;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(PdfPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 文件路径变化时重新加载
    if (oldWidget.filePath != widget.filePath) {
      _controller?.dispose();
      _pinchController?.dispose();
      _controller = null;
      _pinchController = null;
      _error = null;
      _loading = true;
      _open();
    }
  }

  Future<void> _open() async {
    try {
      // Controller 期望 Future<PdfDocument>，直接传入 openFile 的 Future
      final documentFuture = PdfDocument.openFile(widget.filePath);
      // 只创建一次 controller；若在加载期间 widget 已 dispose，则不再更新 UI
      if (!mounted) return;
      if (Platform.isWindows) {
        _controller = PdfController(document: documentFuture);
      } else {
        _pinchController = PdfControllerPinch(document: documentFuture);
      }
      // 等待文档加载完成，加载失败时捕获错误
      await documentFuture;
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pinchController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('PDF 加载失败：$_error'));
    }
    if (Platform.isWindows) {
      return PdfView(
        controller: _controller!,
        scrollDirection: Axis.vertical,
      );
    }
    return PdfViewPinch(
      controller: _pinchController!,
      scrollDirection: Axis.vertical,
    );
  }
}

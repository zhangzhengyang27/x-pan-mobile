import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/file_vo.dart';
import '../services/preview_service.dart';

/// Office 文档预览页
///
/// 通过后端异步预览任务（office → pdf 转换）拿到预览直链，
/// 用 WebView 加载。
class OfficePreviewPage extends StatefulWidget {
  const OfficePreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  State<OfficePreviewPage> createState() => _OfficePreviewPageState();
}

class _OfficePreviewPageState extends State<OfficePreviewPage> {
  WebViewController? _controller;
  String? _error;
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // 1. 创建预览任务
      final task = await PreviewService.instance.office(widget.file.fileId);

      if (task.status == 3) {
        throw Exception(task.errorMsg.isEmpty ? '预览转换失败' : task.errorMsg);
      }

      if (task.status == 2 && task.previewUrl.isNotEmpty) {
        // 已完成，直接加载
        await _loadUrl(task.previewUrl);
        return;
      }

      // 2. 轮询直到完成
      _poll(task.taskId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _poll(String taskId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final task = await PreviewService.instance.url(taskId);
        if (task.status == 2 && task.previewUrl.isNotEmpty) {
          timer.cancel();
          await _loadUrl(task.previewUrl);
        } else if (task.status == 3) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _error = task.errorMsg.isEmpty ? '预览转换失败' : task.errorMsg;
              _loading = false;
            });
          }
        }
      } catch (e) {
        // 轮询失败不中断，继续尝试
      }
    });
  }

  Future<void> _loadUrl(String url) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
    if (mounted) {
      setState(() {
        _controller = controller;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('文档转换中，请稍候…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('预览失败：$_error', textAlign: TextAlign.center),
        ),
      );
    }
    return WebViewWidget(controller: _controller!);
  }
}

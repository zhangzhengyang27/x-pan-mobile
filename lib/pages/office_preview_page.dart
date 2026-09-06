import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/network/http_client.dart';
import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/preview_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/pdf_preview_view.dart';
import '../widgets/skeleton.dart';

/// Office 文档预览页
///
/// 通过后端异步预览任务（office → pdf 转换）拿到预览直链。
/// - 移动端：用 WebView 加载直链。
/// - 桌面端（macOS/Windows）：webview_flutter 不支持，改为下载 PDF 直链后用
///    [PdfPreviewView]（pdfx）渲染，复用 PDF 渲染链路。
class OfficePreviewPage extends StatefulWidget {
  const OfficePreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  State<OfficePreviewPage> createState() => _OfficePreviewPageState();
}

class _OfficePreviewPageState extends State<OfficePreviewPage> {
  WebViewController? _controller;
  String? _localPdfPath;
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
    // 轮询上限（约 120 次）：超时停止并提示，避免转换任务异常时无限轮询
    const maxPollAttempts = 120;
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (attempts >= maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _error = '文档转换超时，请稍后重试';
            _loading = false;
          });
        }
        return;
      }
      attempts++;
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
      } catch (_) {
        // 轮询失败不中断，继续尝试
      }
    });
  }

  Future<void> _loadUrl(String url) async {
    if (Platform.isWindows || Platform.isMacOS) {
      // 桌面端：下载 PDF 直链后用 pdfx 渲染
      try {
        final dir = await getTemporaryDirectory();
        final savePath =
            '${dir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await HttpClient.instance.dio.download(url, savePath);
        if (mounted) {
          setState(() {
            _localPdfPath = savePath;
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
      return;
    }

    // 移动端：WebView 加载
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
    // 清理桌面端临时下载的预览 PDF
    final path = _localPdfPath;
    if (path != null) {
      try {
        File(path).delete();
      } catch (_) {
        // 忽略清理失败
      }
    }
    super.dispose();
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
      return const _OfficeSkeleton();
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '预览失败',
        subtitle: _error,
      );
    }
    // 桌面端：pdfx 渲染 PDF 直链
    if (_localPdfPath != null) {
      return PdfPreviewView(filePath: _localPdfPath!);
    }
    // 移动端：WebView
    return WebViewWidget(controller: _controller!);
  }
}

/// Office 转换中骨架屏
class _OfficeSkeleton extends StatelessWidget {
  const _OfficeSkeleton();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const widths = <double>[0.7, 0.95, 0.88, 0.92, 0.6, 0.9, 0.82];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in widths) ...[
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: w,
                child: const SkeletonBox(height: 12),
              ),
              const SizedBox(height: AppTokens.space12),
            ],
            const SizedBox(height: AppTokens.space24),
            Center(
              child: Text(
                '文档转换中，请稍候…',
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

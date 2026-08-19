import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/download_service.dart';
import '../services/user_service.dart';
import '../widgets/skeleton.dart';

/// 视频预览页
class VideoPreviewPage extends StatefulWidget {
  const VideoPreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // 沉浸式：隐藏状态栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    // Windows 暂不支持 video_player，走「下载后用系统播放器」降级
    if (Platform.isWindows) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final url =
          await FileService.instance.resolvePreviewUrl(widget.file.fileId);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      final scheme = Theme.of(context).colorScheme;
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: scheme.primary,
          handleColor: scheme.primary,
          bufferedColor: scheme.primary.withValues(alpha: 0.3),
          backgroundColor: Colors.white24,
        ),
      );
      setState(() {
        _controller = controller;
        _chewieController = chewie;
        _loading = false;
      });
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
  void dispose() {
    _chewieController?.dispose();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.file.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTokens.titleLarge.copyWith(color: Colors.white),
        ),
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      // 加载骨架：视频画幅比例占位
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SkeletonBox(
            width: 240,
            height: 135,
            borderRadius: AppTokens.radiusMd,
          ),
          const SizedBox(height: AppTokens.space16),
          Text(
            '视频加载中…',
            style: AppTokens.bodyMedium.copyWith(color: Colors.white54),
          ),
        ],
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 56),
            const SizedBox(height: AppTokens.space16),
            Text(
              '播放失败：$_error',
              textAlign: TextAlign.center,
              style: AppTokens.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    // Windows：暂不支持内嵌播放，引导下载后用系统播放器
    if (Platform.isWindows) {
      return _buildWindowsFallback();
    }
    return Chewie(controller: _chewieController!);
  }

  Widget _buildWindowsFallback() {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white54, size: 64),
          const SizedBox(height: AppTokens.space16),
          Text(
            'Windows 暂不支持内嵌视频播放',
            style: AppTokens.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppTokens.space24),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('下载并用系统播放器打开'),
            onPressed: () async {
              try {
                await DownloadService.instance.downloadAndOpen(
                  fileId: widget.file.fileId,
                  filename: widget.file.filename,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('下载失败：$e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

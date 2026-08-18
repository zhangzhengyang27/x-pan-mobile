import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/file_vo.dart';
import '../services/download_service.dart';
import '../services/user_service.dart';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.file.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(
              '播放失败：$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Windows 暂不支持内嵌视频播放',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
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

import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/download_service.dart';
import '../services/preview_service.dart';
import '../core/network/http_client.dart';
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
  bool _subtitleLoading = false;
  bool _subtitleOn = false;
  List<_SubtitleCue> _cues = const [];
  String _currentCue = '';

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
      controller.addListener(_onTick);
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

  /// 切换到 HLS：手动触发转码后轮询任务，完成后用带鉴权头的 master 清单重建播放器。
  /// 360p/720p 由后端清单自适应，播放器只认一个 master URL。
  Future<void> _switchToHls() async {
    final oldChewie = _chewieController;
    final oldController = _controller;
    setState(() => _loading = true);
    try {
      var task = await PreviewService.instance.hls(widget.file.fileId);
      final hlsTaskId = task.taskId;
      for (var i = 0; i < 90 && task.status != 2; i++) {
        if (task.status == 3) throw Exception(task.errorMsg.isEmpty ? '转码失败' : task.errorMsg);
        await Future.delayed(const Duration(seconds: 2));
        task = await PreviewService.instance.url(hlsTaskId);
      }
      if (task.status != 2 || task.previewUrl.isEmpty) {
        throw Exception('转码超时，请稍后在任务中心查看');
      }
      final raw = task.previewUrl;
      final url = raw.startsWith('http') ? raw : '${AppConfig.apiBaseUrl}$raw';
      final headers = <String, String>{
        'Authorization': await TokenStorage.getToken(),
        'X-Client-Id': await TokenStorage.getClientId(),
      };
      final spaceId = await TokenStorage.getSpaceId();
      if (spaceId.isNotEmpty) headers['X-Space-Id'] = spaceId;
      final controller = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
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
      oldController?.removeListener(_onTick);
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _chewieController = chewie;
        _loading = false;
      });
      oldChewie?.dispose();
      oldController?.dispose();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// 字幕开关：首次开启时拉取 VTT；失败静默提示，避免无字幕视频打扰播放
  Future<void> _toggleSubtitle() async {
    if (_subtitleOn) {
      setState(() {
        _subtitleOn = false;
        _currentCue = '';
      });
      return;
    }
    if (_cues.isEmpty) {
      setState(() => _subtitleLoading = true);
      try {
        final response = await HttpClient.instance.dio.get<String>(
          '/preview/subtitle/${Uri.encodeComponent(widget.file.fileId)}',
          options: Options(responseType: ResponseType.plain),
        );
        final cues = _parseVtt(response.data ?? '');
        if (!mounted) return;
        setState(() {
          _cues = cues;
          _subtitleOn = cues.isNotEmpty;
          _subtitleLoading = false;
        });
        if (cues.isEmpty) _toast('该视频没有旁挂字幕');
      } catch (_) {
        if (!mounted) return;
        setState(() => _subtitleLoading = false);
        _toast('该视频没有旁挂字幕');
      }
      return;
    }
    setState(() => _subtitleOn = true);
  }

  void _onTick() {
    if (!_subtitleOn || _cues.isEmpty || !mounted) return;
    final pos = _controller?.value.position;
    if (pos == null) return;
    final text = _cues
        .where((cue) => pos >= cue.start && pos <= cue.end)
        .map((cue) => cue.text)
        .join('\n');
    if (text != _currentCue) setState(() => _currentCue = text);
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
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
        actions: [
          IconButton(
            onPressed: _loading ? null : _switchToHls,
            icon: const Icon(Icons.high_quality_outlined),
            tooltip: '高清播放（HLS）',
          ),
          IconButton(
            onPressed: _subtitleLoading ? null : _toggleSubtitle,
            icon: Icon(_subtitleOn ? Icons.subtitles : Icons.subtitles_off_outlined),
            tooltip: '字幕',
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(child: _buildBody()),
          if (_subtitleOn && _currentCue.isNotEmpty)
            Positioned(
              left: 24,
              right: 24,
              bottom: 96,
              child: IgnorePointer(
                child: Text(
                  _currentCue,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
              ),
            ),
        ],
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


class _SubtitleCue {
  const _SubtitleCue(this.start, this.end, this.text);

  final Duration start;
  final Duration end;
  final String text;
}

/// 解析 WebVTT：后端已把 SRT 统一转为 VTT，这里只需处理 `-->` 与块文本。
List<_SubtitleCue> _parseVtt(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final blocks = normalized.split(RegExp(r'\n\n+'));
  final cues = <_SubtitleCue>[];
  for (final block in blocks) {
    final lines = block.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) continue;
    final timingIndex = lines.indexWhere((line) => line.contains('-->'));
    if (timingIndex < 0) continue;
    final parts = lines[timingIndex].split('-->');
    final start = _parseTimestamp(parts[0].trim().split(' ').first);
    final end = _parseTimestamp(parts[1].trim().split(' ').first);
    if (start == null || end == null || end <= start) continue;
    final text = lines.skip(timingIndex + 1).join('\n').replaceAll(RegExp(r'<[^>]+>'), '').trim();
    if (text.isNotEmpty) cues.add(_SubtitleCue(start, end, text));
  }
  return cues;
}

Duration? _parseTimestamp(String value) {
  final match = RegExp(r'^(?:(\d+):)?(\d{2}):(\d{2})[.,](\d{3})$').firstMatch(value);
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
  final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
  final millis = int.tryParse(match.group(4) ?? '0') ?? 0;
  return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
}

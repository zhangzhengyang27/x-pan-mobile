import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/file_vo.dart';
import '../services/download_service.dart';
import '../services/user_service.dart';

/// 音频预览页
class AudioPreviewPage extends StatefulWidget {
  const AudioPreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  State<AudioPreviewPage> createState() => _AudioPreviewPageState();
}

class _AudioPreviewPageState extends State<AudioPreviewPage> {
  final AudioPlayer _player = AudioPlayer();
  String? _error;
  bool _loading = true;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Windows 暂不支持 just_audio，走「下载后用系统播放器」降级
    if (Platform.isWindows) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final url =
          await FileService.instance.resolvePreviewUrl(widget.file.fileId);
      await _player.setUrl(url);
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _playing = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _playing = false;
            }
          });
        }
      });
      if (mounted) setState(() => _loading = false);
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
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Platform.isWindows
                ? _buildWindowsFallback()
                : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('加载失败：$_error', textAlign: TextAlign.center),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.music_note, size: 64, color: scheme.primary),
                      ),
                      const SizedBox(height: 24),
                      // 进度条
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (ctx, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = _player.duration ?? Duration.zero;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                Slider(
                                  value: duration.inMilliseconds == 0
                                      ? 0
                                      : (position.inMilliseconds /
                                              duration.inMilliseconds)
                                          .clamp(0.0, 1.0),
                                  onChanged: (v) {
                                    final target = Duration(
                                      milliseconds:
                                          (duration.inMilliseconds * v).round(),
                                    );
                                    _player.seek(target);
                                  },
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_format(position)),
                                    Text(_format(duration)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      IconButton(
                        iconSize: 64,
                        icon: Icon(
                          _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        ),
                        color: scheme.primary,
                        onPressed: () {
                          if (_playing) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                      ),
                    ],
                  ),
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildWindowsFallback() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.music_note, size: 64, color: scheme.primary.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        const Text('Windows 暂不支持内嵌音频播放'),
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
    );
  }
}

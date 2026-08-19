import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/download_service.dart';
import '../services/user_service.dart';
import '../widgets/skeleton.dart';

/// 音频预览页
///
/// 品牌渐变背景 + 唱片式封面旋转动画 + 渐变进度条 + 品牌光晕播放按钮。
class AudioPreviewPage extends StatefulWidget {
  const AudioPreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  State<AudioPreviewPage> createState() => _AudioPreviewPageState();
}

class _AudioPreviewPageState extends State<AudioPreviewPage>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  String? _error;
  bool _loading = true;
  bool _playing = false;

  late final AnimationController _discCtrl;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _discCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
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
      _stateSub = _player.playerStateStream.listen((state) {
        if (!mounted) return;
        // 播放时唱片旋转，暂停时停在当前位置
        if (state.playing) {
          _discCtrl.repeat();
        } else {
          _discCtrl.stop();
        }
        setState(() {
          _playing = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playing = false;
          }
        });
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
    _stateSub?.cancel();
    _discCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppTokens.brandGradient),
        child: SafeArea(
          child: Center(
            child: _loading
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonBox(width: 200, height: 200, borderRadius: 999),
                      SizedBox(height: AppTokens.space24),
                      SkeletonBox(width: 160, height: 14),
                    ],
                  )
                : Platform.isWindows
                    ? _buildWindowsFallback()
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(AppTokens.space24),
                            child: Text(
                              '加载失败：$_error',
                              textAlign: TextAlign.center,
                              style: AppTokens.bodyMedium.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          )
                        : _buildPlayer(brightness),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.space32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 唱片式封面（播放时旋转）
          RotationTransition(
            turns: _discCtrl,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.25),
                border: Border.all(color: Colors.white24, width: 8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.music_note,
                size: 72,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space40),
          // 进度条（dataGradient）
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (ctx, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _player.duration ?? Duration.zero;
              final ratio = duration.inMilliseconds == 0
                  ? 0.0
                  : (position.inMilliseconds / duration.inMilliseconds)
                      .clamp(0.0, 1.0);
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.15),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      value: ratio,
                      onChanged: (v) {
                        final target = Duration(
                          milliseconds:
                              (duration.inMilliseconds * v).round(),
                        );
                        _player.seek(target);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _format(position),
                          style: AppTokens.labelSmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          _format(duration),
                          style: AppTokens.labelSmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppTokens.space24),
          // 播放/暂停按钮（圆形 + 品牌光晕）
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: AppTokens.shadowBrand(brightness),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                onTap: () {
                  if (_playing) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
                },
                child: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  size: 40,
                  color: AppTokens.brandPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildWindowsFallback() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.music_note,
          size: 64,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        const SizedBox(height: AppTokens.space16),
        Text(
          'Windows 暂不支持内嵌音频播放',
          style: AppTokens.bodyMedium.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: AppTokens.space24),
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('下载并用系统播放器打开'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTokens.brandPrimary,
          ),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../utils/file_open.dart';

/// 视频分类视图：海报卡片网格 + 播放按钮（参考前端 VideoViewer）
class VideoCategoryView extends StatelessWidget {
  const VideoCategoryView({super.key, required this.files});

  final List<FileVO> files;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppTokens.space16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppTokens.space12,
        crossAxisSpacing: AppTokens.space12,
        childAspectRatio: 0.72,
      ),
      itemCount: files.length,
      itemBuilder: (ctx, i) => _VideoCard(
        file: files[i],
        onTap: () => openFileByType(context, files[i]),
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({required this.file, required this.onTap});
  final FileVO file;
  final VoidCallback onTap;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await resolveCoverUrl(widget.file, width: 480, height: 270);
    if (mounted) setState(() => _url = url);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  child: Container(
                    color: Colors.black,
                    child: _url == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: _url!,
                            fit: BoxFit.cover,
                            placeholder: (c, url) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            ),
                            errorWidget: (c, url, e) => const Center(
                              child: Icon(
                                Icons.videocam_off_outlined,
                                color: Colors.white54,
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 44,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            widget.file.filename,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.labelSmall.copyWith(
              color: AppTokens.textPrimary(brightness),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.file.fileSizeDesc ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.labelSmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../pages/image_preview_page.dart';
import '../../utils/file_open.dart';

/// 图片分类视图：按时间轴分组 + 方形缩略图网格（参考前端 ImageTimeline）
class ImageCategoryView extends StatelessWidget {
  const ImageCategoryView({super.key, required this.files});

  final List<FileVO> files;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final groups = groupByTimeline(files);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      itemCount: groups.length,
      itemBuilder: (ctx, gi) {
        final (label, files) = groups[gi];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space16,
                AppTokens.space16,
                AppTokens.space8,
              ),
              child: Text(
                label,
                style: AppTokens.labelSmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppTokens.space8,
                crossAxisSpacing: AppTokens.space8,
                childAspectRatio: 1,
              ),
              itemCount: files.length,
              itemBuilder: (c, i) {
                final file = files[i];
                return _ImageThumb(
                  file: file,
                  onTap: () {
                    final images = files;
                    final index =
                        images.indexWhere((f) => f.fileId == file.fileId);
                    Navigator.of(context).push(
                      AppTokens.route(
                        ImagePreviewPage(
                          files: images,
                          initialIndex: index < 0 ? 0 : index,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ImageThumb extends StatefulWidget {
  const _ImageThumb({required this.file, required this.onTap});
  final FileVO file;
  final VoidCallback onTap;

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await resolveCoverUrl(widget.file, width: 320, height: 320);
    if (mounted) setState(() => _url = url);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          color: AppTokens.surfaceElevated(Theme.of(context).brightness),
          child: _url == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : CachedNetworkImage(
                imageUrl: _url!,
                fit: BoxFit.cover,
                placeholder: (c, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (c, url, e) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 28),
                ),
              ),
        ),
      ),
    );
  }
}

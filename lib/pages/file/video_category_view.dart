import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../utils/file_open.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_timeline_view.dart';

/// 视频分类视图：海报网格 / 时间线 双视图切换。
///
/// - 网格：2 列海报卡片（默认）。
/// - 时间线：按 年/月/日 分组，每行一张海报 + 标题（对齐前端分类时间线）。
class VideoCategoryView extends StatefulWidget {
  const VideoCategoryView({super.key, required this.files});

  final List<FileVO> files;

  @override
  State<VideoCategoryView> createState() => _VideoCategoryViewState();
}

class _VideoCategoryViewState extends State<VideoCategoryView> {
  bool _timeline = false;

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return const EmptyState(icon: Icons.videocam_off_outlined, title: '暂无视频');
    }
    return Column(
      children: [
        _ViewSwitch(
          timeline: _timeline,
          onChanged: (v) => setState(() => _timeline = v),
        ),
        Expanded(
          child: _timeline
              ? FileTimelineView(
                  files: widget.files,
                  initialMode: TimelineMode.month,
                  emptyIcon: Icons.videocam_off_outlined,
                  emptyTitle: '暂无视频',
                  itemBuilder: (file) => _VideoRow(
                    file: file,
                    onTap: () => openFileByType(context, file),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppTokens.space12,
                    crossAxisSpacing: AppTokens.space12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: widget.files.length,
                  itemBuilder: (ctx, i) => _VideoCard(
                    file: widget.files[i],
                    onTap: () => openFileByType(ctx, widget.files[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 网格 ⇄ 时间线 切换条
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.timeline, required this.onChanged});
  final bool timeline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final activeColor = brightness == Brightness.dark
        ? AppTokens.brandPrimaryDark
        : AppTokens.brandPrimary;
    final items = [
      (false, Icons.grid_view_outlined, '网格'),
      (true, Icons.view_timeline_outlined, '时间线'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space8,
      ),
      color: AppTokens.surface(brightness),
      child: Row(
        children: [
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: AppTokens.background(brightness),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                for (final (isTimeline, icon, label) in items)
                  GestureDetector(
                    onTap: () => onChanged(isTimeline),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.space12,
                        vertical: AppTokens.space4,
                      ),
                      decoration: BoxDecoration(
                        color: timeline == isTimeline
                            ? AppTokens.surface(brightness)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm - 2),
                        boxShadow: timeline == isTimeline
                            ? AppTokens.shadowSm(brightness)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: timeline == isTimeline
                                ? activeColor
                                : AppTokens.textSecondary(brightness),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: AppTokens.labelSmall.copyWith(
                              color: timeline == isTimeline
                                  ? activeColor
                                  : AppTokens.textSecondary(brightness),
                              fontWeight: timeline == isTimeline
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 时间线单行：海报缩略图 + 标题 + 大小
class _VideoRow extends StatelessWidget {
  const _VideoRow({required this.file, required this.onTap});
  final FileVO file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ListTile(
      leading: _VideoThumb(file: file),
      title: Text(
        file.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTokens.bodyMedium.copyWith(
          color: AppTokens.textPrimary(brightness),
        ),
      ),
      subtitle: Text(
        file.fileSizeDesc ?? '',
        style: AppTokens.bodySmall.copyWith(
          color: AppTokens.textSecondary(brightness),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.file});
  final FileVO file;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await resolveCoverUrl(widget.file, width: 120, height: 68);
    if (mounted) setState(() => _url = url);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 34,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
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
                          size: 18,
                        ),
                      ),
                    ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 18,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

/// 网格卡片：海报 + 播放按钮
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

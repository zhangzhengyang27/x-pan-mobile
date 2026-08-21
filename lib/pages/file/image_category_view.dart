import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../utils/file_open.dart';
import '../../widgets/empty_state.dart';

/// 图片分类视图：网格 / 时间线 双视图切换。
///
/// - 网格：缩略图方阵（默认），点击大图预览。
/// - 时间线：按 年/月/日 分组（对齐前端 ImageTimeline），缩略图瓦片流。
class ImageCategoryView extends StatefulWidget {
  const ImageCategoryView({super.key, required this.files});

  final List<FileVO> files;

  @override
  State<ImageCategoryView> createState() => _ImageCategoryViewState();
}

class _ImageCategoryViewState extends State<ImageCategoryView> {
  bool _timeline = false;

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return const EmptyState(icon: Icons.image_outlined, title: '暂无图片');
    }
    return Column(
      children: [
        _ViewSwitch(
          timeline: _timeline,
          onChanged: (v) => setState(() => _timeline = v),
        ),
        Expanded(
          child: _timeline
              ? _ImageTimeline(files: widget.files)
              : _ImageGrid(files: widget.files),
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

/// 图片网格视图
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.files});
  final List<FileVO> files;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppTokens.space16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppTokens.space8,
        crossAxisSpacing: AppTokens.space8,
        childAspectRatio: 1,
      ),
      itemCount: files.length,
      itemBuilder: (ctx, i) => _ImageTile(
        file: files[i],
        onTap: () => openFileByType(ctx, files[i], images: files),
      ),
    );
  }
}

/// 图片时间线视图：分组标题 + 缩略图瓦片流（Wrap，对齐前端 ImageTimeline）
class _ImageTimeline extends StatefulWidget {
  const _ImageTimeline({required this.files});
  final List<FileVO> files;

  @override
  State<_ImageTimeline> createState() => _ImageTimelineState();
}

class _ImageTimelineState extends State<_ImageTimeline> {
  TimelineMode _mode = TimelineMode.day;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final groups = groupByTimeline(widget.files, _mode);
    // 用 LayoutBuilder 按父容器实际宽度计算瓦片尺寸，横屏/分屏下也能自适应，
    // 避免依赖 MediaQuery.size.width 导致瓦片溢出或错乱。
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final tileWidth = (constraints.maxWidth -
                AppTokens.space16 * 2 -
                AppTokens.space8 * 2) /
            3;
        return Column(
          children: [
            _GranularitySwitch(
              mode: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
                itemCount: groups.length,
                itemBuilder: (ctx, gi) {
                  final g = groups[gi];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTokens.space16,
                          AppTokens.space16,
                          AppTokens.space16,
                          AppTokens.space4,
                        ),
                        child: Text(
                          g.label,
                          style: AppTokens.labelSmall.copyWith(
                            color: AppTokens.textSecondary(brightness),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space16,
                        ),
                        child: Wrap(
                          spacing: AppTokens.space8,
                          runSpacing: AppTokens.space8,
                          children: [
                            for (final file in g.files)
                              SizedBox(
                                width: tileWidth,
                                height: tileWidth,
                                child: _ImageTile(
                                  file: file,
                                  onTap: () => openFileByType(
                                    context,
                                    file,
                                    images: widget.files,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 时间线粒度切换（年/月/日）
class _GranularitySwitch extends StatelessWidget {
  const _GranularitySwitch({required this.mode, required this.onChanged});
  final TimelineMode mode;
  final ValueChanged<TimelineMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const items = [
      (TimelineMode.year, '年'),
      (TimelineMode.month, '月'),
      (TimelineMode.day, '日'),
    ];
    final activeColor = brightness == Brightness.dark
        ? AppTokens.brandPrimaryDark
        : AppTokens.brandPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space8,
      ),
      color: AppTokens.surface(brightness),
      child: Row(
        children: [
          Text(
            '时间线',
            style: AppTokens.labelSmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: AppTokens.background(brightness),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                for (final (m, label) in items)
                  GestureDetector(
                    onTap: () => onChanged(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.space12,
                        vertical: AppTokens.space4,
                      ),
                      decoration: BoxDecoration(
                        color: mode == m
                            ? AppTokens.surface(brightness)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm - 2),
                        boxShadow: mode == m ? AppTokens.shadowSm(brightness) : null,
                      ),
                      child: Text(
                        label,
                        style: AppTokens.labelSmall.copyWith(
                          color: mode == m
                              ? activeColor
                              : AppTokens.textSecondary(brightness),
                          fontWeight:
                              mode == m ? FontWeight.w600 : FontWeight.w500,
                        ),
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

/// 单张图片缩略图瓦片
class _ImageTile extends StatefulWidget {
  const _ImageTile({required this.file, required this.onTap});
  final FileVO file;
  final VoidCallback onTap;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
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
          color: AppTokens.surface(Theme.of(context).brightness),
          child: _url == null
              ? Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTokens.textSecondary(Theme.of(context).brightness),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: _url!,
                  fit: BoxFit.cover,
                  placeholder: (c, url) => Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTokens.textSecondary(Theme.of(context).brightness),
                    ),
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

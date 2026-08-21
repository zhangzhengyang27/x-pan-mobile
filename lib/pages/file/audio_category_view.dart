import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../utils/file_open.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_timeline_view.dart';

/// 音频分类视图：歌曲列表 / 时间线 双视图切换（参考前端 MusicViewer）。
///
/// - 列表：全部歌曲逐行展示（默认）。
/// - 时间线：按 年/月/日 分组，行内仍是歌曲信息。
class AudioCategoryView extends StatefulWidget {
  const AudioCategoryView({super.key, required this.files});

  final List<FileVO> files;

  @override
  State<AudioCategoryView> createState() => _AudioCategoryViewState();
}

class _AudioCategoryViewState extends State<AudioCategoryView> {
  bool _timeline = false;

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return const EmptyState(icon: Icons.audiotrack_outlined, title: '暂无音频');
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
                  emptyIcon: Icons.audiotrack_outlined,
                  emptyTitle: '暂无音频',
                  itemBuilder: (file) => _AudioRow(file: file),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
                  itemCount: widget.files.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: AppTokens.space16 + 56,
                    color: AppTokens.divider(Theme.of(context).brightness),
                  ),
                  itemBuilder: (ctx, i) => _AudioRow(file: widget.files[i]),
                ),
        ),
      ],
    );
  }
}

/// 列表 ⇄ 时间线 切换条
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
      (false, Icons.list_alt_outlined, '列表'),
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

/// 单行歌曲：封面 + 标题 + 大小 + 播放
class _AudioRow extends StatelessWidget {
  const _AudioRow({required this.file});
  final FileVO file;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final brand = brightness == Brightness.dark
        ? AppTokens.brandPrimaryDark
        : AppTokens.brandPrimary;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: brand.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        child: Icon(Icons.music_note, color: brand),
      ),
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
      trailing: Icon(Icons.play_circle_outline, color: brand),
      onTap: () => openFileByType(context, file),
    );
  }
}

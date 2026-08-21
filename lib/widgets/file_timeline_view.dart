import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../utils/file_open.dart';

/// 通用时间线视图（对齐前端 ImageTimeline 的「年/月/日」分组）。
///
/// 只负责：空态、分组标题、年/月/日粒度切换、组内布局；
/// 每个文件具体怎么渲染（缩略图瓦片 / 列表行）由 [itemBuilder] 决定，
/// 以便图片、视频、音频、文档等分类页复用同一套时间线结构。
class FileTimelineView extends StatefulWidget {
  const FileTimelineView({
    super.key,
    required this.files,
    required this.itemBuilder,
    this.initialMode = TimelineMode.day,
    this.showGranularitySwitch = true,
    this.emptyIcon = Icons.folder_open_outlined,
    this.emptyTitle = '暂无文件',
  });

  final List<FileVO> files;
  final Widget Function(FileVO file) itemBuilder;
  final TimelineMode initialMode;
  final bool showGranularitySwitch;
  final IconData emptyIcon;
  final String emptyTitle;

  @override
  State<FileTimelineView> createState() => _FileTimelineViewState();
}

class _FileTimelineViewState extends State<FileTimelineView> {
  late TimelineMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (widget.files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.emptyIcon,
              size: 48,
              color: AppTokens.textSecondary(brightness),
            ),
            const SizedBox(height: AppTokens.space12),
            Text(
              widget.emptyTitle,
              style: AppTokens.bodyMedium.copyWith(
                color: AppTokens.textSecondary(brightness),
              ),
            ),
          ],
        ),
      );
    }

    final groups = groupByTimeline(widget.files, _mode);

    return Column(
      children: [
        if (widget.showGranularitySwitch)
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
                  for (final file in g.files)
                    widget.itemBuilder(file),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 年 / 月 / 日 粒度切换（夸克式 segmented）
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
    final activeColor =
        brightness == Brightness.dark ? AppTokens.brandPrimaryDark : AppTokens.brandPrimary;
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

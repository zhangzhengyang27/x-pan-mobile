import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../providers/file_provider.dart';
import '../providers/view_mode_provider.dart';

/// 排序变更后刷新文件列表（load 内部会重置到第 1 页；
/// 列表未初始化时 currentFolderId 为 null，load 会安全跳过）
void _reloadFileList(WidgetRef ref) {
  ref.read(fileListProvider.notifier).refresh();
}

/// 文件视图切换底部弹窗
///
/// 提供：列表/网格视图切换、排序字段、排序方向、按时间分组。
/// 对齐阿里云盘的「更多」弹窗交互。
class ViewOptionsSheet extends ConsumerWidget {
  const ViewOptionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(fileViewModeProvider);
    final notifier = ref.read(fileViewModeProvider.notifier);
    final brightness = Theme.of(context).brightness;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.only(
                top: AppTokens.space8,
                bottom: AppTokens.space12,
              ),
              child: Text(
                '视图与排序',
                style: AppTokens.titleMedium.copyWith(
                  color: AppTokens.textPrimary(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 视图模式：列表 / 网格
            Row(
              children: [
                Expanded(
                  child: _OptionTile(
                    selected: mode.viewMode == FileViewMode.list,
                    icon: Icons.list_outlined,
                    label: '列表视图',
                    onTap: () => notifier.setViewMode(FileViewMode.list),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: _OptionTile(
                    selected: mode.viewMode == FileViewMode.grid,
                    icon: Icons.grid_view_outlined,
                    label: '图标视图',
                    onTap: () => notifier.setViewMode(FileViewMode.grid),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTokens.space16),

            // 排序字段
            Text(
              '排序方式',
              style: AppTokens.labelSmall.copyWith(
                color: AppTokens.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            Wrap(
              spacing: AppTokens.space8,
              children: [
                _Chip(
                  label: '名称',
                  selected: mode.sortField == FileSortField.name,
                  onTap: () {
                    notifier.setSort(FileSortField.name, mode.sortOrder);
                    _reloadFileList(ref);
                  },
                ),
                _Chip(
                  label: '创建时间',
                  selected: mode.sortField == FileSortField.createTime,
                  onTap: () {
                    notifier.setSort(FileSortField.createTime, mode.sortOrder);
                    _reloadFileList(ref);
                  },
                ),
                _Chip(
                  label: '修改时间',
                  selected: mode.sortField == FileSortField.updateTime,
                  onTap: () {
                    notifier.setSort(FileSortField.updateTime, mode.sortOrder);
                    _reloadFileList(ref);
                  },
                ),
                _Chip(
                  label: '文件大小',
                  selected: mode.sortField == FileSortField.size,
                  onTap: () {
                    notifier.setSort(FileSortField.size, mode.sortOrder);
                    _reloadFileList(ref);
                  },
                ),
              ],
            ),

            const SizedBox(height: AppTokens.space12),

            // 排序方向 + 按时间分组
            Row(
              children: [
                _Chip(
                  label: mode.sortOrder == FileSortOrder.asc
                      ? '升序 ↑'
                      : '降序 ↓',
                  selected: false,
                  onTap: () {
                    notifier.toggleSortOrder();
                    _reloadFileList(ref);
                  },
                ),
                const SizedBox(width: AppTokens.space8),
                _Chip(
                  label: '按时间分组',
                  selected: mode.groupByTime,
                  onTap: () => notifier.setGroupByTime(!mode.groupByTime),
                ),
              ],
            ),

            const SizedBox(height: AppTokens.space16),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.space16,
          horizontal: AppTokens.space12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          color: selected
              ? AppTokens.brandPrimary.withValues(alpha: 0.12)
              : AppTokens.surfaceElevated(brightness),
          border: Border.all(
            color: selected
                ? AppTokens.brandPrimary
                : AppTokens.divider(brightness),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? AppTokens.brandPrimary
                  : AppTokens.textSecondary(brightness),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              label,
              style: AppTokens.bodyMedium.copyWith(
                color: selected
                    ? AppTokens.brandPrimary
                    : AppTokens.textPrimary(brightness),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.space8,
          horizontal: AppTokens.space16,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          color: selected
              ? AppTokens.brandPrimary
              : AppTokens.surfaceElevated(brightness),
          border: Border.all(
            color: selected
                ? AppTokens.brandPrimary
                : AppTokens.divider(brightness),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTokens.labelSmall.copyWith(
            color: selected
                ? Colors.white
                : AppTokens.textPrimary(brightness),
          ),
        ),
      ),
    );
  }
}

/// 便捷方法：弹出视图选项弹窗
void showViewOptionsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusXl),
      ),
    ),
    builder: (_) => const ViewOptionsSheet(),
  );
}

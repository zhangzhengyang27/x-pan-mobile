import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 桌面端侧边导航栏（NavigationRail）
///
/// 外层用 SingleChildScrollView 包裹，避免低高度窗口下导航项溢出。
/// 索引 0 为「我的网盘」（当前页，不触发跳转）。
class HomeDesktopRail extends StatelessWidget {
  const HomeDesktopRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.all,
        leading: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: CircleAvatar(
            radius: 20,
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: Text('我的网盘'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.history),
            label: Text('最近访问'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: Text('收藏'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.share_outlined),
            label: Text('分享'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.cloud_download_outlined),
            label: Text('离线'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.upload_file_outlined),
            label: Text('上传任务'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.delete_outline),
            label: Text('回收站'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.security),
            label: Text('保险箱'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.auto_awesome),
            label: Text('AI'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: Text('统计'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.notifications_outlined),
            label: Text('通知'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            label: Text('设置'),
          ),
        ],
      ),
    );
  }
}

/// 文件夹路径面包屑条
///
/// 层级 <= 1 时返回空占位；点击非末级可跳转到对应层级。
class HomeBreadcrumbs extends StatelessWidget {
  const HomeBreadcrumbs({
    super.key,
    required this.names,
    required this.onJump,
  });

  /// 从根目录到当前目录的路径名列表
  final List<String> names;

  /// 点击第 i 级（非末级）时回调
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    if (names.length <= 1) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTokens.divider(brightness), width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,
        separatorBuilder: (_, __) => Icon(
          Icons.chevron_right,
          size: 16,
          color: AppTokens.textTertiary(brightness),
        ),
        itemBuilder: (ctx, i) {
          final isLast = i == names.length - 1;
          return Center(
            child: GestureDetector(
              onTap: isLast ? null : () => onJump(i),
              child: Text(
                names[i],
                style: AppTokens.bodyMedium.copyWith(
                  color: isLast
                      ? AppTokens.brandPrimary
                      : AppTokens.textSecondary(brightness),
                  fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 多选模式 AppBar
///
/// 品牌色浅底 + 已选数量标题 + 批量操作（删除/移动/复制/分享）。
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.onExit,
    required this.onDelete,
    required this.onMove,
    required this.onCopy,
    required this.onShare,
  });

  final int selectedCount;
  final VoidCallback onExit;
  final VoidCallback onDelete;
  final VoidCallback onMove;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTokens.brandPrimary.withValues(alpha: 0.08),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onExit,
      ),
      title: Text('已选 $selectedCount 项'),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '批量删除',
          onPressed: onDelete,
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_outline),
          tooltip: '批量移动',
          onPressed: onMove,
        ),
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: '批量复制',
          onPressed: onCopy,
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          tooltip: '批量分享',
          onPressed: onShare,
        ),
      ],
    );
  }
}

/// 下载/上传进度底部条（bottomSheet 用）
class UploadProgressBar extends StatelessWidget {
  const UploadProgressBar({
    super.key,
    required this.name,
    required this.progress,
  });

  final String name;

  /// 进度 0.0 ~ 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      decoration: BoxDecoration(
        color: AppTokens.surface(brightness),
        boxShadow: AppTokens.shadowMd(brightness),
        border: Border(
          top: BorderSide(color: AppTokens.divider(brightness), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.bodyMedium.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: AppTokens.labelLarge.copyWith(
                  color: AppTokens.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

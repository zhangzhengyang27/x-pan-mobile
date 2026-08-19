import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/app_list_item.dart';

/// 首页抽屉导航项定义（图标 + 标题 + 点击回调）
class HomeNavItem {
  const HomeNavItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

/// 移动端抽屉导航列表
///
/// 顶部品牌渐变头部（头像 / 用户名 / 容量进度条）+ 分组导航项。
/// 外层需自行包裹 Drawer/SafeArea，本组件只负责列表内容。
class HomeDrawerNav extends StatelessWidget {
  const HomeDrawerNav({
    super.key,
    required this.username,
    required this.usedSize,
    required this.totalSize,
    required this.fileItems,
    required this.toolItems,
    required this.accountItems,
  });

  final String username;
  final double usedSize;
  final double totalSize;

  /// 「文件」分组导航项
  final List<HomeNavItem> fileItems;

  /// 「工具」分组导航项
  final List<HomeNavItem> toolItems;

  /// 「账号」分组导航项
  final List<HomeNavItem> accountItems;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ratio =
        totalSize > 0 ? (usedSize / totalSize).clamp(0.0, 1.0) : 0.0;

    // 用 ListView 包裹，避免小屏高度不足时 Column 溢出
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 品牌渐变头部
        Container(
          decoration: const BoxDecoration(gradient: AppTokens.brandGradient),
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space20,
            AppTokens.space32,
            AppTokens.space20,
            AppTokens.space20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(height: AppTokens.space12),
              Text(
                username,
                style: AppTokens.titleMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppTokens.space4),
              Text(
                '已用 ${translateFileSize(usedSize)} / ${translateFileSize(totalSize)}',
                style: AppTokens.bodySmall.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: AppTokens.space12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        _sectionLabel('文件', brightness),
        for (final item in fileItems) _navTile(context, item, brightness),
        _sectionLabel('工具', brightness),
        for (final item in toolItems) _navTile(context, item, brightness),
        _sectionLabel('账号', brightness),
        for (final item in accountItems) _navTile(context, item, brightness),
        const SizedBox(height: AppTokens.space16),
      ],
    );
  }

  Widget _sectionLabel(String text, Brightness brightness) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space20,
          AppTokens.space16,
          AppTokens.space20,
          AppTokens.space4,
        ),
        child: Text(
          text,
          style: AppTokens.labelSmall.copyWith(
            color: AppTokens.textTertiary(brightness),
          ),
        ),
      );

  Widget _navTile(BuildContext context, HomeNavItem item, Brightness b) =>
      AppListTile(
        leading: Icon(item.icon, color: AppTokens.textSecondary(b)),
        title: item.title,
        onTap: () {
          Navigator.pop(context);
          item.onTap();
        },
      );
}

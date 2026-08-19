import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../models/user_info.dart';
import '../providers/auth_provider.dart';
import '../pages/ai_assistant_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/device_page.dart';
import '../pages/dedup_page.dart';
import '../pages/favorite_page.dart';
import '../pages/notification_page.dart';
import '../pages/offline_page.dart';
import '../pages/recent_page.dart';
import '../pages/recycle_page.dart';
import '../pages/settings_page.dart';
import '../pages/share_page.dart';
import '../pages/vault_page.dart';

/// 「我的」页（底部 Tab 的「我的」）
///
/// 容量卡 + 快捷宫格 + 设置分组。对齐阿里云盘「我的」结构。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _humanize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 100 || i <= 1 ? 0 : 1)} ${units[i]}';
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(AppTokens.route(page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => _open(context, const SettingsPage()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppTokens.space24),
        children: [
          // 用户信息 + 容量卡
          _buildUserHeader(context, user),
          // 快捷宫格
          _buildGrid(context),
          // 分组列表
          _Section(
            title: '存储管理',
            items: [
              _RowItem(
                icon: Icons.pie_chart_outline,
                label: '容量管理',
                onTap: () => _open(context, const DashboardPage()),
              ),
              _RowItem(
                icon: Icons.cloud_download_outlined,
                label: '离线下载',
                onTap: () => _open(context, const OfflinePage()),
              ),
              _RowItem(
                icon: Icons.content_copy_outlined,
                label: '文件去重',
                onTap: () => _open(context, const DedupPage()),
              ),
            ],
          ),
          _Section(
            title: '文件工具',
            items: [
              _RowItem(
                icon: Icons.history,
                label: '最近访问',
                onTap: () => _open(context, const RecentPage()),
              ),
              _RowItem(
                icon: Icons.star_outline,
                label: '我的收藏',
                onTap: () => _open(context, const FavoritePage()),
              ),
              _RowItem(
                icon: Icons.devices_outlined,
                label: '我的设备',
                onTap: () => _open(context, const DevicePage()),
              ),
            ],
          ),
          _Section(
            title: '偏好与账户',
            items: [
              _RowItem(
                icon: Icons.notifications_outlined,
                label: '通知中心',
                onTap: () => _open(context, const NotificationPage()),
              ),
              _RowItem(
                icon: Icons.insights_outlined,
                label: '数据仪表盘',
                onTap: () => _open(context, const DashboardPage()),
              ),
              _RowItem(
                icon: Icons.smart_toy_outlined,
                label: 'AI 助手',
                onTap: () => _open(context, const AIAssistantPage()),
              ),
              _RowItem(
                icon: Icons.logout,
                label: '退出登录',
                danger: true,
                onTap: () async =>
                    ref.read(authProvider.notifier).logout(),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          Center(
            child: Text(
              'X-Pan · 你的分布式网盘',
              style: AppTokens.labelSmall.copyWith(
                color: AppTokens.textSecondary(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, UserInfo? user) {
    return Container(
      margin: const EdgeInsets.all(AppTokens.space16),
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B7FFF), Color(0xFF0A5BE0)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Text(
                  (user?.username.isNotEmpty == true
                          ? user!.username[0]
                          : 'U')
                      .toUpperCase(),
                  style: AppTokens.titleLarge.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.username ?? '未登录',
                      style: AppTokens.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user != null
                          ? '已用 ${_humanize(user.usedSize)} / 共 ${_humanize(user.totalSize)}'
                          : '点击登录查看网盘',
                      style: AppTokens.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space14),
          if (user != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              child: LinearProgressIndicator(
                value: user.totalSize > 0
                    ? (user.usedSize / user.totalSize).clamp(0.0, 1.0)
                    : 0.0,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final items = [
      _GridItemData(
        icon: Icons.delete_outline,
        label: '回收站',
        page: const RecyclePage(),
      ),
      _GridItemData(
        icon: Icons.lock_outline,
        label: '保险箱',
        page: const VaultPage(),
      ),
      _GridItemData(
        icon: Icons.share_outlined,
        label: '我的分享',
        page: const SharePage(),
      ),
      _GridItemData(
        icon: Icons.star_outline,
        label: '我的收藏',
        page: const FavoritePage(),
      ),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        color: AppTokens.surfaceElevated(Theme.of(context).brightness),
        border: Border.all(
          color: AppTokens.divider(Theme.of(context).brightness)
              .withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppTokens.space8,
        crossAxisSpacing: AppTokens.space8,
        childAspectRatio: 1.0,
        children: [
          for (final it in items)
            InkWell(
              onTap: () => _open(context, it.page),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(it.icon, color: AppTokens.brandPrimary),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    it.label,
                    style: AppTokens.labelSmall.copyWith(
                      color: AppTokens.textPrimary(
                        Theme.of(context).brightness,
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

class _GridItemData {
  const _GridItemData({
    required this.icon,
    required this.label,
    required this.page,
  });
  final IconData icon;
  final String label;
  final Widget page;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<_RowItem> items;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
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
            title,
            style: AppTokens.labelSmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            color: AppTokens.surfaceElevated(brightness),
            border: Border.all(
              color: AppTokens.divider(brightness).withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: AppTokens.space16,
                    color: AppTokens.divider(brightness),
                  ),
                items[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = danger ? Colors.red : AppTokens.textPrimary(brightness);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space14,
        ),
        child: Row(
          children: [
            Icon(icon, color: danger ? Colors.red : AppTokens.brandPrimary),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                label,
                style: AppTokens.bodyMedium.copyWith(color: color),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTokens.textSecondary(brightness),
            ),
          ],
        ),
      ),
    );
  }
}

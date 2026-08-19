import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../providers/notification_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';

/// 通知中心页
class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final state = ref.watch(notificationProvider);
    final manager = ref.read(notificationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          if (state.notices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空',
              onPressed: manager.clear,
            ),
        ],
      ),
      body: ResponsiveContent(
        child: Column(
          children: [
            // 连接状态
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space16,
                vertical: AppTokens.space8,
              ),
              color: (state.connected
                      ? AppTokens.success
                      : AppTokens.neutral400)
                  .withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: state.connected
                        ? AppTokens.success
                        : AppTokens.neutral400,
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Text(
                    state.connected ? '实时通知已连接' : '实时通知未连接',
                    style: AppTokens.bodySmall.copyWith(
                      color: AppTokens.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.notices.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none,
                      title: '暂无通知',
                      subtitle: '系统消息与任务动态将在此展示',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTokens.space16),
                      itemCount: state.notices.length,
                      itemBuilder: (ctx, i) {
                        final notice = state.notices[i];
                        return _buildNotice(brightness, notice);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotice(Brightness brightness, AppNotice notice) {
    final color = switch (notice.level) {
      'success' => AppTokens.success,
      'error' => AppTokens.error,
      'warning' => AppTokens.warning,
      _ => AppTokens.brandPrimary,
    };
    final icon = switch (notice.level) {
      'success' => Icons.check_circle,
      'error' => Icons.error,
      'warning' => Icons.warning,
      _ => Icons.notifications,
    };

    return AppCard(
      elevation: CardElevation.low,
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.titleMedium.copyWith(
                          color: AppTokens.textPrimary(brightness),
                        ),
                      ),
                    ),
                    Text(
                      notice.time,
                      style: AppTokens.labelSmall.copyWith(
                        color: AppTokens.textTertiary(brightness),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  notice.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.bodyMedium.copyWith(
                    color: AppTokens.textSecondary(brightness),
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

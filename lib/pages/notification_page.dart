import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_provider.dart';

/// 通知中心页
class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: Column(
        children: [
          // 连接状态
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: state.connected
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: state.connected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  state.connected ? '实时通知已连接' : '实时通知未连接',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.notices.isEmpty
                ? const Center(child: Text('暂无通知'))
                : ListView.builder(
                    itemCount: state.notices.length,
                    itemBuilder: (ctx, i) {
                      final notice = state.notices[i];
                      return _buildNotice(context, notice);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(BuildContext context, AppNotice notice) {
    final color = switch (notice.level) {
      'success' => Colors.green,
      'error' => Colors.red,
      'warning' => Colors.orange,
      _ => Theme.of(context).colorScheme.primary,
    };

    return ListTile(
      leading: Icon(
        notice.level == 'success'
            ? Icons.check_circle
            : notice.level == 'error'
                ? Icons.error
                : notice.level == 'warning'
                    ? Icons.warning
                    : Icons.notifications,
        color: color,
      ),
      title: Text(notice.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        notice.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      trailing: Text(
        notice.time,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

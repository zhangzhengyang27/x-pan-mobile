import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_info.dart';
import '../providers/auth_provider.dart';
import '../utils/format.dart';
import '../widgets/responsive.dart';

/// 仪表盘 / 统计页
///
/// 对齐网页版 DashboardCards + DashboardCharts：
/// 统计当前用户存储用量与根目录文件类型分布。
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('存储统计')),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 存储用量卡片
            if (user != null) ...[
              _buildStorageCard(context, user),
              const SizedBox(height: 24),
            ],
            const Text(
              '功能说明',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '详细的文件类型分布图表将在后续版本中补充，'
                  '目前支持查看存储空间使用情况。',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context, UserInfo user) {
    final used = user.usedSize.toDouble();
    final total = user.totalSize.toDouble();
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('存储空间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已用 ${translateFileSize(used)}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                Text(
                  '共 ${translateFileSize(total)}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${(ratio * 100).toStringAsFixed(1)}% 已使用',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

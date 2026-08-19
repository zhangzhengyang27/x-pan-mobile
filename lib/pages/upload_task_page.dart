import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../providers/upload_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';

/// 上传任务面板
class UploadTaskPage extends ConsumerWidget {
  const UploadTaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(uploadManagerProvider);
    final manager = ref.read(uploadManagerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('上传任务'),
        actions: [
          if (queue.tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: '清除已完成',
              onPressed: () {
                for (final t in queue.tasks) {
                  if (t.status == UploadStatus.completed ||
                      t.status == UploadStatus.cancelled ||
                      t.status == UploadStatus.failed) {
                    manager.remove(t.id);
                  }
                }
              },
            ),
        ],
      ),
      body: ResponsiveContent(
        child: queue.tasks.isEmpty
            ? const EmptyState(
                icon: Icons.cloud_upload_outlined,
                title: '暂无上传任务',
                subtitle: '在网盘中选择文件即可开始上传',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppTokens.space16),
                itemCount: queue.tasks.length,
                itemBuilder: (ctx, i) {
                  final task = queue.tasks[i];
                  return _buildTask(context, task, manager);
                },
              ),
      ),
    );
  }

  Widget _buildTask(
    BuildContext context,
    UploadTask task,
    UploadManager manager,
  ) {
    final brightness = Theme.of(context).brightness;
    final (label, color) = switch (task.status) {
      UploadStatus.completed => ('已完成', AppTokens.success),
      UploadStatus.failed => ('失败', AppTokens.error),
      UploadStatus.cancelled => ('已取消', AppTokens.neutral400),
      UploadStatus.uploading => ('上传中', AppTokens.brandPrimary),
      UploadStatus.paused => ('已暂停', AppTokens.warning),
      UploadStatus.waiting => ('排队中', AppTokens.textSecondary(brightness)),
    };

    return AppCard(
      elevation: CardElevation.low,
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.titleMedium.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              // 状态标签
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space8,
                  vertical: AppTokens.space3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusFull),
                ),
                child: Text(
                  label,
                  style: AppTokens.labelSmall.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            task.error == null
                ? task.statusText
                : '${task.statusText}：${task.error}',
            style: AppTokens.bodySmall.copyWith(
              color: task.error == null
                  ? AppTokens.textSecondary(brightness)
                  : AppTokens.error,
            ),
          ),
          if (task.status == UploadStatus.uploading ||
              task.status == UploadStatus.paused) ...[
            const SizedBox(height: AppTokens.space12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    color:
                        AppTokens.divider(brightness).withValues(alpha: 0.5),
                  ),
                  FractionallySizedBox(
                    widthFactor: task.progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: AppTokens.dataGradient,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space4),
            Text(
              '${(task.progress * 100).toStringAsFixed(0)}%',
              style: AppTokens.labelSmall.copyWith(
                color: AppTokens.brandPrimary,
              ),
            ),
          ],
          // 操作按钮
          if (task.status == UploadStatus.uploading ||
              task.status == UploadStatus.failed ||
              task.status == UploadStatus.cancelled ||
              task.status == UploadStatus.completed) ...[
            const SizedBox(height: AppTokens.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == UploadStatus.uploading)
                  TextButton.icon(
                    onPressed: () => manager.cancel(task.id),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('取消'),
                  ),
                if (task.status == UploadStatus.failed ||
                    task.status == UploadStatus.cancelled)
                  TextButton.icon(
                    onPressed: () => manager.retry(task.id),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重试'),
                  ),
                if (task.status == UploadStatus.completed ||
                    task.status == UploadStatus.cancelled ||
                    task.status == UploadStatus.failed)
                  TextButton.icon(
                    onPressed: () => manager.remove(task.id),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('移除'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

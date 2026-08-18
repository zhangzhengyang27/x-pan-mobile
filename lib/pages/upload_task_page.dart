import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/upload_provider.dart';
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
            ? const Center(child: Text('暂无上传任务'))
            : ListView.builder(
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
    final scheme = Theme.of(context).colorScheme;
    final color = switch (task.status) {
      UploadStatus.completed => Colors.green,
      UploadStatus.failed => Colors.red,
      UploadStatus.cancelled => Colors.grey,
      UploadStatus.uploading => scheme.primary,
      UploadStatus.paused => Colors.orange,
      UploadStatus.waiting => scheme.onSurfaceVariant,
    };

    return ListTile(
      leading: Icon(
        task.status == UploadStatus.completed
            ? Icons.check_circle
            : task.status == UploadStatus.failed
                ? Icons.error
                : Icons.upload_file,
        color: color,
      ),
      title: Text(task.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.error == null
                ? task.statusText
                : '${task.statusText}：${task.error}',
            style: TextStyle(color: color, fontSize: 12),
          ),
          if (task.status == UploadStatus.uploading ||
              task.status == UploadStatus.paused) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: task.progress,
              minHeight: 4,
            ),
            const SizedBox(height: 2),
            Text(
              '${(task.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.status == UploadStatus.uploading)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '取消',
              onPressed: () => manager.cancel(task.id),
            ),
          if (task.status == UploadStatus.failed ||
              task.status == UploadStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重试',
              onPressed: () => manager.retry(task.id),
            ),
          if (task.status == UploadStatus.completed ||
              task.status == UploadStatus.cancelled ||
              task.status == UploadStatus.failed)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '移除',
              onPressed: () => manager.remove(task.id),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../providers/upload_provider.dart';
import '../services/offline_service.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// 传输中心（底部 Tab 的「传输」）
///
/// 顶部 TabBar（移到图标栏下方）拆分为「上传任务 / 离线下载」。
class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: const Text('传输中心'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTokens.brandPrimary,
          labelColor: AppTokens.brandPrimary,
          unselectedLabelColor: AppTokens.textSecondary(brightness),
          tabs: const [
            Tab(text: '上传任务'),
            Tab(text: '离线下载'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UploadTasksView(),
          _OfflineTasksView(),
        ],
      ),
    );
  }
}

/// 上传任务列表
class _UploadTasksView extends ConsumerWidget {
  const _UploadTasksView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(uploadManagerProvider);
    final manager = ref.read(uploadManagerProvider.notifier);

    return ResponsiveContent(
      child: queue.tasks.isEmpty
          ? const EmptyState(
              icon: Icons.cloud_upload_outlined,
              title: '暂无上传任务',
              subtitle: '在网盘中选择文件即可开始上传',
            )
          : Column(
              children: [
                if (queue.tasks.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('清除已完成'),
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
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTokens.space16),
                    itemCount: queue.tasks.length,
                    itemBuilder: (ctx, i) =>
                        _buildUploadTask(context, queue.tasks[i], manager),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUploadTask(
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
              Text(
                label,
                style: AppTokens.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (task.status == UploadStatus.uploading ||
                  task.status == UploadStatus.waiting ||
                  task.status == UploadStatus.paused)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '取消',
                  onPressed: () => manager.cancel(task.id),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          LinearProgressIndicator(
            value: task.progress,
            minHeight: 4,
            backgroundColor: AppTokens.divider(brightness),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }
}

/// 离线下载列表（复用 OfflineService）
class _OfflineTasksView extends ConsumerStatefulWidget {
  const _OfflineTasksView();

  @override
  ConsumerState<_OfflineTasksView> createState() => _OfflineTasksViewState();
}

class _OfflineTasksViewState extends ConsumerState<_OfflineTasksView> {
  List<OfflineTask> _tasks = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await OfflineService.instance.list();
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final urlCtrl = TextEditingController();
    final String? url;
    try {
      url = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('新建离线下载'),
          content: TextField(
            controller: urlCtrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '下载链接',
              hintText: 'http(s):// · 磁力/种子链接（云端自动解压与做种）',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
              child: const Text('创建'),
            ),
          ],
        ),
      );
    } finally {
      urlCtrl.dispose();
    }
    if (url == null || url.isEmpty) return;
    try {
      await OfflineService.instance.create(url: url);
      _toast('已创建离线任务');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _cancel(OfflineTask task) async {
    try {
      await OfflineService.instance.cancel(task.id);
      _toast('已取消');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _delete(OfflineTask task) async {
    try {
      await OfflineService.instance.delete(task.id);
      _toast('已删除');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ResponsiveContent(
      child: Stack(
        children: [
          if (_loading)
            const FileListSkeleton(itemCount: 4)
          else if (_error != null)
            EmptyState(
              icon: Icons.error_outline,
              title: '加载失败',
              subtitle: _error,
              actionLabel: '重试',
              actionIcon: Icons.refresh,
              onAction: _load,
            )
          else if (_tasks.isEmpty)
            const EmptyState(
              icon: Icons.cloud_download_outlined,
              title: '暂无离线任务',
              subtitle: '点击右下角按钮，粘贴链接即可离线下载',
            )
          else
            ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space16,
                vertical: AppTokens.space12,
              ),
              itemCount: _tasks.length,
              itemBuilder: (ctx, i) => _buildTask(_tasks[i], brightness),
            ),
          Positioned(
            right: AppTokens.space16,
            bottom: AppTokens.space16,
            child: FloatingActionButton(
              onPressed: _create,
              backgroundColor: AppTokens.brandPrimary,
              foregroundColor: AppTokens.neutral0,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  IconData _taskIcon(int status) {
    return switch (status) {
      2 => Icons.check_circle_outline,
      3 => Icons.error_outline,
      5 => Icons.unarchive_outlined, // 云解压中
      6 => Icons.hub_outlined, // 做种中
      _ => Icons.cloud_download_outlined,
    };
  }

  Widget _buildTask(OfflineTask task, Brightness b) {
    final statusColor = task.statusColor(b);
    final canCancel = task.isActive;
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      elevation: CardElevation.low,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Icon(_taskIcon(task.status), size: 20, color: statusColor),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.titleMedium.copyWith(
                        color: AppTokens.textPrimary(b),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.statusText,
                      style: AppTokens.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (canCancel)
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: AppTokens.textTertiary(b)),
                  tooltip: '取消',
                  onPressed: () => _cancel(task),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppTokens.error,
                tooltip: '删除',
                onPressed: () => _delete(task),
              ),
            ],
          ),
          // 进度 / 状态信息行
          if (task.status == 1 || task.status == 5) ...[
            const SizedBox(height: AppTokens.space12),
            _progressBar(task.progress, b),
            const SizedBox(height: AppTokens.space8),
            Text(
              task.status == 5
                  ? '云端解压中… ${(task.progress * 100).toInt()}%'
                  : '${(task.progress * 100).toInt()}%  ·  ${_formatSize(task.downloadedSize)} / ${_formatSize(task.totalSize)}',
              style: AppTokens.labelSmall.copyWith(
                color: AppTokens.textSecondary(b),
              ),
            ),
          ] else if (task.status == 6) ...[
            const SizedBox(height: AppTokens.space12),
            Row(
              children: [
                Icon(Icons.hub_outlined, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  '做种 ${_formatSpeed(task.seedSpeed)} · 连接 ${task.peers} 个节点',
                  style: AppTokens.labelSmall.copyWith(color: statusColor),
                ),
                const Spacer(),
                Text(
                  '保种中',
                  style: AppTokens.labelSmall.copyWith(
                    color: AppTokens.textSecondary(b),
                  ),
                ),
              ],
            ),
          ] else if (task.status == 0) ...[
            const SizedBox(height: AppTokens.space12),
            Text(
              '已加入队列，等待开始',
              style: AppTokens.labelSmall.copyWith(
                color: AppTokens.textSecondary(b),
              ),
            ),
          ],
          if (task.errorMsg != null && task.errorMsg!.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space8),
            Text(
              task.errorMsg!,
              style: AppTokens.labelSmall.copyWith(color: AppTokens.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatSize(num bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double v = bytes.toDouble();
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    return '${_formatSize(bytesPerSec)}/s';
  }

  Widget _progressBar(num progress, Brightness b) {
    final ratio = progress > 0 ? (progress / 100).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      child: Stack(
        children: [
          Container(height: 6, color: AppTokens.divider(b).withValues(alpha: 0.5)),
          if (ratio > 0)
            FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                height: 6,
                decoration: const BoxDecoration(
                  gradient: AppTokens.brandGradient,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppTokens.radiusFull),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

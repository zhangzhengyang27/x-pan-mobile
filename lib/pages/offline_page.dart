import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/offline_service.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// 离线下载页
class OfflinePage extends ConsumerStatefulWidget {
  const OfflinePage({super.key});

  @override
  ConsumerState<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends ConsumerState<OfflinePage> {
  List<OfflineTask> _tasks = [];
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
              hintText: 'http(s):// 或磁力链接',
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

  Color _statusColor(int status) {
    return switch (status) {
      2 => AppTokens.success,
      3 => AppTokens.error,
      1 => AppTokens.info,
      _ => AppTokens.neutral400,
    };
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(title: const Text('离线下载')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: AppTokens.brandPrimary,
        foregroundColor: AppTokens.neutral0,
        child: const Icon(Icons.add),
      ),
      body: ResponsiveContent(child: _buildBody(brightness)),
    );
  }

  Widget _buildBody(Brightness b) {
    if (_loading) {
      return const FileListSkeleton(itemCount: 4);
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: _error,
        actionLabel: '重试',
        actionIcon: Icons.refresh,
        onAction: _load,
      );
    }
    if (_tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.cloud_download_outlined,
        title: '暂无离线任务',
        subtitle: '点击右下角按钮，粘贴链接即可离线下载',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      itemCount: _tasks.length,
      itemBuilder: (ctx, i) => _buildTask(_tasks[i], b),
    );
  }

  Widget _buildTask(OfflineTask task, Brightness b) {
    final statusColor = _statusColor(task.status);
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
                child: Icon(
                  task.status == 2
                      ? Icons.check_circle_outline
                      : task.status == 3
                          ? Icons.error_outline
                          : Icons.cloud_download_outlined,
                  size: 20,
                  color: statusColor,
                ),
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
              if (task.status == 1)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: AppTokens.textTertiary(b),
                  ),
                  tooltip: '取消',
                  onPressed: () => _cancel(task),
                ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppTokens.error,
                ),
                tooltip: '删除',
                onPressed: () => _delete(task),
              ),
            ],
          ),
          if (task.status == 1) ...[
            const SizedBox(height: AppTokens.space12),
            _progressBar(task.progress, b),
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

  /// 渐变进度条
  Widget _progressBar(num progress, Brightness b) {
    final ratio = progress > 0 ? (progress / 100).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      child: Stack(
        children: [
          Container(
            height: 6,
            color: AppTokens.divider(b).withValues(alpha: 0.5),
          ),
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

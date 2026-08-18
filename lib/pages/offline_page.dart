import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/offline_service.dart';

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
    final url = await showDialog<String>(
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
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
    switch (status) {
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 1:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('离线下载')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }
    if (_tasks.isEmpty) {
      return const Center(child: Text('暂无离线任务'));
    }
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (ctx, i) {
        final task = _tasks[i];
        return ListTile(
          title: Text(task.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.statusText,
                style: TextStyle(color: _statusColor(task.status), fontSize: 12),
              ),
              if (task.status == 1)
                LinearProgressIndicator(
                  value: task.progress > 0 ? task.progress / 100 : null,
                  minHeight: 4,
                ),
              if (task.errorMsg != null && task.errorMsg!.isNotEmpty)
                Text(
                  task.errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.status == 1)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '取消',
                  onPressed: () => _cancel(task),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除',
                onPressed: () => _delete(task),
              ),
            ],
          ),
        );
      },
    );
  }
}

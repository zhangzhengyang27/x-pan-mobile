import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_vo.dart';
import '../services/recycle_service.dart';
import '../utils/format.dart';
import '../widgets/file_type_icon.dart';

/// 回收站页
class RecyclePage extends ConsumerStatefulWidget {
  const RecyclePage({super.key});

  @override
  ConsumerState<RecyclePage> createState() => _RecyclePageState();
}

class _RecyclePageState extends ConsumerState<RecyclePage> {
  List<FileVO> _items = [];
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
      final items = await RecycleService.instance.recycles();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(FileVO file) async {
    try {
      await RecycleService.instance.restore(file.fileId);
      _toast('已恢复');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _deleteForever(FileVO file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text('确定彻底删除「${file.filename}」吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await RecycleService.instance.deleteForever(file.fileId);
      _toast('已彻底删除');
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
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
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
    if (_items.isEmpty) {
      return const Center(child: Text('回收站为空'));
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final file = _items[i];
        return ListTile(
          leading: FileTypeIcon(type: file.fileType),
          title: Text(file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            file.fileSizeDesc ?? translateFileSize(parseFileSize(file.fileSize)),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: '恢复',
                onPressed: () => _restore(file),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: '彻底删除',
                onPressed: () => _deleteForever(file),
              ),
            ],
          ),
        );
      },
    );
  }
}

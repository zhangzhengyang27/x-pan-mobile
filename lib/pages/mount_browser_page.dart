import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../core/theme/app_tokens.dart';
import '../services/mount_service.dart';
import '../utils/format.dart';

/// 外部挂载目录浏览：路径用相对挂载根的 key，所有读写都按用户归属校验由后端处理。
class MountBrowserPage extends StatefulWidget {
  const MountBrowserPage({super.key, required this.mount});

  final MountVO mount;

  @override
  State<MountBrowserPage> createState() => _MountBrowserPageState();
}

class _MountBrowserPageState extends State<MountBrowserPage> {
  List<MountEntry> _entries = const [];
  String _path = '';
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
      final entries = await MountService.instance.browse(widget.mount.id, _path);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _enterDir(MountEntry entry) {
    setState(() => _path = entry.key.endsWith('/') ? entry.key : '${entry.key}/');
    _load();
  }

  void _up() {
    if (_path.isEmpty) return;
    final parts = _path.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) parts.removeLast();
    setState(() => _path = parts.isEmpty ? '' : '${parts.join('/')}/');
    _load();
  }

  Future<void> _open(MountEntry entry) async {
    try {
      final file = await MountService.instance.download(widget.mount.id, entry);
      await OpenFilex.open(file.path);
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _upload() async {
    final result = await file_picker.FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    try {
      for (final picked in result.files) {
        if (picked.path == null) continue;
        await MountService.instance.upload(widget.mount.id, _path, picked.path!, picked.name);
      }
      await _load();
      _toast('已上传 ${result.files.length} 个文件');
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _mkdir() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建目录'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: '目录名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('创建')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (name.contains('/') || name.contains('..')) {
      _toast('目录名不能包含 / 或 ..');
      return;
    }
    try {
      await MountService.instance.makeDir(widget.mount.id, '$_path$name');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _delete(MountEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.dir ? '删除目录' : '删除对象'),
        content: Text('这会真删外部存储中的内容（不进回收站）：\n${entry.display}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final failed = await MountService.instance.deleteObject(widget.mount.id, entry.key, entry.dir);
      await _load();
      if (failed.isNotEmpty) {
        _toast('部分对象删除失败（${failed.length} 个）');
      }
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mount.name),
        actions: [
          IconButton(onPressed: _path.isEmpty ? null : _up, icon: const Icon(Icons.arrow_upward), tooltip: '上一级'),
          IconButton(onPressed: _mkdir, icon: const Icon(Icons.create_new_folder_outlined), tooltip: '新建目录'),
          IconButton(onPressed: _upload, icon: const Icon(Icons.upload), tooltip: '上传'),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTokens.background(b),
            child: Text('/${_path.isEmpty ? '' : _path}', style: AppTokens.labelSmall.copyWith(color: AppTokens.textSecondary(b))),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, textAlign: TextAlign.center, style: AppTokens.bodyMedium.copyWith(color: AppTokens.textPrimary(b))))
                    : _entries.isEmpty
                        ? Center(child: Text('目录为空', style: AppTokens.bodyMedium.copyWith(color: AppTokens.textSecondary(b))))
                        : ListView.separated(
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: AppTokens.divider(b)),
                            itemBuilder: (ctx, i) {
                              final entry = _entries[i];
                              return ListTile(
                                leading: Icon(
                                  entry.dir ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                                  color: entry.dir ? AppTokens.warning : AppTokens.textSecondary(b),
                                ),
                                title: Text(entry.display, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: entry.dir ? null : Text(translateFileSize(entry.size)),
                                onTap: entry.dir ? () => _enterDir(entry) : () => _open(entry),
                                onLongPress: () => _delete(entry),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

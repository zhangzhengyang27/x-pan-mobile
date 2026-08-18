import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_version.dart';
import '../services/user_service.dart';
import '../utils/format.dart';
import '../widgets/responsive.dart';

/// 文件版本历史页
class VersionHistoryPage extends ConsumerStatefulWidget {
  const VersionHistoryPage({super.key, required this.fileId});

  final String fileId;

  @override
  ConsumerState<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends ConsumerState<VersionHistoryPage> {
  List<FileVersion> _versions = [];
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
      final versions =
          await FileService.instance.listVersions(widget.fileId);
      if (mounted) setState(() => _versions = versions);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rollback(FileVersion version) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('回滚版本'),
        content: Text('确定回滚到版本 V${version.versionNumber} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('回滚'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FileService.instance.rollback(
        id: version.id,
        fileId: widget.fileId,
      );
      _toast('已回滚');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _deleteVersion(FileVersion version) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除版本'),
        content: Text('确定删除版本 V${version.versionNumber} 吗？'),
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
      await FileService.instance.deleteVersion(
        id: version.id,
        fileId: widget.fileId,
      );
      _toast('已删除版本');
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
      appBar: AppBar(title: const Text('版本历史')),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }
    if (_versions.isEmpty) {
      return const Center(child: Text('暂无版本记录'));
    }

    return ListView.builder(
      itemCount: _versions.length,
      itemBuilder: (ctx, i) {
        final version = _versions[i];
        return ListTile(
          leading: CircleAvatar(
            child: Text('V${version.versionNumber}'),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  version.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (version.current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '当前',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            '${version.operationText} · '
            '${translateFileSize(parseFileSize(version.fileSize))} · '
            '${version.createTime}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rollback') await _rollback(version);
              if (v == 'delete') await _deleteVersion(version);
            },
            itemBuilder: (_) => [
              if (!version.current)
                const PopupMenuItem(
                  value: 'rollback',
                  child: Text('回滚到此版本'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除此版本'),
              ),
            ],
          ),
        );
      },
    );
  }
}

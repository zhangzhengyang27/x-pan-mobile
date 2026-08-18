import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dedup_service.dart';

/// 文件去重页
class DedupPage extends ConsumerStatefulWidget {
  const DedupPage({super.key});

  @override
  ConsumerState<DedupPage> createState() => _DedupPageState();
}

class _DedupPageState extends ConsumerState<DedupPage> {
  DedupStat? _stat;
  List<DedupGroup> _groups = [];
  bool _loading = true;
  String? _error;

  /// 每组保留的文件（默认保留第一个）
  final Map<String, String> _keepByGroup = {};

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
      final stat = await DedupService.instance.stat();
      final groups = await DedupService.instance.list();
      if (mounted) {
        setState(() {
          _stat = stat;
          _groups = groups;
          // 默认每组保留第一个（空分组跳过，避免 .first 越界）
          for (final g in groups) {
            if (g.items.isEmpty) continue;
            _keepByGroup.putIfAbsent(g.realFileId, () => g.items.first.fileId);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _releaseAll() async {
    final keepIds = _keepByGroup.values.toList();
    if (keepIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('释放冗余空间'),
        content: Text(
          '将释放 ${_stat?.releasableDesc ?? ''}，每组仅保留一个文件，确定继续吗？',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('释放')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DedupService.instance.release(keepIds);
      _toast('已释放冗余空间');
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
      appBar: AppBar(
        title: const Text('文件去重'),
        actions: [
          if (_groups.isNotEmpty)
            TextButton(
              onPressed: _releaseAll,
              child: const Text('一键释放'),
            ),
        ],
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

    return Column(
      children: [
        // 统计卡片
        if (_stat != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('重复组', '${_stat!.groupCount}'),
                _statItem('冗余文件', '${_stat!.redundantCount}'),
                _statItem('可释放', _stat!.releasableDesc),
              ],
            ),
          ),
        Expanded(
          child: _groups.isEmpty
              ? const Center(child: Text('没有重复文件'))
              : ListView.builder(
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) {
                    final group = _groups[i];
                    return _buildGroup(group);
                  },
                ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildGroup(DedupGroup group) {
    final keepId = _keepByGroup[group.realFileId];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text(
          '${group.items.length} 个相同文件 · ${group.fileSizeDesc}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text('可释放 ${group.releasableBytes > 0 ? _fmtBytes(group.releasableBytes) : group.fileSizeDesc}'),
        children: [
          for (final item in group.items)
            RadioListTile<String>(
              value: item.fileId,
              groupValue: keepId,
              title: Text(
                item.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('保留此文件，其余删除', style: TextStyle(fontSize: 11)),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _keepByGroup[group.realFileId] = v);
                }
              },
            ),
        ],
      ),
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}K';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}M';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)}G';
  }
}

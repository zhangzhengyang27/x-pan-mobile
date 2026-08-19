import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/recycle_service.dart';
import '../utils/format.dart';
import '../widgets/app_list_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

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
      await RecycleService.instance.restore([file.fileId]);
      _toast('已恢复');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _deleteForever(FileVO file) async {
    final confirm = await _confirmDelete('确定彻底删除「${file.filename}」吗？此操作不可恢复。');
    if (confirm != true) return;
    try {
      await RecycleService.instance.deleteForever([file.fileId]);
      _toast('已彻底删除');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _emptyRecycle() async {
    if (_items.isEmpty) return;
    final confirm = await _confirmDelete(
      '确定清空回收站吗？将彻底删除 ${_items.length} 个文件，此操作不可恢复。',
    );
    if (confirm != true) return;
    try {
      await RecycleService.instance
          .deleteForever(_items.map((f) => f.fileId).toList());
      _toast('已清空回收站');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<bool?> _confirmDelete(String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: ResponsiveContent(child: _buildBody()),
      bottomNavigationBar: (!_loading && _error == null && _items.isNotEmpty)
          ? _buildEmptyBar()
          : null,
    );
  }

  Widget _buildEmptyBar() {
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: OutlinedButton.icon(
          onPressed: _emptyRecycle,
          icon: const Icon(Icons.delete_forever),
          label: const Text('清空回收站'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTokens.error,
            side: BorderSide(
              color: AppTokens.error.withValues(
                alpha: brightness == Brightness.dark ? 0.6 : 0.4,
              ),
            ),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const FileListSkeleton(itemCount: 6);
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: '加载失败',
        subtitle: _error,
        actionLabel: '重试',
        actionIcon: Icons.refresh,
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.delete_outline,
        title: '回收站为空',
        subtitle: '删除的文件会在此保留 30 天',
      );
    }
    return Column(
      children: [
        // 顶部警示条
        Container(
          margin: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            AppTokens.space4,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space12,
          ),
          decoration: BoxDecoration(
            color: AppTokens.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: AppTokens.warning.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppTokens.warning,
              ),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  '文件将在 30 天后自动清理，请及时恢复重要文件',
                  style: AppTokens.bodySmall.copyWith(
                    color: brightness == Brightness.dark
                        ? AppTokens.warning
                        : AppTokens.warning.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space8,
              vertical: AppTokens.space4,
            ),
            itemCount: _items.length,
            itemBuilder: (ctx, i) {
              final file = _items[i];
              return AppListTile(
                leading: FileTypeIcon(type: file.fileType),
                title: file.filename,
                subtitle: file.fileSizeDesc ??
                    translateFileSize(parseFileSize(file.fileSize)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _restore(file),
                      child: const Text('还原'),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_forever,
                        color: AppTokens.error,
                      ),
                      tooltip: '彻底删除',
                      onPressed: () => _deleteForever(file),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

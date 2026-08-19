import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/recent_storage.dart';
import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../widgets/app_list_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// 最近访问记录页
class RecentPage extends ConsumerStatefulWidget {
  const RecentPage({super.key});

  @override
  ConsumerState<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends ConsumerState<RecentPage> {
  List<RecentItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await RecentStorage.getAll();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    await RecentStorage.clear();
    await _load();
    _toast('已清空');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 按日期分组：今天 / 昨天 / 本周 / 更早
  Map<String, List<RecentItem>> _groupByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 6));

    final groups = <String, List<RecentItem>>{};
    for (final item in _items) {
      final date = DateTime.tryParse(
        item.visitTime.replaceAll(' ', 'T'),
      );
      String key;
      if (date == null) {
        key = '更早';
      } else if (!date.isBefore(today)) {
        key = '今天';
      } else if (!date.isBefore(yesterday)) {
        key = '昨天';
      } else if (!date.isBefore(weekStart)) {
        key = '本周';
      } else {
        key = '更早';
      }
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('最近访问'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空',
              onPressed: _clear,
            ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const FileListSkeleton(itemCount: 6);
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: '暂无访问记录',
        subtitle: '打开文件后将在此展示',
      );
    }

    final groups = _groupByDate();
    const order = ['今天', '昨天', '本周', '更早'];
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space8,
      ),
      children: [
        for (final key in order)
          if (groups.containsKey(key)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space12,
                AppTokens.space12,
                AppTokens.space12,
                AppTokens.space4,
              ),
              child: Text(
                key,
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            for (final item in groups[key]!)
              AppListTile(
                leading: FileTypeIcon(type: FileType.fromCode(item.fileType)),
                title: item.filename,
                trailing: Text(
                  _timePart(item.visitTime),
                  style: AppTokens.labelSmall.copyWith(
                    color: AppTokens.textTertiary(brightness),
                  ),
                ),
              ),
          ],
      ],
    );
  }

  /// 提取时间部分（HH:mm）
  String _timePart(String visitTime) {
    final parts = visitTime.split(' ');
    if (parts.length < 2) return visitTime;
    return parts[1];
  }
}

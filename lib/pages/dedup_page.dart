import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/dedup_service.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('释放'),
          ),
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
              child: Text(
                '一键释放',
                style: TextStyle(
                  color: AppTokens.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const FileListSkeleton();
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

    return Column(
      children: [
        // 统计卡片
        if (_stat != null) _buildStatCard(brightness),
        Expanded(
          child: _groups.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: '没有重复文件',
                  subtitle: '你的网盘空间利用得很好',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: AppTokens.space12,
                    right: AppTokens.space12,
                    bottom: AppTokens.space24,
                  ),
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) => _buildGroup(_groups[i], brightness),
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(Brightness b) {
    return Container(
      margin: const EdgeInsets.all(AppTokens.space16),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space20,
      ),
      decoration: BoxDecoration(
        gradient: AppTokens.brandGradient,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: AppTokens.shadowBrand(b),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('重复组', '${_stat!.groupCount}'),
          _statItem('冗余文件', '${_stat!.redundantCount}'),
          _statItem('可释放', _stat!.releasableDesc),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTokens.headlineMedium.copyWith(
            color: AppTokens.neutral0,
          ),
        ),
        const SizedBox(height: AppTokens.space4),
        Text(
          label,
          style: AppTokens.bodySmall.copyWith(
            color: AppTokens.neutral0.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildGroup(DedupGroup group, Brightness b) {
    final keepId = _keepByGroup[group.realFileId];
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      elevation: CardElevation.low,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
          ),
          iconColor: AppTokens.brandPrimary,
          collapsedIconColor: AppTokens.textTertiary(b),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTokens.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: const Icon(
                  Icons.copy_all_outlined,
                  size: 18,
                  color: AppTokens.brandPrimary,
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${group.items.length} 个相同文件 · ${group.fileSizeDesc}',
                      style: AppTokens.labelLarge.copyWith(
                        color: AppTokens.textPrimary(b),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '可释放 ${group.releasableBytes > 0 ? _fmtBytes(group.releasableBytes) : group.fileSizeDesc}',
                      style: AppTokens.bodySmall.copyWith(
                        color: AppTokens.textSecondary(b),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            RadioGroup<String>(
              groupValue: keepId,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _keepByGroup[group.realFileId] = v);
                }
              },
              // 同一组重复文件可能很多，用受高度约束的滚动列表展示，
              // 避免 ExpansionTile 展开后 Column 超高导致 RenderFlex 溢出。
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: group.items.length,
                  itemBuilder: (ctx, i) {
                    final item = group.items[i];
                    final kept = keepId == item.fileId;
                    return RadioListTile<String>(
                      value: item.fileId,
                      activeColor: AppTokens.brandPrimary,
                      title: Text(
                        item.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.bodyMedium.copyWith(
                          color: AppTokens.textPrimary(b),
                          fontWeight: kept ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        kept ? '保留此项' : '保留此文件，其余删除',
                        style: AppTokens.labelSmall.copyWith(
                          color: kept
                              ? AppTokens.brandPrimary
                              : AppTokens.textTertiary(b),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
          ],
        ),
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

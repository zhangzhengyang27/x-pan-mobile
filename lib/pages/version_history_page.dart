import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_version.dart';
import '../services/user_service.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
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
    final brightness = Theme.of(context).brightness;
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
    if (_versions.isEmpty) {
      return const EmptyState(
        icon: Icons.history_outlined,
        title: '暂无版本记录',
      );
    }

    // 时间轴：左侧竖线 + 圆点节点，右侧版本卡片
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space20,
        AppTokens.space16,
        AppTokens.space16,
        AppTokens.space24,
      ),
      itemCount: _versions.length,
      itemBuilder: (ctx, i) =>
          _buildTimelineItem(_versions[i], i, brightness),
    );
  }

  Widget _buildTimelineItem(FileVersion version, int index, Brightness b) {
    final isLast = index == _versions.length - 1;
    final isCurrent = version.current;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间轴节点 + 竖线
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: AppTokens.space20),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? AppTokens.brandPrimary : b == Brightness.dark
                        ? AppTokens.darkSurface
                        : AppTokens.neutral0,
                    border: Border.all(
                      color: isCurrent
                          ? AppTokens.brandPrimary
                          : AppTokens.neutral300,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppTokens.divider(b),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space12),
          // 版本卡片
          Expanded(
            child: AppCard(
              margin: const EdgeInsets.only(bottom: AppTokens.space16),
              elevation: CardElevation.low,
              padding: const EdgeInsets.all(AppTokens.space14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 版本号徽章
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTokens.brandPrimary
                              : AppTokens.brandPrimary
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusFull,
                          ),
                        ),
                        child: Text(
                          'V${version.versionNumber}',
                          style: AppTokens.labelSmall.copyWith(
                            color: isCurrent
                                ? AppTokens.neutral0
                                : AppTokens.brandPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space8),
                      if (isCurrent)
                        Text(
                          '当前版本',
                          style: AppTokens.labelSmall.copyWith(
                            color: AppTokens.brandPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          size: 20,
                          color: AppTokens.textTertiary(b),
                        ),
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
                    ],
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    version.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.titleMedium.copyWith(
                      color: AppTokens.textPrimary(b),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    '${version.operationText} · '
                    '${translateFileSize(parseFileSize(version.fileSize))} · '
                    '${version.createTime}',
                    style: AppTokens.bodySmall.copyWith(
                      color: AppTokens.textSecondary(b),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

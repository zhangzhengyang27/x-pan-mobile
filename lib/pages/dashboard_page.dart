import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/recent_storage.dart';
import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../providers/auth_provider.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/gradient_header.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// 仪表盘 / 统计页
///
/// 对齐网页版 DashboardCards + DashboardCharts：
/// 统计当前用户存储用量与最近访问的文件类型分布。
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _loading = true;

  /// 文件类型 → 最近访问次数
  Map<FileType, int> _typeDist = {};

  @override
  void initState() {
    super.initState();
    _loadTypeDist();
  }

  Future<void> _loadTypeDist() async {
    try {
      final recent = await RecentStorage.getAll();
      final dist = <FileType, int>{};
      for (final item in recent) {
        final type = FileType.fromCode(item.fileType);
        if (type == FileType.folder) continue;
        dist[type] = (dist[type] ?? 0) + 1;
      }
      if (mounted) setState(() => _typeDist = dist);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      body: ResponsiveContent(
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              title: const Text('存储统计'),
              pinned: true,
              expandedHeight: 160,
              flexibleSpace: FlexibleSpaceBar(
                background: GradientHeader(
                  height: 160,
                  safeArea: false,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.space20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.username ?? '未登录',
                            style: AppTokens.headlineMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppTokens.space4),
                          Text(
                            user == null
                                ? '存储空间概览'
                                : '已用 ${translateFileSize(user.usedSize.toDouble())} / '
                                    '${translateFileSize(user.totalSize.toDouble())}',
                            style: AppTokens.bodySmall.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.all(AppTokens.space16),
            children: [
              // 存储用量卡片
              if (user != null) ...[
                _buildStorageCard(brightness, user.usedSize.toDouble(),
                    user.totalSize.toDouble()),
                const SizedBox(height: AppTokens.space24),
              ],
              Text(
                '文件类型分布',
                style: AppTokens.titleMedium.copyWith(
                  color: AppTokens.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              _buildTypeChart(brightness),
              const SizedBox(height: AppTokens.space24),
              Text(
                '功能说明',
                style: AppTokens.titleMedium.copyWith(
                  color: AppTokens.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              AppCard(
                elevation: CardElevation.low,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTokens.brandPrimary,
                    ),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: Text(
                        '类型分布基于最近访问记录统计，'
                        '完整的云端文件类型分布图表将在后续版本中补充。',
                        style: AppTokens.bodySmall.copyWith(
                          color: AppTokens.textSecondary(brightness),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 存储用量卡片：大号百分比 + dataGradient 进度条
  Widget _buildStorageCard(Brightness brightness, double used, double total) {
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    return AppCard(
      padding: const EdgeInsets.all(AppTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '存储空间',
            style: AppTokens.titleMedium.copyWith(
              color: AppTokens.textPrimary(brightness),
            ),
          ),
          const SizedBox(height: AppTokens.space16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(ratio * 100).toStringAsFixed(1)}%',
                style: AppTokens.displayMedium.copyWith(
                  color: AppTokens.brandPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppTokens.space8,
                  bottom: AppTokens.space8,
                ),
                child: Text(
                  '已使用',
                  style: AppTokens.bodySmall.copyWith(
                    color: AppTokens.textSecondary(brightness),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: AppTokens.divider(brightness).withValues(alpha: 0.5),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      gradient: AppTokens.dataGradient,
                      borderRadius:
                          BorderRadius.horizontal(left: Radius.circular(999)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已用 ${translateFileSize(used)}',
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
              ),
              Text(
                '共 ${translateFileSize(total)}',
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 文件类型分布横向条形图（基于最近访问记录）
  Widget _buildTypeChart(Brightness brightness) {
    if (_loading) {
      return AppCard(
        elevation: CardElevation.low,
        child: Column(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(height: AppTokens.space12),
              Row(
                children: [
                  const SkeletonBox(width: 48, height: 12),
                  const SizedBox(width: AppTokens.space12),
                  const Expanded(child: SkeletonBox(height: 12)),
                ],
              ),
            ],
          ],
        ),
      );
    }
    if (_typeDist.isEmpty) {
      return AppCard(
        elevation: CardElevation.low,
        child: Text(
          '暂无访问记录，打开文件后将在此展示类型分布。',
          style: AppTokens.bodyMedium.copyWith(
            color: AppTokens.textSecondary(brightness),
          ),
        ),
      );
    }

    final entries = _typeDist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.first.value;

    return AppCard(
      elevation: CardElevation.low,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: AppTokens.space12),
            _buildTypeBar(
              brightness,
              label: _typeName(entries[i].key),
              ratio: entries[i].value / maxCount,
              count: entries[i].value,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeBar(
    Brightness brightness, {
    required String label,
    required double ratio,
    required int count,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: AppTokens.bodySmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
        ),
        const SizedBox(width: AppTokens.space12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color:
                      AppTokens.divider(brightness).withValues(alpha: 0.5),
                ),
                FractionallySizedBox(
                  widthFactor: ratio.clamp(0.05, 1.0),
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: AppTokens.dataGradient,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTokens.space12),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: AppTokens.labelSmall.copyWith(
              color: AppTokens.textPrimary(brightness),
            ),
          ),
        ),
      ],
    );
  }

  String _typeName(FileType type) => switch (type) {
        FileType.image => '图片',
        FileType.video => '视频',
        FileType.audio => '音频',
        FileType.pdf => 'PDF',
        FileType.word => '文档',
        FileType.excel => '表格',
        FileType.ppt => '演示',
        FileType.txt => '文本',
        FileType.code => '代码',
        FileType.csv => 'CSV',
        FileType.archive => '压缩包',
        _ => '其他',
      };
}

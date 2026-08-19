import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/share_service.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import 'share_detail_page.dart';

/// 分享管理页
class SharePage extends ConsumerStatefulWidget {
  const SharePage({super.key});

  @override
  ConsumerState<SharePage> createState() => _SharePageState();
}

class _SharePageState extends ConsumerState<SharePage> {
  List<ShareVO> _shares = [];
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
      final shares = await ShareService.instance.list();
      if (mounted) setState(() => _shares = shares);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(ShareVO share) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消分享'),
        content: const Text('确定取消该分享吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ShareService.instance.cancel([share.shareId]);
      _toast('已取消分享');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _copyUrl(ShareVO share) async {
    await Clipboard.setData(
      ClipboardData(text: share.shareUrl.isEmpty ? '分享链接' : share.shareUrl),
    );
    _toast('分享链接已复制');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 通过分享链接/ID 打开他人分享
  Future<void> _openShare() async {
    final ctrl = TextEditingController();
    final String? input;
    try {
      input = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('打开分享'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '分享链接或分享ID',
              hintText: '粘贴完整链接或分享ID',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('打开'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (input == null || input.isEmpty) return;

    // 从链接中提取 shareId（形如 .../share/{shareId} 或纯 shareId）
    final shareId = _extractShareId(input);
    if (shareId == null) {
      _toast('无效的分享链接');
      return;
    }
    if (mounted) {
      Navigator.of(context).push(
        AppTokens.route(ShareDetailPage(shareId: shareId)),
      );
    }
  }

  String? _extractShareId(String input) {
    // 纯 ID（数字或字母数字组合）
    if (RegExp(r'^[0-9a-zA-Z]+$').hasMatch(input)) return input;
    // 从 URL 中提取 /share/{id}
    final match = RegExp(r'/share/([0-9a-zA-Z]+)').firstMatch(input);
    return match?.group(1);
  }

  String _typeText(int type) {
    switch (type) {
      case 1:
        return '公开';
      case 2:
        return '需提取码';
      case 3:
        return '指定用户';
      default:
        return '未知';
    }
  }

  /// 分享是否已过期（超过有效期）
  bool _isExpired(ShareVO share) {
    final end = share.shareEndTime;
    if (end == null || end.isEmpty) return false;
    final endDate = DateTime.tryParse(end.replaceAll(' ', 'T'));
    if (endDate == null) return false;
    return endDate.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的分享'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: '打开分享',
            onPressed: _openShare,
          ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppTokens.space8),
        child: Column(
          children: [CardSkeleton(), CardSkeleton(), CardSkeleton()],
        ),
      );
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
    if (_shares.isEmpty) {
      return const EmptyState(
        icon: Icons.share_outlined,
        title: '暂无分享',
        subtitle: '在网盘中选中文件即可创建分享',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.space16),
      itemCount: _shares.length,
      itemBuilder: (ctx, i) {
        final share = _shares[i];
        final expired = _isExpired(share);
        return AppCard(
          elevation: CardElevation.low,
          margin: const EdgeInsets.only(bottom: AppTokens.space12),
          onTap: () => _copyUrl(share),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      share.shareName.isEmpty
                          ? share.shareId
                          : share.shareName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.titleMedium.copyWith(
                        color: AppTokens.textPrimary(brightness),
                      ),
                    ),
                  ),
                  // 状态标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space8,
                      vertical: AppTokens.space3,
                    ),
                    decoration: BoxDecoration(
                      color: (expired
                              ? AppTokens.neutral400
                              : AppTokens.success)
                          .withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusFull),
                    ),
                    child: Text(
                      expired ? '已过期' : '有效',
                      style: AppTokens.labelSmall.copyWith(
                        color: expired
                            ? AppTokens.neutral400
                            : AppTokens.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                '${_typeText(share.shareType)}'
                '${share.shareCode.isNotEmpty ? ' · 提取码: ${share.shareCode}' : ''}'
                '${share.shareEndTime != null ? ' · 有效期至: ${share.shareEndTime}' : ''}',
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      share.shareUrl.isEmpty ? '分享链接' : share.shareUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.bodySmall.copyWith(
                        color: AppTokens.brandPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: '复制链接',
                    onPressed: () => _copyUrl(share),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTokens.error,
                    ),
                    tooltip: '取消分享',
                    onPressed: () => _cancel(share),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

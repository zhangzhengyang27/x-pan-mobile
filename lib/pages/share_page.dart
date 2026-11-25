import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/share_service.dart';
import '../utils/e2ee_share.dart';
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
    if (share.shareUrl.isEmpty) {
      // shareUrl 为空（例如后端未生成分享链接）时不复制占位文本，明确提示用户
      _toast('暂无分享链接，无法复制');
      return;
    }
    await Clipboard.setData(ClipboardData(text: share.shareUrl));
    _toast('分享链接已复制');
  }

  /// 修改文件收集开关。后端会再校验“仅单个文件夹分享”，失败时直接提示。
  Future<void> _toggleCollect(ShareVO share, bool enabled) async {
    try {
      await ShareService.instance.setCollect(
        shareId: share.shareId,
        enabled: enabled,
      );
      _toast(enabled ? '已开启文件收集' : '已关闭文件收集');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// 查看申诉状态并提交申诉；同一分享只允许一条待处理申诉。
  Future<void> _appeal(ShareVO share) async {
    ShareAppeal? appeal;
    try {
      appeal = await ShareService.instance.getAppeal(share.shareId);
    } catch (e) {
      _toast(e.toString());
      return;
    }
    if (appeal != null && appeal.pending) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('申诉审核中'),
          content: Text(
            '申诉理由：${appeal!.reason}\n提交时间：${appeal.createTime ?? '—'}\n\n管理员复核后会通过通知告知结果。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    final ctrl = TextEditingController();
    final String? reason;
    try {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('申诉分享'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '申诉理由',
              hintText: '说明分享内容合规、请求管理员复核',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('提交申诉'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (reason == null || reason.isEmpty) return;
    try {
      await ShareService.instance.appeal(
        shareId: share.shareId,
        reason: reason,
      );
      _toast('申诉已提交，等待管理员复核');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
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
    final target = _parseShareInput(input);
    if (target == null) {
      _toast('无效的分享链接');
      return;
    }
    if (mounted) {
      Navigator.of(context).push(
        AppTokens.route(ShareDetailPage(
          shareId: target.shareId,
          e2eeKey: target.key,
          e2eeIv: target.iv,
        )),
      );
    }
  }

  /// 解析链接：shareId + E2EE fragment 密钥
  ///
  /// fragment 不会随 HTTP 请求发送到服务端，只能由客户端从用户粘贴的完整链接里取；
  /// 仅分享列表里的 shareUrl 不含密钥，因此从列表进入 E2EE 分享时只能提示缺少密钥。
  _ShareTarget? _parseShareInput(String input) {
    final uri = Uri.tryParse(input);
    final fragment = uri?.fragment.isNotEmpty == true
        ? parseE2eeFragment(uri!.fragment)
        : parseE2eeFragment(input);
    final shareId = _extractShareId(uri != null ? uri.path : input) ??
        _extractShareId(input);
    if (shareId == null) return null;
    return _ShareTarget(
      shareId: shareId,
      key: fragment?['key'],
      iv: fragment?['iv'],
    );
  }

  String? _extractShareId(String input) {
    // 分享 ID 由后端 IdUtil 使用 URL-safe Base64 加密生成，字符集为字母数字 + '-'/'_'，
    // 因此 ID 正则需同时覆盖这三种字符，否则含 '-'/'_' 的合法 ID 会被误判为无效。
    final idChar = r'0-9a-zA-Z_\-';
    // 纯 ID（字母数字 + '-'/'_' 组合）
    if (RegExp('^[$idChar]+\$').hasMatch(input)) return input;
    // 从 URL 中提取 /share/{id}
    final match = RegExp('/share/([$idChar]+)').firstMatch(input);
    return match?.group(1);
  }

  String _typeText(int type) {
    switch (type) {
      case 0:
        return '需提取码';
      case 1:
        return '公开';
      case 2:
        return '指定用户';
      default:
        return '未知';
    }
  }

  /// 永久有效阈值：后端永久分享的结束时间固定为 2099-12-31 23:59:59，
  /// 结束时间落在 2099 年（含）之后即视为“永久有效”。
  static final DateTime _permanentThreshold = DateTime(2099);

  /// 解析后端返回的日期时间字符串（兼容 " " 和 "T" 分隔）。
  DateTime? _parseEndTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  /// 分享有效期展示文案
  String _expireText(ShareVO share) {
    final endDate = _parseEndTime(share.shareEndTime);
    if (endDate == null) {
      return ' · 永久有效';
    }
    // 永久有效：结束时间落在远未来（2099 年及以后）
    if (!endDate.isBefore(_permanentThreshold)) {
      return ' · 永久有效';
    }
    // 格式化展示：2026-08-19 09:57
    final formatted =
        '${endDate.year}-${_pad(endDate.month)}-${_pad(endDate.day)} '
        '${_pad(endDate.hour)}:${_pad(endDate.minute)}';
    return ' · 有效期至: $formatted';
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  /// 分享是否已过期（超过有效期）
  bool _isExpired(ShareVO share) {
    // 优先信任后端返回的 shareStatus（1 通常表示已过期 / 已取消）
    if (share.shareStatus == 1) return true;

    final endDate = _parseEndTime(share.shareEndTime);
    if (endDate == null) return false;

    // 永久有效（结束时间在远未来）不会过期
    if (!endDate.isBefore(_permanentThreshold)) return false;

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
                  // 状态标签：举报隐藏优先于普通有效期状态
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space8,
                      vertical: AppTokens.space3,
                    ),
                    decoration: BoxDecoration(
                      color: (share.reportHidden
                              ? AppTokens.error
                              : expired
                                  ? AppTokens.neutral400
                                  : AppTokens.success)
                          .withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusFull),
                    ),
                    child: Text(
                      share.reportHidden
                          ? '待复核'
                          : expired
                              ? '已过期'
                              : '有效',
                      style: AppTokens.labelSmall.copyWith(
                        color: share.reportHidden
                            ? AppTokens.error
                            : expired
                                ? AppTokens.neutral400
                                : AppTokens.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                '${share.e2ee ? '端到端加密' : _typeText(share.shareType)}'
                '${share.shareType == 0 && share.shareCode.isNotEmpty ? ' · 提取码: ${share.shareCode}' : ''}'
                '${_expireText(share)}',
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              Text(
                '访问 ${share.visitCount} · 保存 ${share.saveCount} · 下载 '
                '${share.downloadCount}${share.downloadLimit > 0 ? '/${share.downloadLimit}' : ''}'
                '${share.forbidReshare ? ' · 禁止转载' : ''}'
                '${share.collectEnabled ? ' · 收集开启' : ''}',
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              Row(
                children: [
                  if (!expired && !share.reportHidden && !share.e2ee)
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '文件收集',
                            style: AppTokens.bodySmall.copyWith(
                              color: AppTokens.textSecondary(brightness),
                            ),
                          ),
                          Switch(
                            value: share.collectEnabled,
                            onChanged: (value) => _toggleCollect(share, value),
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  if (share.reportHidden)
                    TextButton.icon(
                      onPressed: () => _appeal(share),
                      icon: const Icon(Icons.gavel_outlined, size: 16),
                      label: const Text('申诉'),
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.space4),
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

/// 打开分享的解析结果
class _ShareTarget {
  const _ShareTarget({required this.shareId, this.key, this.iv});

  final String shareId;
  final String? key;
  final String? iv;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/share_service.dart';
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ShareService.instance.cancel(share.shareId);
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
    final input = await showDialog<String>(
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('打开'),
          ),
        ],
      ),
    );
    if (input == null || input.isEmpty) return;

    // 从链接中提取 shareId（形如 .../share/{shareId} 或纯 shareId）
    final shareId = _extractShareId(input);
    if (shareId == null) {
      _toast('无效的分享链接');
      return;
    }
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShareDetailPage(shareId: shareId),
        ),
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
    if (_shares.isEmpty) {
      return const Center(child: Text('暂无分享'));
    }
    return ListView.builder(
      itemCount: _shares.length,
      itemBuilder: (ctx, i) {
        final share = _shares[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(
              share.shareName.isEmpty ? share.shareId : share.shareName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${_typeText(share.shareType)}'
              '${share.shareCode.isNotEmpty ? ' · 提取码: ${share.shareCode}' : ''}'
              '${share.shareEndTime != null ? '\n有效期至: ${share.shareEndTime}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: share.shareEndTime != null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: '复制链接',
                  onPressed: () => _copyUrl(share),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '取消分享',
                  onPressed: () => _cancel(share),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

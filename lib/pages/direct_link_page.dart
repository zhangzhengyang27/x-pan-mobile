import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_tokens.dart';
import '../services/direct_link_service.dart';

/// 直链管理页：直链由文件操作“创建直链”产生，这里只负责列表/复制/启停/删除。
class DirectLinkPage extends StatefulWidget {
  const DirectLinkPage({super.key});

  @override
  State<DirectLinkPage> createState() => _DirectLinkPageState();
}

class _DirectLinkPageState extends State<DirectLinkPage> {
  List<DirectLinkVO> _links = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final links = await DirectLinkService.instance.list();
      if (!mounted) return;
      setState(() {
        _links = links;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _copy(DirectLinkVO link) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    _toast('直链已复制');
  }

  Future<void> _toggle(DirectLinkVO link) async {
    try {
      await DirectLinkService.instance.toggle(link.id, link.enableFlag == 1 ? 0 : 1);
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _delete(DirectLinkVO link) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除直链'),
        content: Text('删除后“${link.filename}”的直链立即失效，可重新创建。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DirectLinkService.instance.delete(link.id);
      _toast('已删除');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件直链'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: AppTokens.bodyMedium.copyWith(color: AppTokens.textPrimary(b)), textAlign: TextAlign.center))
              : _links.isEmpty
                  ? Center(child: Text('暂无直链\n在文件操作中选择“创建直链”', textAlign: TextAlign.center, style: AppTokens.bodyMedium.copyWith(color: AppTokens.textSecondary(b))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _links.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final link = _links[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTokens.surface(b),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTokens.divider(b)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      link.filename,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTokens.bodyMedium.copyWith(color: AppTokens.textPrimary(b)),
                                    ),
                                  ),
                                  Switch(
                                    value: link.enableFlag == 1,
                                    onChanged: (_) => _toggle(link),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                link.url,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTokens.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '创建于 ${link.createTime}${link.expireTime == null ? ' · 永久有效' : ' · 到期 ${link.expireTime}'}',
                                style: AppTokens.labelSmall,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _copy(link),
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('复制'),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _delete(link),
                                    child: const Text('删除', style: TextStyle(color: AppTokens.error)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

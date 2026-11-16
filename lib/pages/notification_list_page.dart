import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../services/notification_api.dart';

/// 移动端通知中心：列表（最新 50 条，倒序）+ 未读高亮 + 单条/全部已读
class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  final NotificationApi _api = NotificationApi.instance();

  List<NotificationItem> _items = const [];
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
      final items = await _api.list(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.readFlag == 1) return;
    try {
      await _api.markRead(item.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标记已读失败：$e')),
      );
      return;
    }
    if (!mounted) return;
    _load(); // 已读状态以服务端为准，刷新列表与未读角标
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('全部已读失败：$e')),
      );
      return;
    }
    if (!mounted) return;
    _load();
  }

  Widget _buildItem(BuildContext context, NotificationItem item) {
    final brightness = Theme.of(context).brightness;
    final unread = item.readFlag == 0;
    final titleColor =
        unread ? AppTokens.textPrimary(brightness) : AppTokens.textSecondary(brightness);
    final titleStyle = unread
        ? AppTokens.titleMedium.copyWith(color: titleColor)
        : AppTokens.bodyMedium.copyWith(color: titleColor);

    return ListTile(
      leading: Icon(
        unread ? Icons.notifications_active_outlined : Icons.notifications_none,
        color: unread ? AppTokens.brandPrimary : AppTokens.textTertiary(brightness),
      ),
      title: Text(item.title, style: titleStyle),
      subtitle: item.content.isEmpty
          ? null
          : Text(
              item.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.bodySmall.copyWith(
                color: AppTokens.textSecondary(brightness),
              ),
            ),
      isThreeLine: item.content.isNotEmpty,
      trailing: unread
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTokens.brandPrimary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () => _markRead(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('全部已读'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: AppTokens.bodyMedium.copyWith(
                          color: AppTokens.textSecondary(brightness),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space16),
                      OutlinedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('暂无通知'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _buildItem(context, _items[index]),
                      ),
                    ),
    );
  }
}

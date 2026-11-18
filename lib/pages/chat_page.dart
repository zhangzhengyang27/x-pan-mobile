import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../services/chat_service.dart';
import '../core/theme/app_tokens.dart' as tokens;
import '../widgets/empty_state.dart';
import 'chat_detail_page.dart';

/// 站内 IM：会话列表 + 好友管理
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  final TextEditingController _applyIdCtrl = TextEditingController();
  final TextEditingController _applyMsgCtrl = TextEditingController();
  final TextEditingController _groupNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatNotifierProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _applyIdCtrl.dispose();
    _applyMsgCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: '创建群聊',
            onPressed: () => _showCreateGroup(chatState),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: '会话',
              icon: chatState.totalUnread > 0
                  ? Badge(
                      label: Text('${chatState.totalUnread}'),
                      child: const Icon(Icons.chat_bubble_outline),
                    )
                  : const Icon(Icons.chat_bubble_outline),
            ),
            Tab(
              text: '好友',
              icon: chatState.applies.isNotEmpty
                  ? Badge(
                      label: Text('${chatState.applies.length}'),
                      child: const Icon(Icons.people_outline),
                    )
                  : const Icon(Icons.people_outline),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(chatNotifierProvider.notifier).refresh(),
            child: _buildConversations(chatState, brightness),
          ),
          RefreshIndicator(
            onRefresh: () => ref.read(chatNotifierProvider.notifier).refresh(),
            child: _buildFriends(chatState),
          ),
        ],
      ),
    );
  }

  Widget _buildConversations(ChatState chatState, Brightness brightness) {
    if (chatState.conversations.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: '暂无会话',
        subtitle: '到「好友」页添加好友开始聊天',
      );
    }
    return ListView.separated(
      itemCount: chatState.conversations.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: tokens.AppTokens.divider(brightness).withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) {
        final conv = chatState.conversations[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: conv.type == 'GROUP'
                ? Colors.deepPurple
                : tokens.AppTokens.brandPrimary,
            child: Text(
              conv.type == 'GROUP'
                  ? '群'
                  : (conv.displayName.isNotEmpty ? conv.displayName[0] : '?'),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          title: Row(
            children: [
              Expanded(child: Text(conv.displayName, overflow: TextOverflow.ellipsis)),
              if (conv.type == 'DIRECT')
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: conv.peerOnline ? Colors.green : Colors.grey,
                  ),
                ),
            ],
          ),
          subtitle: Text(
            conv.lastMsgPreview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: conv.unread > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    conv.unread > 99 ? '99+' : '${conv.unread}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )
              : null,
          onTap: () async {
            await Navigator.of(context).push(tokens.AppTokens.route(
              ChatDetailPage(conversationId: conv.conversationId),
            ));
            if (mounted) ref.read(chatNotifierProvider.notifier).refresh();
          },
        );
      },
    );
  }

  Widget _buildFriends(ChatState chatState) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _applyIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '输入好友数字 ID',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _applyMsgCtrl,
                decoration: const InputDecoration(
                  hintText: '验证消息（可选）',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('发送好友申请'),
                  onPressed: _submitApply,
                ),
              ),
            ],
          ),
        ),
        if (chatState.applies.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('待处理申请',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ...chatState.applies.map((apply) => ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(apply.fromUsername),
              subtitle: Text(apply.applyMessage.isEmpty
                  ? '请求添加你为好友'
                  : apply.applyMessage),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await ChatService.instance.acceptFriendApply(apply.id);
                        if (mounted) ref.read(chatNotifierProvider.notifier).refresh();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('操作失败：$e')));
                        }
                      }
                    },
                    child: const Text('同意'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await ChatService.instance.rejectFriendApply(apply.id);
                        if (mounted) ref.read(chatNotifierProvider.notifier).refresh();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('操作失败：$e')));
                        }
                      }
                    },
                    child: const Text('拒绝'),
                  ),
                ],
              ),
            )),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('我的好友',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        ...chatState.friends.map((friend) => ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    child: Text(friend.username.isNotEmpty
                        ? friend.username[0]
                        : '?'),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: friend.online ? Colors.green : Colors.grey,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(friend.remark.isNotEmpty
                  ? friend.remark
                  : friend.username),
              subtitle: Text(friend.username),
              trailing: TextButton(
                onPressed: () => _confirmDeleteFriend(friend.friendUserId, friend.username),
                child: const Text('删除',
                    style: TextStyle(color: Colors.red)),
              ),
              onTap: () async {
                final conv = await ChatService.instance
                    .directConversation(friend.friendUserId);
                if (mounted) {
                  await Navigator.of(context).push(tokens.AppTokens.route(
                    ChatDetailPage(conversationId: conv.conversationId),
                  ));
                  if (mounted) ref.read(chatNotifierProvider.notifier).refresh();
                }
              },
            )),
        if (chatState.friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('还没有好友，输入对方的数字用户 ID 发送申请',
                style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Future<void> _submitApply() async {
    final target = _applyIdCtrl.text.trim();
    if (target.isEmpty) return;
    try {
      await ChatService.instance.applyFriend(target, _applyMsgCtrl.text.trim());
      if (mounted) {
        _applyIdCtrl.clear();
        _applyMsgCtrl.clear();
        ref.read(chatNotifierProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('申请已发送')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('申请失败：$e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteFriend(String friendUserId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('删除后与 $username 的好友关系解除（历史会话保留）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await ChatService.instance.deleteFriend(friendUserId);
      if (mounted) ref.read(chatNotifierProvider.notifier).refresh();
    }
  }

  Future<void> _showCreateGroup(ChatState chatState) async {
    final selected = <String>{};
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('创建群聊'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: '群名称'),
                ),
                const SizedBox(height: 8),
                ...chatState.friends.map((friend) => CheckboxListTile(
                      dense: true,
                      title: Text(friend.remark.isNotEmpty
                          ? friend.remark
                          : friend.username),
                      value: selected.contains(friend.friendUserId),
                      onChanged: (checked) {
                        setState(() {
                          checked == true
                              ? selected.add(friend.friendUserId)
                              : selected.remove(friend.friendUserId);
                        });
                      },
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || selected.isEmpty) return;
                try {
                  final conv = await ChatService.instance
                      .createGroup(nameCtrl.text.trim(), selected.toList());
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ref.read(chatNotifierProvider.notifier).refresh();
                  if (mounted) {
                    await Navigator.of(context).push(tokens.AppTokens.route(
                      ChatDetailPage(conversationId: conv.conversationId),
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('创建失败：$e')));
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

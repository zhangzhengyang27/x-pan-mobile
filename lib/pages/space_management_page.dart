import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/token_storage.dart';
import '../core/theme/app_tokens.dart';
import '../models/space_info.dart';
import '../models/space_member.dart';
import '../providers/auth_provider.dart';
import '../services/deep_link_service.dart';
import '../services/space_service.dart';
import 'space_acl_page.dart';
import '../widgets/empty_state.dart';

/// 团队空间管理（列表 + 成员 + 邀请）
class SpaceManagementPage extends ConsumerStatefulWidget {
  const SpaceManagementPage({super.key});

  @override
  ConsumerState<SpaceManagementPage> createState() =>
      _SpaceManagementPageState();
}

class _SpaceManagementPageState extends ConsumerState<SpaceManagementPage> {
  List<SpaceInfo> _spaces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final spaces = await SpaceService.instance.list();
      if (!mounted) return;
      setState(() {
        _spaces = spaces;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('空间列表加载失败');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createTeam() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建团队空间'),
        content: TextField(
          controller: ctrl,
          maxLength: 32,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '空间名称',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = ctrl.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await SpaceService.instance.createTeam(name);
      _toast('团队空间已创建');
      await _load();
    } catch (e) {
      _toast('创建失败：$e');
    }
  }

  Future<void> _joinByCode() async {
    final ctrl = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通过邀请码加入'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: '邀请码或邀请链接',
            hintText: '如 HQWUXE3V 或 xpan://join?code=HQWUXE3V',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('加入'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final code = DeepLinkService.parseInviteInput(input ?? '');
    if (code == null) {
      _toast('请输入有效的邀请码');
      return;
    }
    try {
      final preview = await SpaceService.instance.previewInvite(code);
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('加入团队空间'),
          content: Text(
            '空间：${preview.spaceName}\n'
            '创建者：${preview.ownerUsername}\n'
            '成员：${preview.memberCount} 人',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(preview.alreadyMember ? '进入' : '加入'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      if (!preview.alreadyMember) {
        await SpaceService.instance.join(code);
      }
      _toast('已加入 ${preview.spaceName}');
      await _load();
    } catch (e) {
      _toast('加入失败：$e');
    }
  }

  Future<void> _openDetail(SpaceInfo space) async {
    await Navigator.of(context).push(
      AppTokens.route(_SpaceDetailPage(space: space)),
    );
    await _load();
  }

  Future<void> _switchTo(SpaceInfo space) async {
    await TokenStorage.setSpaceId(space.isTeam ? space.spaceId : '');
    if (!mounted) return;
    _toast(space.isTeam ? '已切换到 ${space.spaceName}' : '已切换到个人空间');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: const Text('团队空间'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: '通过邀请码加入',
            onPressed: _joinByCode,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建团队空间',
            onPressed: _createTeam,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppTokens.space16),
                children: [
                  if (_spaces.isEmpty)
                    const EmptyState(
                      icon: Icons.groups_outlined,
                      title: '暂无空间',
                      subtitle: '创建一个团队空间，邀请成员一起协作',
                    ),
                  for (final space in _spaces)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppTokens.space12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTokens.brandPrimary
                              .withValues(alpha: 0.12),
                          child: Icon(
                            space.isTeam
                                ? Icons.groups_outlined
                                : Icons.person_outline,
                            color: AppTokens.brandPrimary,
                          ),
                        ),
                        title: Text(
                          space.isTeam ? space.spaceName : '个人空间',
                          style: TextStyle(
                            color: AppTokens.textPrimary(brightness),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatSize(space.usedSize)} / ${_formatSize(space.totalSize)}'
                          '${space.isTeam ? ' · ${space.memberCount} 人 · ${_roleLabel(space.role)}' : ''}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'open') _openDetail(space);
                            if (value == 'switch') _switchTo(space);
                          },
                          itemBuilder: (context) => [
                            if (space.isTeam)
                              const PopupMenuItem(
                                value: 'open',
                                child: Text('成员与邀请'),
                              ),
                            const PopupMenuItem(
                              value: 'switch',
                              child: Text('切换到此空间'),
                            ),
                          ],
                        ),
                        onTap: space.isTeam ? () => _openDetail(space) : null,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  static String _roleLabel(String role) {
    return {
          'OWNER': '所有者',
          'ADMIN': '管理员',
          'MEMBER': '成员',
          'VIEWER': '只读',
        }[role] ??
        role;
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(value >= 10 || index == 0 ? 0 : 1)} ${units[index]}';
  }
}

/// 团队详情：成员与邀请管理
class _SpaceDetailPage extends ConsumerStatefulWidget {
  const _SpaceDetailPage({required this.space});

  final SpaceInfo space;

  @override
  ConsumerState<_SpaceDetailPage> createState() => _SpaceDetailPageState();
}

class _SpaceDetailPageState extends ConsumerState<_SpaceDetailPage> {
  List<SpaceMemberInfo> _members = [];
  List<SpaceInviteInfo> _invites = [];
  bool _loading = true;

  SpaceInfo get _space => widget.space;

  bool get _canManage => _space.role == 'OWNER' || _space.role == 'ADMIN';

  bool get _isOwner => _space.role == 'OWNER';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SpaceService.instance.listMembers(_space.spaceId),
        SpaceService.instance.listInvites(_space.spaceId),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<SpaceMemberInfo>;
        _invites = results[1] as List<SpaceInviteInfo>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载失败');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createInvite() async {
    try {
      final invite = await SpaceService.instance.createInvite(_space.spaceId);
      await Clipboard.setData(ClipboardData(text: invite.inviteUrl));
      _toast('邀请链接已复制：${invite.inviteUrl}');
      await _load();
    } catch (e) {
      _toast('创建邀请失败：$e');
    }
  }

  Future<void> _changeRole(SpaceMemberInfo member) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in {
              'ADMIN': '管理员',
              'MEMBER': '成员',
              'VIEWER': '只读',
            }.entries)
              ListTile(
                title: Text(entry.value),
                trailing: member.role == entry.key
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (role == null || role == member.role) return;
    try {
      await SpaceService.instance
          .updateMemberRole(_space.spaceId, member.userId, role);
      _toast('角色已更新');
      await _load();
    } catch (e) {
      _toast('修改失败：$e');
    }
  }

  Future<void> _removeMember(SpaceMemberInfo member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定将 ${member.username} 移出空间？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SpaceService.instance.removeMember(_space.spaceId, member.userId);
      _toast('已移除');
      await _load();
    } catch (e) {
      _toast('操作失败：$e');
    }
  }

  Future<void> _leave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出空间'),
        content: const Text('退出后将无法访问该团队的共享文件，确定退出？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final currentUserId = ref.read(authProvider).user?.userId ?? '';
    if (currentUserId.isEmpty) {
      _toast('登录状态异常，请重新登录');
      return;
    }
    try {
      await SpaceService.instance.removeMember(_space.spaceId, currentUserId);
      _toast('已退出空间');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('退出失败：$e');
    }
  }

  Future<void> _dissolve() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解散空间'),
        content: const Text('解散后空间将不可访问，且必须已清空全部文件。确定解散？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解散'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SpaceService.instance.dissolve(_space.spaceId);
      _toast('空间已解散');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('解散失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: Text(_space.spaceName),
        actions: [
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: '生成邀请链接',
              onPressed: _createInvite,
            ),
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: '目录权限',
              onPressed: () => Navigator.of(context).push(
                AppTokens.route(SpaceAclPage(space: _space)),
              ),
            ),
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'dissolve') _dissolve();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'dissolve', child: Text('解散空间')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppTokens.space16),
                children: [
                  Text(
                    '成员（${_members.length}）',
                    style: AppTokens.titleMedium.copyWith(
                      color: AppTokens.textPrimary(brightness),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  for (final member in _members)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            member.username.isEmpty
                                ? '?'
                                : member.username
                                    .substring(0, 1)
                                    .toUpperCase(),
                          ),
                        ),
                        title: Text(member.username),
                        subtitle: Text(_roleLabel(member.role)),
                        trailing: _canManage && member.role != 'OWNER'
                            ? PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'role') _changeRole(member);
                                  if (value == 'remove') _removeMember(member);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'role',
                                    child: Text('修改角色'),
                                  ),
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Text('移除成员'),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  const SizedBox(height: AppTokens.space16),
                  Text(
                    '有效邀请（${_invites.length}）',
                    style: AppTokens.titleMedium.copyWith(
                      color: AppTokens.textPrimary(brightness),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  if (_invites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '暂无有效邀请，点击右上角链接按钮生成。',
                        style: AppTokens.bodySmall.copyWith(
                          color: AppTokens.textSecondary(brightness),
                        ),
                      ),
                    ),
                  for (final invite in _invites)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(invite.inviteCode),
                        subtitle: Text(
                          '已用 ${invite.usedCount}'
                          '${invite.maxUses > 0 ? '/${invite.maxUses}' : ''} 次',
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: '复制邀请链接',
                          onSelected: (value) async {
                            final link = value == 'app'
                                ? 'xpan://join?code=${invite.inviteCode}'
                                : invite.inviteUrl;
                            await Clipboard.setData(ClipboardData(text: link));
                            _toast(value == 'app'
                                ? 'App 邀请链接已复制'
                                : '邀请链接已复制');
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'web',
                              child: Text('复制网页链接'),
                            ),
                            PopupMenuItem(
                              value: 'app',
                              child: Text('复制 App 链接'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_isOwner) ...[
                    const SizedBox(height: AppTokens.space16),
                    OutlinedButton.icon(
                      onPressed: _leave,
                      icon: const Icon(Icons.logout),
                      label: const Text('退出空间'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  static String _roleLabel(String role) {
    return {
          'OWNER': '所有者',
          'ADMIN': '管理员',
          'MEMBER': '成员',
          'VIEWER': '只读',
        }[role] ??
        role;
  }
}

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../models/space_info.dart';
import '../models/space_member.dart';
import '../services/space_service.dart';

/// 团队目录权限：用户组维护 + 目录 ACL 授权。
///
/// 注意：subjectId 必须是后端原始用户/用户组 ID 字符串（接口返回的 userId/groupId），
/// 不要经 IdUtil 加密，否则后端解析失败。
class SpaceAclPage extends StatefulWidget {
  const SpaceAclPage({super.key, required this.space});

  final SpaceInfo space;

  @override
  State<SpaceAclPage> createState() => _SpaceAclPageState();
}

class _SpaceAclPageState extends State<SpaceAclPage> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<SpaceGroup> _groups = const [];
  List<SpaceAcl> _acls = const [];
  List<SpaceMemberInfo> _members = const [];
  List<SpaceFolderNode> _folders = const [];
  final Set<String> _expandedGroups = {};

  String get _spaceId => widget.space.spaceId;

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
      final results = await Future.wait([
        SpaceService.instance.listGroups(_spaceId),
        SpaceService.instance.listAcls(_spaceId),
        SpaceService.instance.listMembers(_spaceId),
        SpaceService.instance.listFolders(_spaceId),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = results[0] as List<SpaceGroup>;
        _acls = results[1] as List<SpaceAcl>;
        _members = results[2] as List<SpaceMemberInfo>;
        _folders = results[3] as List<SpaceFolderNode>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建用户组'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: '用户组名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('创建')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await SpaceService.instance.createGroup(_spaceId, name);
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _deleteGroup(SpaceGroup group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户组'),
        content: Text('删除“${group.groupName}”会同时移除组成员与相关目录授权。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SpaceService.instance.deleteGroup(_spaceId, group.groupId);
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _editGroupMembers(SpaceGroup group) async {
    final selected = <String>{for (final m in group.members) m.userId};
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${group.groupName} · 成员'),
          content: SizedBox(
            width: double.maxFinite,
            height: 340,
            child: ListView(
              children: [
                for (final member in _members)
                  CheckboxListTile(
                    dense: true,
                    value: selected.contains(member.userId),
                    title: Text(member.username),
                    subtitle: Text(member.role),
                    onChanged: (value) => setLocal(() {
                      if (value == true) {
                        selected.add(member.userId);
                      } else {
                        selected.remove(member.userId);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      // 差集分别调用后端加/移接口；后端按 userId 幂等处理重复提交
      final oldIds = group.members.map((e) => e.userId).toSet();
      final add = selected.difference(oldIds).toList();
      final remove = oldIds.difference(selected).toList();
      if (add.isNotEmpty) await SpaceService.instance.addGroupMembers(_spaceId, group.groupId, add);
      if (remove.isNotEmpty) await SpaceService.instance.removeGroupMembers(_spaceId, group.groupId, remove);
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _addAcl() async {
    final folder = await _pickFolder();
    if (folder == null) return;
    if (!mounted) return;
    final subject = await showModalBottomSheet<_AclSubject>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (_groups.isNotEmpty) ...[
              const ListTile(dense: true, title: Text('用户组', style: TextStyle(fontWeight: FontWeight.w600))),
              for (final group in _groups)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.group_outlined),
                  title: Text(group.groupName),
                  onTap: () => Navigator.pop(ctx, _AclSubject('GROUP', group.groupId, group.groupName)),
                ),
            ],
            const ListTile(dense: true, title: Text('成员', style: TextStyle(fontWeight: FontWeight.w600))),
            for (final member in _members)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(member.username),
                onTap: () => Navigator.pop(ctx, _AclSubject('USER', member.userId, member.username)),
              ),
          ],
        ),
      ),
    );
    if (subject == null) return;
    if (!mounted) return;
    final permission = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('权限'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'READ'), child: const Text('只读（READ）')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'WRITE'), child: const Text('读写（WRITE，隐含 READ）')),
        ],
      ),
    );
    if (permission == null) return;
    try {
      await SpaceService.instance.saveAcl(
        _spaceId,
        folderId: folder.id,
        subjectType: subject.type,
        subjectId: subject.id,
        permission: permission,
      );
      await _load();
      _toast('目录授权已保存');
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<SpaceFolderNode?> _pickFolder() async {
    final flat = <({SpaceFolderNode node, String path})>[];
    void walk(List<SpaceFolderNode> nodes, String prefix) {
      for (final node in nodes) {
        final path = prefix.isEmpty ? node.label : '$prefix/${node.label}';
        flat.add((node: node, path: path));
        walk(node.children, path);
      }
    }

    walk(_folders, '');
    if (flat.isEmpty) {
      _toast('空间中暂无文件夹');
      return null;
    }
    return showModalBottomSheet<SpaceFolderNode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          itemCount: flat.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) => ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text('/${flat[i].path}', maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(ctx, flat[i].node),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAcl(SpaceAcl acl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除授权'),
        content: Text('移除 ${acl.subjectName} 对 /${acl.folderPath} 的 ${acl.permission} 权限？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SpaceService.instance.deleteAcl(_spaceId, acl.id);
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
        title: const Text('目录权限'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('目录授权')),
                ButtonSegment(value: 1, label: Text('用户组')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: AppTokens.bodySmall.copyWith(color: AppTokens.error)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tab == 0
                    ? _buildAcls(b)
                    : _buildGroups(b),
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _tab == 0 ? _addAcl : _createGroup,
              icon: Icon(_tab == 0 ? Icons.add_link : Icons.group_add),
              label: Text(_tab == 0 ? '新增授权' : '新建用户组'),
            ),
    );
  }

  Widget _buildAcls(Brightness b) {
    if (_acls.isEmpty) {
      return Center(child: Text('暂无目录授权', style: AppTokens.bodyMedium.copyWith(color: AppTokens.textSecondary(b))));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _acls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final acl = _acls[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTokens.surface(b),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTokens.divider(b)),
          ),
          child: Row(
            children: [
              Icon(acl.subjectType == 'GROUP' ? Icons.group_outlined : Icons.person_outline, color: AppTokens.brandPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${acl.subjectName} · ${acl.permission}', style: AppTokens.bodyMedium.copyWith(color: AppTokens.textPrimary(b))),
                    Text('/${acl.folderPath}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTokens.bodySmall.copyWith(color: AppTokens.textSecondary(b))),
                  ],
                ),
              ),
              IconButton(onPressed: () => _deleteAcl(acl), icon: const Icon(Icons.delete_outline, color: AppTokens.error)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroups(Brightness b) {
    if (_groups.isEmpty) {
      return Center(child: Text('暂无用户组', style: AppTokens.bodyMedium.copyWith(color: AppTokens.textSecondary(b))));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final group = _groups[i];
        final expanded = _expandedGroups.contains(group.groupId);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTokens.surface(b),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTokens.divider(b)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.group_outlined, color: AppTokens.brandPrimary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${group.groupName} · ${group.memberCount} 人', style: AppTokens.bodyMedium.copyWith(color: AppTokens.textPrimary(b)))),
                  IconButton(
                    onPressed: () => setState(() {
                      if (expanded) {
                        _expandedGroups.remove(group.groupId);
                      } else {
                        _expandedGroups.add(group.groupId);
                      }
                    }),
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ),
                ],
              ),
              if (expanded) ...[
                for (final member in group.members)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('· ${member.username}', style: AppTokens.bodySmall.copyWith(color: AppTokens.textSecondary(b))),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(onPressed: () => _editGroupMembers(group), child: const Text('管理成员')),
                    const Spacer(),
                    TextButton(onPressed: () => _deleteGroup(group), child: const Text('删除', style: TextStyle(color: AppTokens.error))),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AclSubject {
  const _AclSubject(this.type, this.id, this.name);

  final String type;
  final String id;
  final String name;
}

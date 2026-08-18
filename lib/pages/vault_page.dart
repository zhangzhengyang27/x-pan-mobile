import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_vo.dart';
import '../services/vault_service.dart';
import '../utils/format.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/responsive.dart';

/// 隐私保险箱页
class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  VaultStatus? _status;
  List<FileVO> _files = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await VaultService.instance.status();
      if (mounted) setState(() => _status = status);

      if (status.hasPassword && status.unlocked) {
        final files = await VaultService.instance.list();
        if (mounted) setState(() => _files = files);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 设置密码（首次）
  Future<void> _setup() async {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置保险箱密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '确认密码'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.isEmpty || ctrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('两次输入的密码不一致')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('设置'),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      await VaultService.instance.setup(ctrl.text);
      _toast('保险箱密码已设置');
      await _init();
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// 解锁
  Future<void> _unlock() async {
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解锁保险箱'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: '密码'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('解锁'),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty) return;
    try {
      await VaultService.instance.unlock(password);
      _toast('已解锁');
      await _init();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _lock() async {
    try {
      await VaultService.instance.lock();
      _toast('已锁定');
      await _init();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _moveOut(FileVO file) async {
    try {
      await VaultService.instance.moveOut(file.fileId);
      _toast('已移出保险箱');
      await _init();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _destroy(FileVO file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('永久删除'),
        content: Text('确定永久删除「${file.filename}」吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await VaultService.instance.destroy(file.fileId);
      _toast('已永久删除');
      await _init();
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
      appBar: AppBar(
        title: const Text('隐私保险箱'),
        actions: [
          if (_status?.hasPassword == true && _status?.unlocked == true)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: '锁定',
              onPressed: _lock,
            ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }

    final status = _status;
    // 未设置密码
    if (status != null && !status.hasPassword) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 64),
            const SizedBox(height: 16),
            const Text('尚未设置保险箱密码'),
            const SizedBox(height: 24),
            FilledButton(onPressed: _setup, child: const Text('设置密码')),
          ],
        ),
      );
    }

    // 已设置密码但未解锁
    if (status != null && !status.unlocked) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64),
            const SizedBox(height: 16),
            const Text('保险箱已锁定'),
            const SizedBox(height: 24),
            FilledButton(onPressed: _unlock, child: const Text('解锁')),
          ],
        ),
      );
    }

    // 已解锁：显示文件列表
    if (_files.isEmpty) {
      return const Center(child: Text('保险箱为空'));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (ctx, i) {
        final file = _files[i];
        return ListTile(
          leading: FileTypeIcon(type: file.fileType),
          title: Text(file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            file.fileSizeDesc ?? translateFileSize(parseFileSize(file.fileSize)),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: '移出保险箱',
                onPressed: () => _moveOut(file),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: '永久删除',
                onPressed: () => _destroy(file),
              ),
            ],
          ),
        );
      },
    );
  }
}

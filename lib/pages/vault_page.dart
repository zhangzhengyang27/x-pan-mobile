import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/vault_service.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// 隐私保险箱页
class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

/// 深色渐变（neutral900 → brandPrimaryDark），营造保险箱的安全感
const LinearGradient _vaultGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppTokens.neutral900, AppTokens.brandPrimaryDark],
);

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
    final bool? result;
    final String password;
    try {
      result = await showDialog<bool>(
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
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
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
      password = ctrl.text;
    } finally {
      ctrl.dispose();
      confirmCtrl.dispose();
    }
    if (result != true) return;
    try {
      await VaultService.instance.setup(password);
      _toast('保险箱密码已设置');
      await _init();
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// 解锁
  Future<void> _unlock() async {
    final ctrl = TextEditingController();
    final String? password;
    try {
      password = await showDialog<String>(
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('解锁'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
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
      return const FileListSkeleton(itemCount: 4);
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: _error,
        actionLabel: '重试',
        actionIcon: Icons.refresh,
        onAction: _init,
      );
    }

    final status = _status;
    // 未设置密码
    if (status != null && !status.hasPassword) {
      return _buildGuardView(
        icon: Icons.security,
        title: '尚未设置保险箱密码',
        subtitle: '设置密码后，私密文件将被单独加密保护',
        actionLabel: '设置密码',
        onAction: _setup,
      );
    }

    // 已设置密码但未解锁
    if (status != null && !status.unlocked) {
      return _buildGuardView(
        icon: Icons.lock,
        title: '保险箱已锁定',
        subtitle: '输入密码以查看私密文件',
        actionLabel: '解锁',
        onAction: _unlock,
      );
    }

    // 已解锁：显示文件列表
    if (_files.isEmpty) {
      return const EmptyState(
        icon: Icons.lock_open_outlined,
        title: '保险箱为空',
        subtitle: '将私密文件移入保险箱即可受到保护',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      itemCount: _files.length,
      itemBuilder: (ctx, i) => _buildFile(_files[i]),
    );
  }

  /// 锁定 / 未设置密码态：深色渐变 + 盾牌 + 操作卡片
  Widget _buildGuardView({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      decoration: const BoxDecoration(gradient: _vaultGradient),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 盾牌图标（带光晕）
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTokens.neutral0.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTokens.neutral0.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, size: 44, color: AppTokens.neutral0),
              ),
              const SizedBox(height: AppTokens.space24),
              Text(
                title,
                style: AppTokens.headlineMedium.copyWith(
                  color: AppTokens.neutral0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                subtitle,
                style: AppTokens.bodyMedium.copyWith(
                  color: AppTokens.neutral0.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.space32),
              // 操作卡片按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.neutral0,
                    foregroundColor: AppTokens.brandPrimaryDark,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTokens.space14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusFull,
                      ),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: AppTokens.labelLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFile(FileVO file) {
    final brightness = Theme.of(context).brightness;
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      elevation: CardElevation.low,
      child: Row(
        children: [
          FileTypeIcon(type: file.fileType),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.titleMedium.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  file.fileSizeDesc ??
                      translateFileSize(parseFileSize(file.fileSize)),
                  style: AppTokens.bodySmall.copyWith(
                    color: AppTokens.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.logout,
              size: 20,
              color: AppTokens.textSecondary(brightness),
            ),
            tooltip: '移出保险箱',
            onPressed: () => _moveOut(file),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_forever,
              size: 20,
              color: AppTokens.error,
            ),
            tooltip: '永久删除',
            onPressed: () => _destroy(file),
          ),
        ],
      ),
    );
  }
}

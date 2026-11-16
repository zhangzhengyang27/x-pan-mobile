import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_list_item.dart';
import '../widgets/responsive.dart';
import 'device_page.dart';

/// 设置页（修改密码 / 设备管理）
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.space16),
          children: [
            // 顶部账号卡片
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppTokens.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTokens.shadowBrand(brightness),
                    ),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: AppTokens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user?.username ?? '未登录',
                          style: AppTokens.titleMedium.copyWith(
                            color: AppTokens.textPrimary(brightness),
                          ),
                        ),
                        if ((auth.user?.email ?? '').isNotEmpty) ...[
                          const SizedBox(height: AppTokens.space4),
                          Text(
                            auth.user!.email!,
                            style: AppTokens.bodySmall.copyWith(
                              color: AppTokens.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space24),
            _SettingsGroup(
              title: '账号',
              children: [
                AppListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: AppTokens.brandPrimary,
                  ),
                  title: (auth.user?.email ?? '').isEmpty ? '绑定邮箱' : '更换邮箱',
                  subtitle: (auth.user?.email ?? '').isEmpty
                      ? '绑定后可使用邮箱登录与找回账号'
                      : auth.user!.email!,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTokens.textTertiary(brightness),
                  ),
                  onTap: _bindEmail,
                ),
                AppListTile(
                  leading: const Icon(
                    Icons.lock_outline,
                    color: AppTokens.brandPrimary,
                  ),
                  title: '修改密码',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTokens.textTertiary(brightness),
                  ),
                  onTap: _changePassword,
                ),
                AppListTile(
                  leading: const Icon(
                    Icons.devices,
                    color: AppTokens.brandPrimary,
                  ),
                  title: '登录设备',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTokens.textTertiary(brightness),
                  ),
                  onTap: () => Navigator.of(context).push(
                    AppTokens.route(const DevicePage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space24),
            AppCard(
              padding: EdgeInsets.zero,
              elevation: CardElevation.low,
              child: AppListItem(
                onTap: _logout,
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: AppTokens.error),
                    const SizedBox(width: AppTokens.space12),
                    Text(
                      '退出登录',
                      style: AppTokens.bodyLarge.copyWith(
                        color: AppTokens.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // 通知停已收敛进 AuthNotifier.logout()（路由守卫会自动跳回登录页）
    await ref.read(authProvider.notifier).logout();
  }

  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final bool? result;
    final String oldPassword;
    final String newPassword;
    try {
      result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('修改密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '旧密码'),
              ),
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码（8-16位）'),
              ),
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认新密码'),
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
                if (newCtrl.text.length < 8 || newCtrl.text.length > 16) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('新密码长度需为 8-16 位')),
                  );
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('两次输入的新密码不一致')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
      oldPassword = oldCtrl.text;
      newPassword = newCtrl.text;
    } finally {
      oldCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
    if (result != true) return;
    try {
      await UserService.instance.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      _toast('密码修改成功');
      // 修改密码后重新登录（通知停已收敛进 logout）
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _bindEmail() async {
    final auth = ref.read(authProvider);
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _BindEmailDialog(currentEmail: auth.user?.email ?? ''),
    );
    if (updated == true) {
      await ref.read(authProvider.notifier).refreshUser();
      _toast('邮箱已绑定，可使用邮箱登录');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 设置分组：小标题 + 卡片包裹多个列表项（中间分割线）
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTokens.space4,
            bottom: AppTokens.space8,
          ),
          child: Text(
            title,
            style: AppTokens.bodySmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          elevation: CardElevation.low,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 0.5,
                    indent: AppTokens.space16,
                    endIndent: AppTokens.space16,
                    color: AppTokens.divider(brightness),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 绑定/更换邮箱弹窗
class _BindEmailDialog extends StatefulWidget {
  const _BindEmailDialog({required this.currentEmail});

  final String currentEmail;

  @override
  State<_BindEmailDialog> createState() => _BindEmailDialogState();
}

class _BindEmailDialogState extends State<_BindEmailDialog> {
  static final _emailPattern =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _saving = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.currentEmail;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      _toast('请输入正确的邮箱地址');
      return;
    }
    if (_sending || _countdown > 0) return;
    setState(() => _sending = true);
    try {
      await UserService.instance.sendEmailCode(email: email, scene: 'BIND');
      if (!mounted) return;
      _toast('验证码已发送，请查收邮箱');
      setState(() => _countdown = 60);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _countdown -= 1;
          if (_countdown <= 0) timer.cancel();
        });
      });
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      _toast('请输入正确的邮箱地址');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _toast('请输入 6 位邮箱验证码');
      return;
    }
    setState(() => _saving = true);
    try {
      await UserService.instance.bindEmail(email: email, code: code);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AlertDialog(
      title: const Text('邮箱设置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.currentEmail.isEmpty
                ? '当前未绑定邮箱，绑定后可使用邮箱登录。'
                : '当前邮箱：${widget.currentEmail}',
            style: AppTokens.bodySmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: '邮箱'),
          ),
          const SizedBox(height: AppTokens.space12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6 位验证码',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              TextButton(
                onPressed: _countdown > 0 || _sending ? null : _sendCode,
                child: Text(
                  _countdown > 0
                      ? '${_countdown}s'
                      : _sending
                          ? '发送中…'
                          : '获取验证码',
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
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
    // 停止实时通知并断开连接（路由守卫会自动跳回登录页）
    ref.read(notificationProvider.notifier).stop();
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
      // 修改密码后重新登录
      ref.read(notificationProvider.notifier).stop();
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      _toast(e.toString());
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

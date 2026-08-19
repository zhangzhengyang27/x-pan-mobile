import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_header.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(
            _usernameCtrl.text.trim(),
            _passwordCtrl.text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space24,
                  vertical: AppTokens.space32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 品牌区
                    const Center(child: BrandLogoBadge(size: 72)),
                    const SizedBox(height: AppTokens.space20),
                    Text(
                      'X Pan',
                      textAlign: TextAlign.center,
                      style: AppTokens.displayMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTokens.textPrimary(brightness),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Text(
                      '个人分布式存储 · 安全 · 高速 · 无界',
                      textAlign: TextAlign.center,
                      style: AppTokens.bodyMedium.copyWith(
                        color: AppTokens.textSecondary(brightness),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space40),

                    // 表单卡片
                    Container(
                      padding: const EdgeInsets.all(AppTokens.space24),
                      decoration: BoxDecoration(
                        color: AppTokens.surface(brightness),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusXl),
                        boxShadow: AppTokens.shadowMd(brightness),
                        border: Border.all(
                          color: AppTokens.divider(brightness),
                          width: 0.5,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '欢迎回来',
                              style: AppTokens.headlineMedium.copyWith(
                                color: AppTokens.textPrimary(brightness),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '登录以继续访问你的云盘',
                              style: AppTokens.bodySmall.copyWith(
                                color: AppTokens.textSecondary(brightness),
                              ),
                            ),
                            const SizedBox(height: AppTokens.space24),
                            TextFormField(
                              controller: _usernameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '用户名',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? '请输入用户名'
                                  : null,
                            ),
                            const SizedBox(height: AppTokens.space16),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: '密码',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? '请输入密码'
                                  : null,
                            ),
                            const SizedBox(height: AppTokens.space24),
                            _buildLoginButton(brightness),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            AppTokens.route(const RegisterPage()),
                          ),
                          child: Text(
                            '没有账号？去注册',
                            style: AppTokens.bodyMedium.copyWith(
                              color: AppTokens.brandPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '·',
                          style: AppTokens.bodyMedium.copyWith(
                            color: AppTokens.textTertiary(brightness),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            AppTokens.route(const ForgotPasswordPage()),
                          ),
                          child: Text(
                            '忘记密码？',
                            style: AppTokens.bodyMedium.copyWith(
                              color: AppTokens.textSecondary(brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(Brightness brightness) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        boxShadow: _loading ? [] : AppTokens.shadowBrand(brightness),
      ),
      child: FilledButton(
        onPressed: _loading ? null : _submit,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppTokens.brandPrimary,
          disabledBackgroundColor: AppTokens.brandPrimary.withValues(alpha: 0.5),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                '登录',
                style: AppTokens.labelLarge.copyWith(
                  fontSize: 16,
                  letterSpacing: 4,
                ),
              ),
      ),
    );
  }
}

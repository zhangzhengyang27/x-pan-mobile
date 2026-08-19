import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/user_service.dart';
import '../widgets/gradient_header.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await UserService.instance.register(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请登录')),
        );
        Navigator.of(context).pop();
      }
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
      appBar: AppBar(title: const Text('注册')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space24,
              vertical: AppTokens.space24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 品牌区
                  const Center(child: BrandLogoBadge(size: 56)),
                  const SizedBox(height: AppTokens.space16),
                  Text(
                    '创建账号',
                    textAlign: TextAlign.center,
                    style: AppTokens.headlineLarge.copyWith(
                      color: AppTokens.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    '加入 X-Pan，开启你的云端空间',
                    textAlign: TextAlign.center,
                    style: AppTokens.bodyMedium.copyWith(
                      color: AppTokens.textSecondary(brightness),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),

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
                          TextFormField(
                            controller: _usernameCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '用户名（6-16位字母或数字）',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) {
                              if (v == null ||
                                  !RegExp(r'^[0-9A-Za-z]{6,16}$').hasMatch(v)) {
                                return '用户名需为 6-16 位字母或数字';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTokens.space16),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: '密码（8-16位）',
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
                            validator: (v) {
                              if (v == null || v.length < 8 || v.length > 16) {
                                return '密码长度需为 8-16 位';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTokens.space16),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscure,
                            decoration: const InputDecoration(
                              labelText: '确认密码',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) =>
                                v != _passwordCtrl.text ? '两次输入的密码不一致' : null,
                          ),
                          const SizedBox(height: AppTokens.space16),
                          TextFormField(
                            controller: _emailCtrl,
                            textInputAction: TextInputAction.done,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: '邮箱（可选）',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: AppTokens.space24),
                          _buildSubmitButton(brightness),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Brightness brightness) {
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
          disabledBackgroundColor:
              AppTokens.brandPrimary.withValues(alpha: 0.5),
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
                '注 册',
                style: AppTokens.labelLarge.copyWith(
                  fontSize: 16,
                  letterSpacing: 4,
                ),
              ),
      ),
    );
  }
}

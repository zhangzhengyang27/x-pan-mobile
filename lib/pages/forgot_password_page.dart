import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/user_service.dart';
import '../widgets/gradient_header.dart';

/// 忘记密码页
///
/// 流程：用户名 + 密保答案校验 → 重置密码
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _usernameCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _answerCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final answer = _answerCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;
    if (username.isEmpty || answer.isEmpty) {
      _toast('请填写用户名和密保答案');
      return;
    }
    if (newPassword.length < 8 || newPassword.length > 16) {
      _toast('新密码长度需为 8-16 位');
      return;
    }
    if (newPassword != _confirmCtrl.text) {
      _toast('两次输入的新密码不一致');
      return;
    }

    setState(() => _loading = true);
    try {
      // 第一步：校验密保答案
      await UserService.instance.checkAnswer(
        username: username,
        answer: answer,
      );
      // 第二步：重置密码
      await UserService.instance.resetPassword(
        username: username,
        answer: answer,
        newPassword: newPassword,
      );
      _toast('密码重置成功，请登录');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(title: const Text('忘记密码')),
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
                    '找回密码',
                    textAlign: TextAlign.center,
                    style: AppTokens.headlineLarge.copyWith(
                      color: AppTokens.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    '通过密保问题重置你的账号密码',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '填写用户名与注册时设置的密保答案，验证通过后可设置新密码。',
                          style: AppTokens.bodySmall.copyWith(
                            color: AppTokens.textSecondary(brightness),
                          ),
                        ),
                        const SizedBox(height: AppTokens.space24),
                        TextField(
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: AppTokens.space16),
                        TextField(
                          controller: _answerCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '密保答案',
                            prefixIcon: Icon(Icons.question_answer_outlined),
                          ),
                        ),
                        const SizedBox(height: AppTokens.space16),
                        TextField(
                          controller: _newPasswordCtrl,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '新密码（8-16位）',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: AppTokens.space16),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: '确认新密码',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: AppTokens.space24),
                        _buildSubmitButton(brightness),
                      ],
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
                '重置密码',
                style: AppTokens.labelLarge.copyWith(
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }
}

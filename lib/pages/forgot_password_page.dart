import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/user_service.dart';
import '../widgets/responsive.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('忘记密码')),
      body: ResponsiveContent(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _answerCtrl,
                    decoration: const InputDecoration(
                      labelText: '密保答案',
                      prefixIcon: Icon(Icons.question_answer_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '新密码（8-16位）',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '确认新密码',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('重置密码'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

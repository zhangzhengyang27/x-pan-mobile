import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/llm_service.dart';
import '../services/user_service.dart';

/// AI 助手页
///
/// 对齐网页版 useAIAssistant：意图识别（关键词预判 + LLM 兜底）
/// + 执行（search / summarize / rename / chat）。
class AIAssistantPage extends ConsumerStatefulWidget {
  const AIAssistantPage({super.key});

  @override
  ConsumerState<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _ChatMsg {
  const _ChatMsg({required this.role, required this.content});

  final String role; // user / assistant
  final String content;
}

class _AIAssistantPageState extends ConsumerState<AIAssistantPage> {
  final _inputCtrl = TextEditingController();
  final List<_ChatMsg> _messages = [];
  bool _loading = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureConfig() async {
    final configured = await LLMService.instance.isConfigured();
    if (configured) return;
    if (!mounted) return;

    final ctrl = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('配置 DeepSeek API Key'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'sk-...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (key != null && key.isNotEmpty) {
      await LLMService.instance.setApiKey(key);
    }
  }

  Future<void> _send() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add(_ChatMsg(role: 'user', content: input));
      _loading = true;
    });

    try {
      await _ensureConfig();
      final reply = await _run(input);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(role: 'assistant', content: reply));
        });
      }
    } on LlmInvalidKeyException catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(role: 'assistant', content: e.message));
        });
      }
      // 引导重新配置 API Key
      await _ensureConfig();
    } on LlmNotConfiguredException catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(role: 'assistant', content: e.message));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(role: 'assistant', content: '出错了：$e'));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 主入口：识别意图 + 执行
  Future<String> _run(String input) async {
    final intent = await _detectIntent(input);
    switch (intent) {
      case 'search':
        return _executeSearch(input);
      case 'chat':
      default:
        return _executeChat(input);
    }
  }

  /// 意图识别（关键词预判 + LLM 兜底）
  Future<String> _detectIntent(String input) async {
    final text = input.trim().toLowerCase();
    // 关键词预判
    if (RegExp(r'^(找|搜索|查|搜|查找|列出|显示|有哪些|看看)').hasMatch(text) ||
        RegExp(r'(文件|图片|视频|音乐|文档|文件夹|上周|昨天|今天|本周|本月|最近|大于|小于|超过)')
            .hasMatch(text)) {
      return 'search';
    }
    // LLM 兜底
    try {
      final raw = await LLMService.instance.chat(
        [
          const LLMMessage(
            role: 'system',
            content:
                '你是网盘 AI 助手的意图识别模块。判断用户输入意图，输出 JSON（不要 markdown 代码块）。意图类型：search（搜索文件）、chat（闲聊）。输出格式：{"intent":"search|chat"}',
          ),
          LLMMessage(role: 'user', content: input),
        ],
        temperature: 0.1,
      );
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (match != null) {
        final parsed = jsonDecode(match.group(0)!);
        final intent = parsed['intent']?.toString();
        if (intent == 'search') return 'search';
      }
    } catch (_) {
      // 忽略，默认 chat
    }
    return 'chat';
  }

  /// 执行搜索意图
  Future<String> _executeSearch(String input) async {
    // LLM 解析自然语言为搜索参数
    var keyword = input;
    String? fileTypes;
    String? dateFrom;
    String? dateTo;
    num? sizeMin;
    num? sizeMax;

    try {
      final raw = await LLMService.instance.chat(
        [
          LLMMessage(
            role: 'system',
            content:
                '你是网盘搜索助手。将用户自然语言搜索请求解析为 JSON（不要 markdown 代码块）。字段：keyword（文件名关键词）、fileType（0=文件夹,7=图片,8=音频,9=视频,3/4/10=文档，不确定填-1）、dateFrom、dateTo（YYYY-MM-DD）、sizeMinMB、sizeMaxMB。',
          ),
          LLMMessage(role: 'user', content: input),
        ],
        temperature: 0.1,
      );
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (match != null) {
        final parsed = jsonDecode(match.group(0)!);
        if (parsed is Map) {
          if (parsed['keyword'] != null && parsed['keyword'].toString().isNotEmpty) {
            keyword = parsed['keyword'].toString();
          }
          final ft = parsed['fileType'];
          if (ft != null && ft != -1) fileTypes = ft.toString();
          if (parsed['dateFrom'] != null) dateFrom = parsed['dateFrom'].toString();
          if (parsed['dateTo'] != null) dateTo = parsed['dateTo'].toString();
          if (parsed['sizeMinMB'] != null) {
            sizeMin = (parsed['sizeMinMB'] as num) * 1024 * 1024;
          }
          if (parsed['sizeMaxMB'] != null) {
            sizeMax = (parsed['sizeMaxMB'] as num) * 1024 * 1024;
          }
        }
      }
    } catch (_) {
      // 解析失败，退化为纯关键词搜索
    }

    final results = await FileService.instance.search(
      keyword: keyword,
      fileTypes: fileTypes,
      dateFrom: dateFrom,
      dateTo: dateTo,
      sizeMin: sizeMin,
      sizeMax: sizeMax,
    );

    if (results.isEmpty) {
      return '🔍 已为你搜索「$input」\n\n没有找到匹配的文件。';
    }
    final lines = results
        .take(10)
        .map((r) => '${results.indexOf(r) + 1}. ${r.filename}')
        .join('\n');
    final suffix = results.length > 10 ? '\n\n（仅显示前 10 个，共 ${results.length} 个结果）' : '';
    return '🔍 已为你搜索「$input」\n\n找到 ${results.length} 个结果：\n$lines$suffix';
  }

  /// 执行闲聊意图
  Future<String> _executeChat(String input) async {
    final history = _messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .toList();
    final messages = <LLMMessage>[
      const LLMMessage(
        role: 'system',
        content:
            '你是 X-Pan 网盘的 AI 助手。你熟悉文件管理、网盘使用，可以帮用户搜索文件、整理文件夹、建议命名。回答简洁友好，使用中文。',
      ),
      ...history.take(6).map(
            (m) => LLMMessage(role: m.role, content: m.content),
          ),
    ];
    return LLMService.instance.chat(messages, temperature: 0.7);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '配置 API Key',
            onPressed: () async {
              final ctrl = TextEditingController(
                text: await LLMService.instance.getApiKey(),
              );
              final key = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('配置 DeepSeek API Key'),
                  content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(labelText: 'API Key'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              );
              if (key != null) {
                await LLMService.instance.setApiKey(key);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      '我是 X-Pan AI 助手\n可以帮你搜索文件、整理文件夹\n试试输入「找上周的图片」',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      return _buildBubble(msg);
                    },
                  ),
          ),
          // 输入栏
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '输入指令，如「找上周的图片」',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _loading ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMsg msg) {
    final isUser = msg.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Text(
          msg.content,
          style: TextStyle(
            color: isUser ? scheme.onPrimary : scheme.onSurface,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

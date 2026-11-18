import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/config/app_config.dart';
import '../core/network/http_client.dart';
import '../core/theme/app_tokens.dart';
import '../models/chat_vo.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/chat_service.dart';

/// 聊天窗：文本 / 图片 / 文件卡片（转存）/ 语音条（录制+播放）+ emoji
/// 消息实时来自 chatProvider（WS CHAT_NEW 增量），撤回/转发走 provider
class ChatDetailPage extends ConsumerStatefulWidget {
  const ChatDetailPage({super.key, required this.conversationId});

  final int conversationId;

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final ChatService _service = ChatService.instance;
  final TextEditingController _draftCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  bool _sending = false;
  String _myUsername = '';
  String _myUserId = '';

  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _showEmoji = false;

  final List<String> _emojiList = const [
    '😀', '😂', '🤝', '👍', '🎉', '🔥', '❤️', '🙏', '😮', '😢', '🚀', '✅'
  ];

  @override
  void initState() {
    super.initState();
    _myUsername = ref.read(authProvider).user?.username ?? '';
    _myUserId = ref.read(authProvider).user?.userId ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatNotifierProvider.notifier).loadMessages(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _draftCtrl.dispose();
    _scrollCtrl.dispose();
    _player.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final messages =
        ref.read(chatNotifierProvider).messagesByConv[widget.conversationId];
    if (messages == null || messages.isEmpty) return;
    try {
      await _service.markRead(widget.conversationId, messages.last.seq);
    } catch (_) {
      // 已读失败不阻塞
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send(Future<void> Function() action) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await action();
      _markRead();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('发送失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText() async {
    final content = _draftCtrl.text.trim();
    if (content.isEmpty) return;
    _draftCtrl.clear();
    if (mounted) setState(() => _showEmoji = false);
    await _send(() => ref
        .read(chatNotifierProvider.notifier)
        .send(widget.conversationId, 'TEXT', content: content));
  }

  Future<void> _sendImage() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    await _send(() async {
      final mediaId = await _service.uploadMedia(MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
      ));
      await ref.read(chatNotifierProvider.notifier).send(
          widget.conversationId, 'IMAGE',
          mediaId: mediaId);
    });
  }

  /// 文件卡片：从我的网盘选择文件（加密 fileId 直传，接收方转存走配额校验）
  Future<void> _sendFileCard() async {
    try {
      final dio = HttpClient.instance.dio;
      final response = await dio.request<dynamic>('/file/search',
          queryParameters: {'keyword': '', 'fileTypes': '-1'},
          options: Options(method: 'GET'));
      final map = response.data as Map<String, dynamic>;
      final records = (map['data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((f) => (f['folderFlag'] as num? ?? 1) == 0)
          .toList();
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择要发送的网盘文件'),
          children: records
              .map((f) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, f),
                    child: Text(
                        '${f['filename'] ?? ''}  ${f['fileSizeDesc'] ?? ''}',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        ),
      );
      if (selected == null) return;
      final fileId = selected['fileId'] as String? ?? '';
      final filename = selected['filename'] as String? ?? '';
      await _send(() => ref.read(chatNotifierProvider.notifier).send(
          widget.conversationId, 'FILE_CARD',
          fileId: fileId, content: filename));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('文件列表加载失败：$e')));
      }
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      _recordTimer?.cancel();
      if (mounted) setState(() => _recording = false);
      if (path == null) return;
      final seconds = _recordSeconds;
      await _send(() async {
        final mediaId = await _service.uploadMedia(
            await MultipartFile.fromFile(path, filename: 'voice.m4a'));
        await ref.read(chatNotifierProvider.notifier).send(
            widget.conversationId, 'VOICE',
            mediaId: mediaId, content: '${seconds * 1000}');
      });
      return;
    }
    try {
      if (await _recorder.hasPermission()) {
        final docsDir = await getApplicationDocumentsDirectory();
        final path =
            '${docsDir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        if (mounted) setState(() => _recording = true);
        _recordSeconds = 0;
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordSeconds++);
            if (_recordSeconds >= 60) _toggleRecord();
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('需要麦克风权限')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('录音不可用：$e')));
      }
    }
  }

  Future<void> _playVoice(int mediaId) async {
    try {
      await _player.setUrl('${AppConfig.apiBaseUrl}/chat/media/$mediaId');
      await _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('播放失败：$e')));
      }
    }
  }

  Future<void> _recall(ChatMessageVO message) async {
    await ref.read(chatNotifierProvider.notifier).recall(message);
  }

  Future<void> _forward(ChatMessageVO message) async {
    if (!mounted) return;
    final conversations = ref.read(chatNotifierProvider).conversations;
    final targets = <int>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('转发到…（可多选）'),
          content: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: conversations
                  .where((c) => c.conversationId != widget.conversationId)
                  .map((c) => CheckboxListTile(
                        dense: true,
                        title: Text(c.displayName),
                        value: targets.contains(c.conversationId),
                        onChanged: (checked) {
                          setDialogState(() {
                            checked == true
                                ? targets.add(c.conversationId)
                                : targets.remove(c.conversationId);
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: targets.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text('转发（${targets.length}）'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && targets.isNotEmpty) {
      await ref
          .read(chatNotifierProvider.notifier)
          .forward(message, targets.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已转发到 ${targets.length} 个会话')));
      }
    }
  }

  Future<void> _transfer(ChatMessageVO message) async {
    try {
      final dio = HttpClient.instance.dio;
      final response = await dio.request<dynamic>('/file/transfer',
          data: {
            'fileIds': [message.fileId],
            'targetParentId': '-1'
          },
          options: Options(method: 'POST'));
      final map = response.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(map['code'] == 0
              ? '已转存到我的网盘'
              : '转存失败：${map['message']}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('转存失败：$e')));
      }
    }
  }

  void _showActions(ChatMessageVO message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.recallable)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('撤回'),
                onTap: () {
                  Navigator.pop(ctx);
                  _recall(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.shortcut),
              title: const Text('转发'),
              onTap: () {
                Navigator.pop(ctx);
                _forward(message);
              },
            ),
            if (message.msgType == 'FILE_CARD')
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('转存到我的网盘'),
                onTap: () {
                  Navigator.pop(ctx);
                  _transfer(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      chatNotifierProvider
          .select((s) => s.messagesByConv[widget.conversationId]?.length),
      (_, __) => _scrollToBottom(),
    );
    final chatState = ref.watch(chatNotifierProvider);
    final messages =
        chatState.messagesByConv[widget.conversationId] ??
            const <ChatMessageVO>[];
    final loading = !chatState.messagesByConv.containsKey(widget.conversationId);
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(title: const Text('聊天')),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('还没有消息'))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = _myUserId.isNotEmpty
                              ? message.senderId == _myUserId
                              : message.senderUsername == _myUsername;
                          if (message.msgType == 'SYSTEM') {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Center(
                                child: Text(message.content,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ),
                            );
                          }
                          return GestureDetector(
                            onLongPress: message.status == 'SENT'
                                ? () => _showActions(message)
                                : null,
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.72),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppTokens.brandPrimary
                                      : (brightness == Brightness.dark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (message.status == 'RECALLED')
                                      Text('消息已撤回',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: isMe
                                                  ? Colors.white70
                                                  : Colors.grey)),
                                    if (message.status != 'RECALLED')
                                      ..._buildBody(message, isMe),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Container(
              color: brightness == Brightness.dark
                  ? Colors.grey.shade900
                  : Colors.grey.shade100,
              child: Column(
                children: [
                  if (_showEmoji)
                    Container(
                      padding: const EdgeInsets.all(6),
                      height: 96,
                      child: GridView.count(
                        crossAxisCount: 8,
                        children: _emojiList
                            .map((e) => IconButton(
                                  icon: Text(e,
                                      style: const TextStyle(fontSize: 20)),
                                  onPressed: () => _draftCtrl.text += e,
                                ))
                            .toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image_outlined),
                          onPressed: _sending ? null : _sendImage,
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file),
                          onPressed: _sending ? null : _sendFileCard,
                        ),
                        IconButton(
                          icon: Icon(
                            _recording ? Icons.mic : Icons.mic_none,
                            color: _recording ? Colors.red : null,
                          ),
                          onPressed: _sending ? null : _toggleRecord,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color:
                                _showEmoji ? AppTokens.brandPrimary : null,
                          ),
                          onPressed: () =>
                              setState(() => _showEmoji = !_showEmoji),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _draftCtrl,
                            maxLines: 1,
                            decoration: const InputDecoration(
                              hintText: '输入消息…',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _sending ? null : _sendText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBody(ChatMessageVO message, bool isMe) {
    final textColor = isMe ? Colors.white : null;
    switch (message.msgType) {
      case 'IMAGE':
        return [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              '${AppConfig.apiBaseUrl}/chat/media/${message.mediaId}',
              width: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Text('[图片加载失败]'),
            ),
          ),
        ];
      case 'VOICE':
        return [
          InkWell(
            onTap: () => _playVoice(message.mediaId),
            child: SizedBox(
              width: 160,
              child: Row(
                children: [
                  Icon(Icons.play_circle_filled, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                      '语音条 ${(int.tryParse(message.content) ?? 0) / 1000}s',
                      style: TextStyle(fontSize: 13, color: textColor)),
                ],
              ),
            ),
          ),
        ];
      case 'FILE_CARD':
        return [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file, color: textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message.fileCardName.isNotEmpty
                      ? message.fileCardName
                      : message.content,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          ),
        ];
      default:
        return [Text(message.content, style: TextStyle(color: textColor))];
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/http_client.dart';
import '../core/theme/app_tokens.dart';
import '../models/file_edit.dart';
import '../models/file_vo.dart';
import '../services/user_service.dart';
import '../widgets/empty_state.dart';

/// Markdown / TXT 在线编辑页
///
/// - 进入时申请编辑锁，离开/销毁时释放
/// - 保存走 PUT /file/content（multipart），baseVersion 乐观锁
/// - 版本冲突时提示加载最新内容，避免覆盖他人修改
class TextEditPage extends StatefulWidget {
  const TextEditPage({super.key, required this.file});

  final FileVO file;

  @override
  State<TextEditPage> createState() => _TextEditPageState();
}

class _TextEditPageState extends State<TextEditPage> {
  final TextEditingController _controller = TextEditingController();

  FileDetail? _detail;
  String _savedText = '';
  String _lockToken = '';
  int _version = 1;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  bool _locked = false;
  bool _unsupported = false;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _bootstrap();
  }

  void _onChanged() {
    final dirty = _controller.text != _savedText;
    if (dirty != _dirty) {
      setState(() => _dirty = dirty);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _locked = false;
      _unsupported = false;
    });
    try {
      final detail = await FileService.instance.getDetail(widget.file.fileId);
      if (!detail.editable) {
        setState(() {
          _loading = false;
          _unsupported = true;
          _error = '该文件类型暂不支持在线编辑';
        });
        return;
      }
      try {
        final session =
            await FileService.instance.acquireEditSession(widget.file.fileId);
        _lockToken = session.lockToken;
        _version = session.version;
        _startHeartbeat();
      } on ApiException catch (e) {
        if (e.code == 423) {
          setState(() {
            _loading = false;
            _locked = true;
            _error = e.message;
          });
          return;
        }
        rethrow;
      }

      final text = await FileService.instance.fetchRawText(widget.file.fileId);
      _detail = detail;
      _savedText = text;
      _controller.text = text;
      if (mounted) {
        setState(() {
          _loading = false;
          _dirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? e.message : e.toString();
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final content = _controller.text;
    setState(() => _saving = true);
    try {
      final result = await FileService.instance.saveContent(
        fileId: widget.file.fileId,
        baseVersion: _version,
        content: content,
        filename: _detail?.filename ?? widget.file.filename,
      );
      _version = result.version;
      _savedText = content;
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 409) {
        await _handleConflict();
      } else if (e.code == 423) {
        setState(() {
          _locked = true;
          _error = e.message;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 版本冲突：加载最新内容（丢弃本地修改）或保留本地修改
  Future<void> _handleConflict() async {
    final reload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存冲突'),
        content: const Text('文件已被其他端修改。加载最新内容会丢弃你当前的未保存修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('保留我的修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('加载最新内容'),
          ),
        ],
      ),
    );
    if (reload != true) return;
    try {
      final detail = await FileService.instance.getDetail(widget.file.fileId);
      final text = await FileService.instance.fetchRawText(widget.file.fileId);
      _detail = detail;
      _version = detail.version;
      _savedText = text;
      _controller.text = text;
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已加载最新内容')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载最新内容失败：$e')),
        );
      }
    }
  }

  /// 编辑锁心跳：同一用户重复申请会续期
  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final session =
            await FileService.instance.acquireEditSession(widget.file.fileId);
        _lockToken = session.lockToken;
      } catch (_) {
        // 网络异常时等待下一次心跳；锁过期后保存仍受版本冲突保护
      }
    });
  }

  void _releaseLock() {
    _heartbeat?.cancel();
    _heartbeat = null;
    if (_lockToken.isEmpty) return;
    final token = _lockToken;
    _lockToken = '';
    FileService.instance
        .releaseEditSession(fileId: widget.file.fileId, lockToken: token)
        .catchError((_) => null);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('当前修改尚未保存，确定离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('离开'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  void dispose() {
    _releaseLock();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) {
          _releaseLock();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.file.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                _dirty ? 'v$_version · 未保存' : 'v$_version',
                style: TextStyle(
                  fontSize: 11,
                  color: _dirty ? AppTokens.warning : AppTokens.neutral400,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '保存',
              onPressed: _loading || _saving || !_dirty ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: _buildBody(brightness),
      ),
    );
  }

  Widget _buildBody(Brightness brightness) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: _locked
            ? Icons.lock_outline
            : _unsupported
                ? Icons.edit_off_outlined
                : Icons.error_outline,
        title: _locked
            ? '暂时无法编辑'
            : _unsupported
                ? '暂不支持编辑'
                : '加载失败',
        subtitle: _error,
        actionLabel: _locked ? '重试' : null,
        onAction: _locked ? _bootstrap : null,
        actionIcon: Icons.refresh,
      );
    }
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space12),
            child: TextField(
              controller: _controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.55,
                color: AppTokens.textPrimary(brightness),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTokens.surface(brightness),
                contentPadding: const EdgeInsets.all(AppTokens.space16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  borderSide: BorderSide(
                    color: AppTokens.divider(brightness).withValues(alpha: 0.6),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  borderSide: BorderSide(
                    color: AppTokens.divider(brightness).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

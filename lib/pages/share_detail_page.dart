import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../models/file_vo.dart';
import '../services/share_service.dart';
import '../utils/format.dart';
import '../widgets/folder_picker_dialog.dart';

/// 分享详情页
///
/// 流程：简单详情 → 提取码验证（如需）→ 分享文件列表 → 保存到网盘
class ShareDetailPage extends ConsumerStatefulWidget {
  const ShareDetailPage({super.key, required this.shareId});

  final String shareId;

  @override
  ConsumerState<ShareDetailPage> createState() => _ShareDetailPageState();
}

class _ShareDetailPageState extends ConsumerState<ShareDetailPage> {
  ShareDetail? _detail;
  String? _shareToken;
  String? _error;
  bool _loading = true;
  bool _needCode = false;

  final Set<String> _selectedIds = {};

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
      // 1. 简单详情（预热，若失败不阻塞主流程）
      try {
        await ShareService.instance.simpleDetail(widget.shareId);
      } catch (_) {
        // 简单详情失败不影响后续
      }

      // 2. 尝试直接获取详情（无需提取码时）
      final savedToken = await TokenStorage.getShareToken();
      final token = savedToken.isNotEmpty ? savedToken : '';
      try {
        final detail = await ShareService.instance.detail(token);
        if (mounted) {
          setState(() {
            _detail = detail;
            _shareToken = token;
          });
        }
      } on ApiException catch (e) {
        // code == 4 需要提取码
        if (e.code == 4) {
          if (mounted) setState(() => _needCode = true);
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 提取码验证
  Future<void> _verifyCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('请输入提取码'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '提取码'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    try {
      final token = await ShareService.instance.checkShareCode(
        shareId: widget.shareId,
        shareCode: code,
      );
      await TokenStorage.setShareToken(token);
      final detail = await ShareService.instance.detail(token);
      if (mounted) {
        setState(() {
          _shareToken = token;
          _detail = detail;
          _needCode = false;
        });
      }
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// 保存选中文件到网盘
  Future<void> _save() async {
    final files = _detail!.files.where((f) => _selectedIds.contains(f.fileId)).toList();
    if (files.isEmpty) {
      _toast('请先选择要保存的文件');
      return;
    }
    final targetId = await showFolderPickerDialog(
      context,
      title: '保存到',
      confirmText: '保存到此处',
    );
    if (targetId == null) return;

    final fileIds = files.map((f) => f.fileId).toList();
    try {
      await ShareService.instance.save(
        fileIds: fileIds,
        targetParentId: targetId,
        shareToken: _shareToken!,
      );
      _toast('保存成功');
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toggleSelect(FileVO file) {
    setState(() {
      if (_selectedIds.contains(file.fileId)) {
        _selectedIds.remove(file.fileId);
      } else {
        _selectedIds.add(file.fileId);
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分享详情')),
      body: _buildBody(),
      floatingActionButton: _detail != null
          ? FloatingActionButton.extended(
              onPressed: _save,
              icon: const Icon(Icons.save_alt),
              label: const Text('保存到网盘'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }
    if (_needCode) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 16),
            const Text('该分享需要提取码'),
            const SizedBox(height: 24),
            FilledButton(onPressed: _verifyCode, child: const Text('输入提取码')),
          ],
        ),
      );
    }
    if (_detail == null) {
      return const Center(child: Text('暂无内容'));
    }

    final detail = _detail!;
    return ListView(
      children: [
        // 分享头部信息
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      detail.shareUserInfo.username.isNotEmpty
                          ? detail.shareUserInfo.username[0]
                          : '?',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.shareUserInfo.username,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '分享于 ${detail.createTime}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                detail.shareName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 文件列表（多选）
        ...detail.files.map((file) => _buildFileTile(file)),
      ],
    );
  }

  Widget _buildFileTile(FileVO file) {
    final selected = _selectedIds.contains(file.fileId);
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      leading: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        file.isFolder
            ? '文件夹'
            : file.fileSizeDesc ?? translateFileSize(parseFileSize(file.fileSize)),
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => _toggleSelect(file),
    );
  }
}

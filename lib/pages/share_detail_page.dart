import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/share_service.dart';
import '../utils/format.dart';
import '../widgets/app_list_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

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
    final String? code;
    try {
      code = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('请输入提取码'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: '提取码'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
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
      body: ResponsiveContent(child: _buildBody()),
      bottomNavigationBar: _detail != null ? _buildSaveBar() : null,
    );
  }

  /// 底部“保存到我的网盘”按钮（品牌光晕）
  Widget _buildSaveBar() {
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            boxShadow: AppTokens.shadowBrand(brightness),
          ),
          child: FilledButton.icon(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppTokens.brandPrimary,
            ),
            icon: const Icon(Icons.save_alt),
            label: Text(
              _selectedIds.isEmpty
                  ? '保存到我的网盘'
                  : '保存到我的网盘（${_selectedIds.length}）',
              style: AppTokens.labelLarge,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const FileListSkeleton(itemCount: 6);
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: '加载失败',
        subtitle: _error,
        actionLabel: '重试',
        actionIcon: Icons.refresh,
        onAction: _init,
      );
    }
    if (_needCode) {
      return Center(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: '该分享需要提取码',
          subtitle: '输入提取码后即可查看分享内容',
          actionLabel: '输入提取码',
          onAction: _verifyCode,
        ),
      );
    }
    if (_detail == null) {
      return const EmptyState(
        icon: Icons.link_off,
        title: '暂无内容',
        subtitle: '分享可能已失效',
      );
    }

    final detail = _detail!;
    return ListView(
      children: [
        // 渐变头部：分享名 + 分享者 + 创建时间
        Container(
          decoration: const BoxDecoration(gradient: AppTokens.brandGradient),
          padding: const EdgeInsets.all(AppTokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.shareName,
                style: AppTokens.headlineMedium.copyWith(
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTokens.space12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      detail.shareUserInfo.username.isNotEmpty
                          ? detail.shareUserInfo.username[0]
                          : '?',
                      style: AppTokens.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Text(
                    detail.shareUserInfo.username,
                    style: AppTokens.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Text(
                    '分享于 ${detail.createTime} · ${_expireLabel(detail.shareEndTime)}',
                    style: AppTokens.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 文件列表（多选）
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space12,
            AppTokens.space12,
            AppTokens.space12,
            AppTokens.space4,
          ),
          child: Text(
            '共 ${detail.files.length} 个文件，点击选择后保存',
            style: AppTokens.bodySmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
        ),
        ...detail.files.map((file) => _buildFileTile(file)),
      ],
    );
  }

  Widget _buildFileTile(FileVO file) {
    final brightness = Theme.of(context).brightness;
    final selected = _selectedIds.contains(file.fileId);
    return AppListItem(
      selected: selected,
      onTap: () => _toggleSelect(file),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected
                ? AppTokens.brandPrimary
                : AppTokens.textTertiary(brightness),
          ),
          const SizedBox(width: AppTokens.space12),
          FileTypeIcon(type: file.fileType),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.bodyLarge.copyWith(
                    color: AppTokens.textPrimary(brightness),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  file.isFolder
                      ? '文件夹'
                      : file.fileSizeDesc ??
                          translateFileSize(parseFileSize(file.fileSize)),
                  style: AppTokens.bodySmall.copyWith(
                    color: AppTokens.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 有效期展示文案（永久有效 / 有效期至）
  String _expireLabel(String? shareEndTime) {
    if (shareEndTime == null || shareEndTime.isEmpty) {
      return '永久有效';
    }
    final normalized = shareEndTime.trim().replaceFirst(' ', 'T');
    final endDate = DateTime.tryParse(normalized);
    if (endDate == null) return '永久有效';
    // 2099 年及以后视为永久有效
    if (!endDate.isBefore(DateTime(2099))) return '永久有效';
    final f = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-'
        '${endDate.day.toString().padLeft(2, '0')} '
        '${endDate.hour.toString().padLeft(2, '0')}:'
        '${endDate.minute.toString().padLeft(2, '0')}';
    return '有效期至 $f';
  }
}

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/share_service.dart';
import '../utils/e2ee_share.dart';
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
  const ShareDetailPage({
    super.key,
    required this.shareId,
    this.e2eeKey,
    this.e2eeIv,
  });

  final String shareId;

  /// E2EE 分享密钥只存在于分享链接 fragment（#k=&iv=），不会发送到服务端。
  /// 从分享列表点进来时为空，页面会明确提示用户改用带 fragment 的完整链接。
  final String? e2eeKey;
  final String? e2eeIv;

  @override
  ConsumerState<ShareDetailPage> createState() => _ShareDetailPageState();
}

class _ShareDetailPageState extends ConsumerState<ShareDetailPage> {
  /// 记录 share_token 归属分享的本地键（SharedPreferences）
  ///
  /// TokenStorage 的 share_token 是全局单槽，跨分享会复用旧 token；
  /// 这里记录 token 属于哪个 shareId，不匹配则忽略旧 token 走提取码流程。
  static const String _shareTokenOwnerKey = 'share_token_owner';

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
      var token = '';
      if (savedToken.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final owner = prefs.getString(_shareTokenOwnerKey);
        // 全局单槽 token 属于其他分享：忽略，走提取码流程
        if (owner == widget.shareId) {
          token = savedToken;
        }
      }
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
      // 校验成功：记录 token 归属当前分享，避免其他分享复用旧 token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_shareTokenOwnerKey, widget.shareId);
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

  /// 解密下载 E2EE 分享：下载密文 → 逐块解密到临时文件 → 打开
  ///
  /// 全程按块处理，20GB 文件也不会一次性读入内存；进度条同时展示下载与解密两段。
  Future<void> _downloadE2ee() async {
    final key = widget.e2eeKey;
    final iv = widget.e2eeIv;
    if (key == null || key.isEmpty || iv == null || iv.isEmpty) {
      _toast('链接缺少解密密钥，请使用创建者提供的完整分享链接（含 #k=&iv=）');
      return;
    }
    final files = _detail!.files.where((f) => !f.isFolder).toList();
    if (files.length != 1) {
      _toast('E2EE 分享只包含一个密文文件');
      return;
    }
    final file = files.first;

    if (!mounted) return;
    final progress = ValueNotifier<double>(0);
    final phase = ValueNotifier<String>('准备下载密文…');
    var dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('解密下载'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (ctx, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: phase,
                builder: (ctx, text, _) => Text(text),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: value),
              const SizedBox(height: 8),
              Text('${(value * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    ).whenComplete(() => dialogOpen = false));

    // 等路由入栈后再开始，避免极快失败时把详情页 pop 掉
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final tempDir = await getTemporaryDirectory();
    final cipherPath =
        '${tempDir.path}/e2ee-download-${DateTime.now().microsecondsSinceEpoch}.xpan';
    try {
      phase.value = '下载密文中…';
      await ShareService.instance.downloadCipher(
        fileId: file.fileId,
        shareToken: _shareToken!,
        savePath: cipherPath,
        onProgress: (ratio) => progress.value = ratio * 0.5,
      );
      phase.value = '解密中…';
      final result = await decryptE2eeFile(
        File(cipherPath),
        keyBase64Url: key,
        ivBase64Url: iv,
        onProgress: (ratio) => progress.value = 0.5 + ratio * 0.5,
      );
      if (dialogOpen && mounted) Navigator.of(context).pop();
      await OpenFilex.open(result.file.path);
      _toast('已解密：${result.name}');
    } catch (e) {
      if (dialogOpen && mounted) Navigator.of(context).pop();
      _toast('解密下载失败：${e.toString()}');
    } finally {
      final cipher = File(cipherPath);
      if (await cipher.exists()) await cipher.delete();
      progress.dispose();
      phase.dispose();
    }
  }

  /// 举报当前分享。后端要求登录账号，举报只记录待审核，不直接下架。
  Future<void> _report() async {
    final ctrl = TextEditingController();
    final String? reason;
    try {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('举报分享'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '举报理由',
              hintText: '请说明该分享存在的问题',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('提交'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (reason == null || reason.isEmpty) return;
    try {
      await ShareService.instance.report(
        shareId: widget.shareId,
        reason: reason,
      );
      _toast('举报已提交，平台会尽快核查');
    } catch (e) {
      _toast('举报失败：${e.toString()}');
    }
  }

  /// 文件收集上传：访问者把本地文件上传到分享者开启收集的文件夹。
  Future<void> _collect() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) {
      _toast('无法读取所选文件，请重试');
      return;
    }
    final file = File(path);
    final size = await file.length();
    if (size > 2 * 1024 * 1024 * 1024) {
      _toast('文件收集单文件上限为 2GB');
      return;
    }
    final progress = ValueNotifier<double>(0);
    var dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('上传到分享文件夹'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (ctx, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 8),
              Text('${(value * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    ).whenComplete(() => dialogOpen = false));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      await ShareService.instance.collect(
        file: file,
        shareToken: _shareToken!,
        onProgress: (ratio) => progress.value = ratio,
      );
      if (dialogOpen && mounted) Navigator.of(context).pop();
      _toast('上传成功');
    } catch (e) {
      if (dialogOpen && mounted) Navigator.of(context).pop();
      _toast('上传失败：${e.toString()}');
    } finally {
      progress.dispose();
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
      appBar: AppBar(
        title: const Text('分享详情'),
        actions: [
          if (_detail != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: '举报分享',
              onPressed: _report,
            ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody()),
      bottomNavigationBar: _detail != null ? _buildBottomBar() : null,
    );
  }

  /// 底部操作区：E2EE 只解密下载；普通分享按开关组合“上传收集/保存到网盘”。
  Widget? _buildBottomBar() {
    final detail = _detail!;
    if (detail.e2ee) return _buildE2eeBar();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (detail.forbidReshare)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space8),
                child: Row(
                  children: [
                    const Icon(Icons.block, size: 16, color: AppTokens.error),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        '分享者已禁止转载，不能保存到我的网盘',
                        style: AppTokens.bodySmall.copyWith(
                          color: AppTokens.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (detail.collectEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space8),
                child: OutlinedButton.icon(
                  onPressed: _collect,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('上传到分享文件夹'),
                ),
              ),
            if (!detail.forbidReshare) _buildSaveBar(),
          ],
        ),
      ),
    );
  }

  /// E2EE 分享底部按钮：密文不能另存到网盘，只提供解密下载
  Widget _buildE2eeBar() {
    final brightness = Theme.of(context).brightness;
    final hasKey = widget.e2eeKey?.isNotEmpty == true && widget.e2eeIv?.isNotEmpty == true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasKey)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space8),
                child: Text(
                  '当前链接缺少解密密钥，请使用创建者提供的完整链接',
                  style: AppTokens.bodySmall.copyWith(
                    color: AppTokens.textSecondary(brightness),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                boxShadow: AppTokens.shadowBrand(brightness),
              ),
              child: FilledButton.icon(
                onPressed: _downloadE2ee,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppTokens.brandPrimary,
                ),
                icon: const Icon(Icons.lock_open),
                label: const Text('解密下载', style: AppTokens.labelLarge),
              ),
            ),
          ],
        ),
      ),
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
        if (detail.forbidReshare || detail.collectEnabled || detail.downloadLimit > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space12,
              AppTokens.space12,
              AppTokens.space12,
              AppTokens.space4,
            ),
            child: Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space4,
              children: [
                if (detail.forbidReshare)
                  _buildInfoChip(
                    icon: Icons.block,
                    text: '禁止转载',
                    color: AppTokens.error,
                  ),
                if (detail.collectEnabled)
                  _buildInfoChip(
                    icon: Icons.inbox_outlined,
                    text: '可上传到分享文件夹',
                    color: AppTokens.brandPrimary,
                  ),
                if (detail.downloadLimit > 0)
                  _buildInfoChip(
                    icon: Icons.download_outlined,
                    text:
                        '已下载 ${detail.downloadCount}/${detail.downloadLimit}',
                    color: AppTokens.textSecondary(brightness),
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
            detail.forbidReshare
                ? '共 ${detail.files.length} 个文件，分享者已禁止转载'
                : '共 ${detail.files.length} 个文件，点击选择后保存',
            style: AppTokens.bodySmall.copyWith(
              color: detail.forbidReshare
                  ? AppTokens.error
                  : AppTokens.textSecondary(brightness),
            ),
          ),
        ),
        ...detail.files.map((file) => _buildFileTile(file)),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: AppTokens.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildFileTile(FileVO file) {
    final brightness = Theme.of(context).brightness;
    final selected = _selectedIds.contains(file.fileId);
    final selectable = _detail?.forbidReshare != true;
    return AppListItem(
      selected: selected,
      onTap: selectable ? () => _toggleSelect(file) : null,
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

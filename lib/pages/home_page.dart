import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_tokens.dart';
import '../core/storage/upload_task_storage.dart';
import '../models/file_vo.dart';
import '../providers/auth_provider.dart';
import '../providers/file_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/upload_provider.dart';
import '../services/ai_file_service.dart';
import '../services/download_service.dart';
import '../services/local_notification_service.dart';
import '../services/extract_service.dart';
import '../services/favorite_service.dart';
import '../services/llm_service.dart';
import '../services/share_service.dart';
import '../services/upload_service.dart';
import '../services/vault_service.dart';
import '../utils/file_open.dart';
import '../utils/format.dart';
import '../widgets/app_list_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../widgets/tag_dialog.dart';
import 'ai_assistant_page.dart';
import 'dashboard_page.dart';
import 'favorite_page.dart';
import 'home/home_components.dart';
import 'home/home_dashboard.dart';
import 'notification_page.dart';
import 'offline_page.dart';
import 'recent_page.dart';
import 'recycle_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'share_page.dart';
import 'file/category_files_page.dart';
import 'upload_task_page.dart';
import '../providers/view_mode_provider.dart';
import '../widgets/category_grid.dart';
import '../widgets/view_options_sheet.dart';
import 'vault_page.dart';
import 'version_history_page.dart';
import 'profile_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _initialized = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  String _uploadingName = '';

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  int _desktopNavIndex = 0;
  int _mobileTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRoot());
  }

  Future<void> _initRoot() async {
    if (_initialized) return;
    final auth = ref.read(authProvider);
    final rootId = auth.user?.rootFileId;
    if (rootId == null || rootId.isEmpty) return;
    _initialized = true;
    await ref
        .read(fileListProvider.notifier)
        .initRoot(rootId, auth.user?.rootFilename ?? '全部文件');
    await _checkPendingUploads();
    // 启动实时通知
    await ref.read(notificationProvider.notifier).start();
    // 请求本地通知权限（后台系统推送）
    try {
      await LocalNotificationService.instance.requestPermissions();
    } catch (_) {
      // 忽略权限请求失败
    }
  }

  /// 检测未完成的上传任务并提示恢复
  Future<void> _checkPendingUploads() async {
    try {
      final tasks = await UploadService.instance.pendingTasks();
      if (tasks.isEmpty || !mounted) return;
      final task = tasks.first;
      final confirm = await _showConfirm(
        title: '发现未完成的上传',
        content: '检测到「${task.filename}」上次上传未完成，是否继续上传？',
      );
      if (confirm == true && mounted) {
        await _resumeUpload(task);
      }
    } catch (_) {
      // 忽略检测错误
    }
  }

  /// 恢复上传任务（走统一上传队列，消除全局回调冲突）
  Future<void> _resumeUpload(UploadTaskRecord task) async {
    final file = File(task.filePath);
    if (!await file.exists()) {
      _toast('源文件已不存在，无法恢复');
      return;
    }
    final manager = ref.read(uploadManagerProvider.notifier);
    await manager.addFile(
      file,
      task.parentId,
      resumeIdentifier: task.identifier,
    );
    _toast('已恢复上传');
    _openPage(const TransferPage());
  }

  Future<void> _refresh() => ref.read(fileListProvider.notifier).refresh();

  Future<void> _goBack() => ref.read(fileListProvider.notifier).goBack();

  void _openFile(FileVO file) {
    if (file.isFolder) {
      ref.read(fileListProvider.notifier).openFolder(file);
      return;
    }
    // 复用统一打开逻辑（含最近访问记录）；图片图集取当前列表内所有图片
    final images = ref
        .read(fileListProvider)
        .files
        .where((f) => f.fileType == FileType.image)
        .toList();
    openFileByType(context, file, images: images);
  }

  Future<void> _download(FileVO file) async {
    if (file.isFolder) {
      _toast('文件夹暂不支持下载');
      return;
    }
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _uploadingName = file.filename;
    });
    try {
      await DownloadService.instance.downloadAndOpen(
        fileId: file.fileId,
        filename: file.filename,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
    } catch (e) {
      _toast('下载失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadingName = '';
        });
      }
    }
  }

  Future<void> _upload() async {
    final parentId = ref.read(fileListProvider.notifier).currentFolderId;
    if (parentId == null) return;

    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final manager = ref.read(uploadManagerProvider.notifier);
    var added = 0;
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      await manager.addFile(File(path), parentId);
      added++;
    }
    if (added > 0) {
      _toast('已添加 $added 个文件到上传队列');
      // 打开上传任务面板
      _openPage(const TransferPage());
    }
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final String? name;
    try {
      name = await _showInputDialog(
        title: '新建文件夹',
        label: '文件夹名称',
        controller: ctrl,
      );
    } finally {
      ctrl.dispose();
    }
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(fileListProvider.notifier).createFolder(name);
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _rename(FileVO file) async {
    final ctrl = TextEditingController(text: file.filename);
    final String? name;
    try {
      name = await _showInputDialog(
        title: '重命名',
        label: '新名称',
        controller: ctrl,
      );
    } finally {
      ctrl.dispose();
    }
    if (name == null || name.isEmpty || name == file.filename) return;
    try {
      await ref.read(fileListProvider.notifier).rename(file.fileId, name);
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _delete(List<FileVO> files) async {
    final names = files.length == 1
        ? '「${files.first.filename}」'
        : '选中的 ${files.length} 个文件';
    final confirm = await _showConfirm(
      title: '删除',
      content: '确定删除$names吗？',
    );
    if (confirm != true) return;
    try {
      final fileIds = files.map((f) => f.fileId).toList();
      await ref.read(fileListProvider.notifier).delete(fileIds);
      _toast('已删除');
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// 选择目标文件夹（用于复制/移动，支持批量）
  Future<void> _pickTargetFolder(
    List<FileVO> files, {
    required bool isCopy,
  }) async {
    final targetId = await showFolderPickerDialog(
      context,
      title: isCopy ? '复制到' : '移动到',
      confirmText: isCopy ? '复制到此处' : '移动到此处',
    );
    if (targetId == null) return;
    final notifier = ref.read(fileListProvider.notifier);
    final fileIds = files.map((f) => f.fileId).toList();
    try {
      if (isCopy) {
        await notifier.copy(fileIds, targetId);
      } else {
        await notifier.move(fileIds, targetId);
      }
      _toast(isCopy ? '已复制' : '已移动');
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// 选择分享有效期（0 永久 / 1 七天 / 2 三十天）
  Future<int?> _pickShareDayType() async {
    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppTokens.space16),
              child: Text('选择分享有效期', style: AppTokens.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('永久有效'),
              subtitle: const Text('分享链接不会过期'),
              onTap: () => Navigator.pop(ctx, 0),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('7 天有效'),
              subtitle: const Text('一周后自动过期'),
              onTap: () => Navigator.pop(ctx, 1),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('30 天有效'),
              subtitle: const Text('一月后自动过期'),
              onTap: () => Navigator.pop(ctx, 2),
            ),
          ],
        ),
      ),
    );
  }

  /// 分享选中文件
  Future<void> _shareFiles(List<FileVO> files) async {
    final fileIds = files.map((f) => f.fileId).toList();
    // shareName：单文件用文件名，多文件用 "文件名 等 N 个文件"
    final shareName = files.length == 1
        ? files.first.filename
        : '${files.first.filename} 等 ${files.length} 个文件';

    final shareDayType = await _pickShareDayType();
    if (shareDayType == null) return;

    try {
      await ShareService.instance.create(
        shareName: shareName,
        fileIds: fileIds,
        shareType: 1, // 公开分享
        shareDayType: shareDayType,
      );
      _toast('分享成功');
      // 跳转分享页
      if (mounted) {
        Navigator.of(context).push(AppTokens.route(const SharePage()));
      }
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// 单个文件操作菜单
  Future<void> _showFileActions(FileVO file) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('下载'),
              onTap: () => Navigator.pop(ctx, 'download'),
            ),
            if (!file.isFolder)
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('重命名'),
                onTap: () => Navigator.pop(ctx, 'rename'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('分享'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移动'),
              onTap: () => Navigator.pop(ctx, 'move'),
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('收藏'),
              onTap: () => Navigator.pop(ctx, 'favorite'),
            ),
            if (!file.isFolder)
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: const Text('标签'),
                onTap: () => Navigator.pop(ctx, 'tag'),
              ),
            if (!file.isFolder)
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('移入保险箱'),
                onTap: () => Navigator.pop(ctx, 'vault'),
              ),
            if (file.fileType == FileType.archive)
              ListTile(
                leading: const Icon(Icons.unarchive_outlined),
                title: const Text('在线解压'),
                onTap: () => Navigator.pop(ctx, 'extract'),
              ),
            if (!file.isFolder)
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('AI 摘要'),
                onTap: () => Navigator.pop(ctx, 'ai-summarize'),
              ),
            if (!file.isFolder)
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('AI 重命名建议'),
                onTap: () => Navigator.pop(ctx, 'ai-rename'),
              ),
            if (!file.isFolder)
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('版本历史'),
                onTap: () => Navigator.pop(ctx, 'versions'),
              ),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (!mounted) return;
    switch (action) {
      case 'download':
        await _download(file);
      case 'rename':
        await _rename(file);
      case 'delete':
        await _delete([file]);
      case 'share':
        await _shareFiles([file]);
      case 'copy':
        await _pickTargetFolder([file], isCopy: true);
      case 'move':
        await _pickTargetFolder([file], isCopy: false);
      case 'favorite':
        await _favorite([file]);
      case 'tag':
        await showTagDialog(context, file);
      case 'vault':
        await _moveToVault([file]);
      case 'extract':
        await _extract(file);
      case 'ai-summarize':
        await _aiSummarize(file);
      case 'ai-rename':
        await _aiRename(file);
      case 'versions':
        _openPage(VersionHistoryPage(fileId: file.fileId));
    }
  }

  /// 收藏文件
  Future<void> _favorite(List<FileVO> files) async {
    try {
      await FavoriteService.instance.add(files.map((f) => f.fileId).toList());
      _toast('已收藏');
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// AI 文件摘要
  Future<void> _aiSummarize(FileVO file) async {
    // 检查 API Key 是否配置
    if (!await LLMService.instance.isConfigured()) {
      _toast('请先在「AI 助手」中配置 DeepSeek API Key');
      return;
    }
    if (!mounted) return;
    // 显示加载对话框
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final summary = await AiFileService.instance.summarize(file);
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载框
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${file.filename} 摘要', maxLines: 1, overflow: TextOverflow.ellipsis),
          content: SingleChildScrollView(
            child: Text(summary, style: const TextStyle(height: 1.6)),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _toast(e.toString());
    }
  }

  /// AI 重命名建议
  Future<void> _aiRename(FileVO file) async {
    if (!await LLMService.instance.isConfigured()) {
      _toast('请先在「AI 助手」中配置 DeepSeek API Key');
      return;
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final suggestions = await AiFileService.instance.suggestRename(file);
      if (!mounted) return;
      Navigator.of(context).pop();
      // 解析建议（每行一个）
      final names = suggestions
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .where((s) => !s.startsWith('-'))
          .map((s) => s.replaceFirst(RegExp(r'^\d+[\.\)、]?\s*'), ''))
          .toList();

      final chosen = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择新文件名'),
          children: [
            for (final name in names)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, name),
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      );

      if (chosen != null && chosen.isNotEmpty) {
        await ref.read(fileListProvider.notifier).rename(file.fileId, chosen);
        _toast('已重命名');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _toast(e.toString());
    }
  }

  /// 移入保险箱
  Future<void> _moveToVault(List<FileVO> files) async {
    try {
      // 检查保险箱状态，若未设置密码需先设置
      final status = await VaultService.instance.status();
      if (!status.hasPassword) {
        _toast('请先到「隐私保险箱」设置密码');
        return;
      }
      if (!status.unlocked) {
        _toast('请先到「隐私保险箱」解锁');
        return;
      }
      final fileIds = files.map((f) => f.fileId).toList();
      await VaultService.instance.move(fileIds);
      _toast('已移入保险箱');
      await _refresh();
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// 在线解压
  Future<void> _extract(FileVO file) async {
    _toast('正在创建解压任务…');
    try {
      final task = await ExtractService.instance.extract(file.fileId);
      if (task.status == 2) {
        _toast('解压完成');
        await _refresh();
        return;
      }
      // 轮询进度
      _toast('解压中…');
      await _pollExtract(task.taskId);
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _pollExtract(String taskId) async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final task = await ExtractService.instance.progress(taskId);
        if (task.status == 2) {
          _toast('解压完成（${task.totalCount} 个文件）');
          await _refresh();
          return;
        }
        if (task.status == 3) {
          _toast('解压失败：${task.errorMsg ?? '未知错误'}');
          return;
        }
      } catch (_) {
        // 轮询失败继续
      }
    }
    _toast('解压超时，请稍后刷新查看');
    await _refresh();
  }

  // ─── 多选相关 ───────────────────────────────────────────────

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
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

  List<FileVO> get _selectedFiles {
    final state = ref.read(fileListProvider);
    return state.files.where((f) => _selectedIds.contains(f.fileId)).toList();
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    await _delete(_selectedFiles);
    _exitSelection();
  }

  Future<void> _batchMove() async {
    if (_selectedIds.isEmpty) return;
    await _pickTargetFolder(_selectedFiles, isCopy: false);
    _exitSelection();
  }

  Future<void> _batchCopy() async {
    if (_selectedIds.isEmpty) return;
    await _pickTargetFolder(_selectedFiles, isCopy: true);
    _exitSelection();
  }

  Future<void> _batchShare() async {
    if (_selectedIds.isEmpty) return;
    await _shareFiles(_selectedFiles);
    _exitSelection();
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  // ─── 工具方法 ───────────────────────────────────────────────

  Future<String?> _showInputDialog({
    required String title,
    required String label,
    required TextEditingController controller,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: AppTokens.titleLarge.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: AppTokens.space16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(hintText: label),
                ),
                const SizedBox(height: AppTokens.space24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.pop(ctx, controller.text.trim()),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showConfirm({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: AppTokens.titleLarge.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: AppTokens.space16),
                Text(
                  content,
                  style: AppTokens.bodyMedium.copyWith(
                    color: AppTokens.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: AppTokens.space24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTokens.error,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(AppTokens.route(page));
  }

  @override
  Widget build(BuildContext context) {
    // 冷启动时 bootstrap 可能晚于首帧完成：认证恢复完成后补充初始化根目录，避免列表为空
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.user != null && (prev == null || prev.user == null)) {
        _initRoot();
      }
    });
    final fileState = ref.watch(fileListProvider);
    final notifier = ref.read(fileListProvider.notifier);
    final desktop = isDesktop(context);

    // 桌面端：侧边导航栏 + 内容区；移动端：底部 TabBar + IndexedStack
    final mainBody = Column(
      children: [
        HomeBreadcrumbs(
          names: notifier.breadcrumbs.map((c) => c.name).toList(),
          onJump: notifier.jumpTo,
        ),
        // 分类直达入口（对齐主流网盘）
        _CategoryShortcut(
          onOpen: (label, fileTypesParam) => Navigator.of(context).push(
            AppTokens.route(
              CategoryFilesPage(
                title: label,
                fileTypesParam: fileTypesParam,
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _buildBody(fileState),
          ),
        ),
      ],
    );

    // 移动端底部 TabBar（首页/文件/传输/AI/我的）；完整功能已分散到各 Tab 与我的页
    final onFilesTab = _mobileTabIndex == 1;
    final brightness = Theme.of(context).brightness;
    final mobileTabStack = IndexedStack(
      index: _mobileTabIndex,
      children: [
        const HomeDashboard(),
        mainBody,
        const TransferPage(),
        const AIAssistantPage(),
        const ProfilePage(),
      ],
    );

    return Scaffold(
      // 非文件页自带 AppBar，切换 Tab 时隐藏外层 AppBar
      appBar: desktop || onFilesTab ? _buildAppBar(notifier) : null,
      body: desktop
          ? Row(
              children: [
                HomeDesktopRail(
                  selectedIndex: _desktopNavIndex,
                  onDestinationSelected: (i) {
                    setState(() => _desktopNavIndex = i);
                    _openDesktopNav(i);
                  },
                ),
                const VerticalDivider(width: 1),
                Expanded(child: mainBody),
              ],
            )
          : mobileTabStack,
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _mobileTabIndex,
              onDestinationSelected: (i) =>
                  setState(() => _mobileTabIndex = i),
              indicatorColor:
                  AppTokens.brandPrimary.withValues(alpha: 0.12),
              backgroundColor: AppTokens.surface(brightness),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: '文件',
                ),
                NavigationDestination(
                  icon: Icon(Icons.upload_file_outlined),
                  selectedIcon: Icon(Icons.upload_file),
                  label: '传输',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: 'AI',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: '我的',
                ),
              ],
            ),
      floatingActionButton: _selectionMode || !onFilesTab
          ? null
          : FloatingActionButton(
              onPressed: _showAddSheet,
              child: const Icon(Icons.add),
            ),
      bottomSheet: _uploading
          ? UploadProgressBar(
              name: _uploadingName,
              progress: _uploadProgress,
            )
          : null,
    );
  }

  /// 文件页 FAB 底部弹窗（上传/新建文件夹/离线下载）
  void _showAddSheet() {
    final brightness = Theme.of(context).brightness;
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(
                  '上传文件',
                  style: AppTokens.bodyLarge.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _upload();
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text(
                  '新建文件夹',
                  style: AppTokens.bodyLarge.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _createFolder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(
                  '离线下载',
                  style: AppTokens.bodyLarge.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPage(const OfflinePage());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 桌面端侧边导航点击分发
  void _openDesktopNav(int index) {
    final page = switch (index) {
      1 => const RecentPage(),
      2 => const FavoritePage(),
      3 => const SharePage(),
      4 => const OfflinePage(),
      5 => const TransferPage(),
      6 => const RecyclePage(),
      7 => const VaultPage(),
      8 => const AIAssistantPage(),
      9 => const DashboardPage(),
      10 => const NotificationPage(),
      11 => const SettingsPage(),
      _ => null,
    };
    if (page != null) _openPage(page);
  }

  PreferredSizeWidget _buildAppBar(FileListNotifier notifier) {
    final brightness = Theme.of(context).brightness;
    if (_selectionMode) {
      return SelectionAppBar(
        selectedCount: _selectedIds.length,
        onExit: _exitSelection,
        onDelete: _batchDelete,
        onMove: _batchMove,
        onCopy: _batchCopy,
        onShare: _batchShare,
      );
    }

    final crumbs = notifier.breadcrumbs;
    final pathDesc = crumbs.length > 1
        ? crumbs.map((c) => c.name).join(' / ')
        : null;

    return AppBar(
      leading: notifier.canGoBack
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的网盘'),
          if (pathDesc != null)
            Text(
              pathDesc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.bodySmall.copyWith(
                color: AppTokens.textSecondary(brightness),
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            ref.watch(fileViewModeProvider).viewMode == FileViewMode.list
                ? Icons.grid_view
                : Icons.view_list,
          ),
          tooltip: '视图与排序',
          onPressed: () => showViewOptionsSheet(context),
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选',
          onPressed: _toggleSelectionMode,
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: '搜索',
          onPressed: () => _openPage(const SearchPage()),
        ),
        IconButton(
          icon: const Icon(Icons.upload_file_outlined),
          tooltip: '上传',
          onPressed: _upload,
        ),
      ],
    );
  }

  Widget _buildBody(FileListState state) {
    if (state.loading && state.files.isEmpty) {
      return const FileListSkeleton();
    }
    if (state.error != null && state.files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(
            icon: Icons.cloud_off,
            title: '加载失败',
            subtitle: state.error,
            actionLabel: '重试',
            actionIcon: Icons.refresh,
            onAction: _refresh,
          ),
        ],
      );
    }
    if (state.files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(
            icon: Icons.folder_open,
            title: '文件夹为空',
            subtitle: '上传你的第一个文件吧',
            actionLabel: '上传文件',
            onAction: _upload,
          ),
        ],
      );
    }

    if (ref.read(fileViewModeProvider).viewMode == FileViewMode.grid) {
      return _buildGrid(state.files);
    }
    return _buildList(state.files);
  }

  Widget _buildList(List<FileVO> files) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (ctx, i) {
        final file = files[i];
        return _FileTile(
          file: file,
          selected: _selectedIds.contains(file.fileId),
          selectionMode: _selectionMode,
          onTap: () => _selectionMode ? _toggleSelect(file) : _openFile(file),
          onLongPress: () {
            if (!_selectionMode) {
              _toggleSelectionMode();
              _toggleSelect(file);
            } else {
              _showFileActions(file);
            }
          },
        );
      },
    );
  }

  Widget _buildGrid(List<FileVO> files) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      // 限制预加载范围，减少快速滚动时的并发缩略图请求
      cacheExtent: 200,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (ctx, i) {
        final file = files[i];
        return _FileGridItem(
          file: file,
          selected: _selectedIds.contains(file.fileId),
          selectionMode: _selectionMode,
          onTap: () => _selectionMode ? _toggleSelect(file) : _openFile(file),
          onLongPress: () {
            if (!_selectionMode) {
              _toggleSelectionMode();
              _toggleSelect(file);
            }
          },
        );
      },
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final FileVO file;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Stack(
      children: [
        AppListItem(
          selected: selected,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? AppTokens.brandPrimary
                      : AppTokens.textTertiary(brightness),
                ),
                const SizedBox(width: AppTokens.space12),
              ],
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
              if (!selectionMode) ...[
                const SizedBox(width: AppTokens.space8),
                if (file.isFolder)
                  Icon(
                    Icons.chevron_right,
                    color: AppTokens.textTertiary(brightness),
                  )
                else
                  _MoreButton(onTap: onLongPress),
              ],
            ],
          ),
        ),
        // 选中态左侧蓝色竖条
        if (selected)
          Positioned(
            left: 0,
            top: AppTokens.space12,
            bottom: AppTokens.space12,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: AppTokens.brandPrimary,
                borderRadius:
                    BorderRadius.circular(AppTokens.radiusFull),
              ),
            ),
          ),
      ],
    );
  }
}

/// 文件行尾圆形更多按钮
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTokens.surface(brightness),
        boxShadow: AppTokens.shadowSm(brightness),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          onTap: onTap,
          child: Icon(
            Icons.more_vert,
            size: 18,
            color: AppTokens.textSecondary(brightness),
          ),
        ),
      ),
    );
  }
}

class _FileGridItem extends StatelessWidget {
  const _FileGridItem({
    required this.file,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final FileVO file;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.brandPrimary.withValues(alpha: 0.08)
              : AppTokens.surface(brightness),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: selected
                ? AppTokens.brandPrimary
                : AppTokens.divider(brightness).withValues(alpha: 0.5),
            width: selected ? 2 : 0.5,
          ),
          boxShadow: AppTokens.shadowSm(brightness),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTokens.space8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (file.fileType == FileType.image && file.thumbnail != null)
                    _buildThumbnail(context)
                  else
                    FileTypeIcon(type: file.fileType, size: 56),
                  if (selectionMode) ...[
                    const SizedBox(height: AppTokens.space4),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? AppTokens.brandPrimary
                          : AppTokens.textTertiary(brightness),
                      size: 24,
                    ),
                  ],
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    file.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTokens.bodySmall.copyWith(
                      color: AppTokens.textPrimary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            // 选中角标
            if (selected)
              Positioned(
                top: AppTokens.space4,
                right: AppTokens.space4,
                child: const Icon(
                  Icons.check_circle,
                  color: AppTokens.brandPrimary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    // 缩略图：后端返回相对路径，拼接 base URL
    final thumbnail = file.thumbnail!;
    final url = thumbnail.startsWith('http')
        ? thumbnail
        : '${AppConfig.apiBaseUrl}$thumbnail';
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        // 懒加载优化：仅解码到屏幕所需分辨率，避免原图占用内存
        // 56px * devicePixelRatio ≈ 112px，向上取 128 作为缓存宽度
        memCacheWidth: 128,
        maxWidthDiskCache: 256,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => const SkeletonBox(
          width: 56,
          height: 56,
          borderRadius: AppTokens.radiusMd,
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.image_outlined, size: 40),
      ),
    );
  }
}

/// 文件页顶部分类直达入口（横向滚动）
class _CategoryShortcut extends StatelessWidget {
  const _CategoryShortcut({required this.onOpen});
  final void Function(String label, String fileTypesParam) onOpen;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 84,
      margin: const EdgeInsets.fromLTRB(
        AppTokens.space12,
        AppTokens.space8,
        AppTokens.space12,
        AppTokens.space4,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kFileCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.space12),
        itemBuilder: (context, i) {
          final c = kFileCategories[i];
          return InkWell(
            onTap: () =>
                onOpen(c.label, c.fileTypes.map((t) => t.value).join(',')),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: Container(
              width: 76,
              padding: const EdgeInsets.all(AppTokens.space8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                color: AppTokens.surfaceElevated(brightness),
                border: Border.all(
                  color:
                      AppTokens.divider(brightness).withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: c.gradient,
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: Icon(c.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    c.label,
                    style: AppTokens.labelSmall.copyWith(
                      color: AppTokens.textPrimary(brightness),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

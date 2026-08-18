import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/storage/recent_storage.dart';
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
import '../utils/format.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/responsive.dart';
import '../widgets/tag_dialog.dart';
import 'ai_assistant_page.dart';
import 'audio_preview_page.dart';
import 'csv_preview_page.dart';
import 'dashboard_page.dart';
import 'dedup_page.dart';
import 'favorite_page.dart';
import 'image_preview_page.dart';
import 'notification_page.dart';
import 'offline_page.dart';
import 'office_preview_page.dart';
import 'pdf_preview_page.dart';
import 'recent_page.dart';
import 'recycle_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'share_page.dart';
import 'text_preview_page.dart';
import 'upload_task_page.dart';
import 'vault_page.dart';
import 'version_history_page.dart';
import 'video_preview_page.dart';
import 'xmind_preview_page.dart';

enum _ViewMode { list, grid }

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

  _ViewMode _viewMode = _ViewMode.list;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  int _desktopNavIndex = 0;

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
    _openPage(const UploadTaskPage());
  }

  Future<void> _refresh() => ref.read(fileListProvider.notifier).refresh();

  Future<void> _goBack() => ref.read(fileListProvider.notifier).goBack();

  void _openFile(FileVO file) {
    if (file.isFolder) {
      ref.read(fileListProvider.notifier).openFolder(file);
      return;
    }

    // 记录最近访问
    _recordRecent(file);

    // xmind 思维导图（通过扩展名识别）
    if (file.filename.toLowerCase().endsWith('.xmind')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => XmindPreviewPage(file: file)),
      );
      return;
    }

    final route = switch (file.fileType) {
      FileType.image => _buildImageRoute(file),
      FileType.video => MaterialPageRoute(
          builder: (_) => VideoPreviewPage(file: file),
        ),
      FileType.audio => MaterialPageRoute(
          builder: (_) => AudioPreviewPage(file: file),
        ),
      FileType.pdf => MaterialPageRoute(
          builder: (_) => PDFPreviewPage(file: file),
        ),
      FileType.csv => MaterialPageRoute(
          builder: (_) => CsvPreviewPage(file: file),
        ),
      FileType.txt || FileType.code => MaterialPageRoute(
          builder: (_) => TextPreviewPage(file: file),
        ),
      FileType.word || FileType.excel || FileType.ppt => MaterialPageRoute(
          builder: (_) => OfficePreviewPage(file: file),
        ),
      _ => null,
    };

    if (route != null) {
      Navigator.of(context).push(route);
      return;
    }
    _download(file);
  }

  /// 记录最近访问（异步，不阻塞）
  void _recordRecent(FileVO file) {
    final now = DateTime.now();
    final timeStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    RecentStorage.add(
      RecentItem(
        fileId: file.fileId,
        filename: file.filename,
        fileType: file.fileType.value,
        visitTime: timeStr,
      ),
    );
  }

  MaterialPageRoute<void> _buildImageRoute(FileVO file) {
    final state = ref.read(fileListProvider);
    final images =
        state.files.where((f) => f.fileType == FileType.image).toList();
    final index = images.indexWhere((f) => f.fileId == file.fileId);
    return MaterialPageRoute(
      builder: (_) => ImagePreviewPage(
        files: images,
        initialIndex: index < 0 ? 0 : index,
      ),
    );
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
      _openPage(const UploadTaskPage());
    }
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await _showInputDialog(
      title: '新建文件夹',
      label: '文件夹名称',
      controller: ctrl,
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(fileListProvider.notifier).createFolder(name);
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _rename(FileVO file) async {
    final ctrl = TextEditingController(text: file.filename);
    final name = await _showInputDialog(
      title: '重命名',
      label: '新名称',
      controller: ctrl,
    );
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

  /// 分享选中文件
  Future<void> _shareFiles(List<FileVO> files) async {
    final fileIds = files.map((f) => f.fileId).toList();
    // shareName：单文件用文件名，多文件用 "文件名 等 N 个文件"
    final shareName = files.length == 1
        ? files.first.filename
        : '${files.first.filename} 等 ${files.length} 个文件';
    try {
      await ShareService.instance.create(
        shareName: shareName,
        fileIds: fileIds,
        shareType: 1, // 公开分享
      );
      _toast('分享成功');
      // 跳转分享页
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SharePage()),
        );
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
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirm({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final fileState = ref.watch(fileListProvider);
    final notifier = ref.read(fileListProvider.notifier);
    final desktop = isDesktop(context);

    // 桌面端：侧边导航栏 + 内容区；移动端：抽屉导航
    final mainBody = Column(
      children: [
        _buildBreadcrumbs(notifier),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _buildBody(fileState),
          ),
        ),
      ],
    );

    return Scaffold(
      drawer: desktop
          ? null
          : Drawer(
              child: SafeArea(
                child: _buildNavList(auth),
              ),
            ),
      appBar: _buildAppBar(notifier),
      body: desktop
          ? Row(
              children: [
                // 用 SingleChildScrollView 包裹，避免低高度窗口下导航项溢出
                SingleChildScrollView(
                  child: NavigationRail(
                    selectedIndex: _desktopNavIndex,
                    onDestinationSelected: (i) {
                      setState(() => _desktopNavIndex = i);
                      _openDesktopNav(i);
                    },
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: CircleAvatar(
                        radius: 20,
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    destinations: _navDestinations(),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: mainBody),
              ],
            )
          : mainBody,
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              onPressed: _upload,
              child: const Icon(Icons.add),
            ),
      bottomSheet: _uploading ? _buildUploadBar() : null,
    );
  }

  /// 桌面端侧边导航项
  List<NavigationRailDestination> _navDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud),
        label: Text('我的网盘'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.history),
        label: Text('最近访问'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.star_outline),
        selectedIcon: Icon(Icons.star),
        label: Text('收藏'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.share_outlined),
        label: Text('分享'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.cloud_download_outlined),
        label: Text('离线'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.upload_file_outlined),
        label: Text('上传任务'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.delete_outline),
        label: Text('回收站'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.security),
        label: Text('保险箱'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.auto_awesome),
        label: Text('AI'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        label: Text('统计'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.notifications_outlined),
        label: Text('通知'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        label: Text('设置'),
      ),
    ];
  }

  /// 桌面端侧边导航点击分发
  void _openDesktopNav(int index) {
    final page = switch (index) {
      1 => const RecentPage(),
      2 => const FavoritePage(),
      3 => const SharePage(),
      4 => const OfflinePage(),
      5 => const UploadTaskPage(),
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

  /// 移动端抽屉导航项（可复用）
  Widget _buildNavList(dynamic auth) {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text(auth.user?.username ?? '未登录'),
          accountEmail: Text(
            '已用 ${translateFileSize((auth.user?.usedSize ?? 0).toDouble())} / ${translateFileSize((auth.user?.totalSize ?? 0).toDouble())}',
          ),
          currentAccountPicture: CircleAvatar(
            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('回收站'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const RecyclePage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('我的分享'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const SharePage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: const Text('离线下载'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const OfflinePage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: const Text('上传任务'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const UploadTaskPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('最近访问'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const RecentPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.star_outline),
          title: const Text('我的收藏'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const FavoritePage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.security),
          title: const Text('隐私保险箱'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const VaultPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('文件去重'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const DedupPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.dashboard_outlined),
          title: const Text('存储统计'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const DashboardPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('AI 助手'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const AIAssistantPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('通知中心'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const NotificationPage());
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('设置'),
          onTap: () {
            Navigator.pop(context);
            _openPage(const SettingsPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('退出登录'),
          onTap: () {
            Navigator.pop(context);
            // 停止实时通知并断开连接
            ref.read(notificationProvider.notifier).stop();
            ref.read(authProvider.notifier).logout();
          },
        ),
      ],
    );
  }

  AppBar _buildAppBar(FileListNotifier notifier) {
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelection,
        ),
        title: Text('已选 ${_selectedIds.length} 项'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '批量删除',
            onPressed: _batchDelete,
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_move_outline),
            tooltip: '批量移动',
            onPressed: _batchMove,
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: '批量复制',
            onPressed: _batchCopy,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: '批量分享',
            onPressed: _batchShare,
          ),
        ],
      );
    }

    return AppBar(
      leading: notifier.canGoBack
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
          : null,
      title: const Text('我的网盘'),
      actions: [
        IconButton(
          icon: Icon(
            _viewMode == _ViewMode.list ? Icons.grid_view : Icons.view_list,
          ),
          tooltip: '切换视图',
          onPressed: () => setState(() {
            _viewMode =
                _viewMode == _ViewMode.list ? _ViewMode.grid : _ViewMode.list;
          }),
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
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'newFolder') await _createFolder();
            if (v == 'logout') {
              ref.read(notificationProvider.notifier).stop();
              await ref.read(authProvider.notifier).logout();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'newFolder', child: Text('新建文件夹')),
            PopupMenuItem(value: 'logout', child: Text('退出登录')),
          ],
        ),
      ],
    );
  }

  Widget _buildBreadcrumbs(FileListNotifier notifier) {
    final crumbs = notifier.breadcrumbs;
    if (crumbs.length <= 1) return const SizedBox.shrink();
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: crumbs.length,
        separatorBuilder: (_, __) => const Icon(Icons.chevron_right, size: 16),
        itemBuilder: (ctx, i) {
          final isLast = i == crumbs.length - 1;
          return Center(
            child: GestureDetector(
              onTap: isLast ? null : () => notifier.jumpTo(i),
              child: Text(
                crumbs[i].name,
                style: TextStyle(
                  color: isLast
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _uploadingName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${(_uploadProgress * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _uploadProgress),
        ],
      ),
    );
  }

  Widget _buildBody(FileListState state) {
    if (state.loading && state.files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.files.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.error_outline,
              size: 56, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Center(child: Text('加载失败：${state.error}')),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(onPressed: _refresh, child: const Text('重试')),
          ),
        ],
      );
    }
    if (state.files.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.folder_open,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Center(child: Text('文件夹为空')),
        ],
      );
    }

    if (_viewMode == _ViewMode.grid) {
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
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primary.withValues(alpha: 0.08),
      leading: selectionMode
          ? Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? scheme.primary : scheme.outline,
            )
          : FileTypeIcon(type: file.fileType),
      title: Text(file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        file.isFolder
            ? '文件夹'
            : file.fileSizeDesc ??
                translateFileSize(parseFileSize(file.fileSize)),
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: selectionMode
          ? null
          : file.isFolder
              ? Icon(Icons.chevron_right, color: scheme.outline)
              : IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: onLongPress,
                ),
      onTap: onTap,
      onLongPress: onLongPress,
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
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          border: selected
              ? Border.all(color: scheme.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selectionMode)
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.outline,
                size: 28,
              )
            else if (file.fileType == FileType.image && file.thumbnail != null)
              _buildThumbnail(context)
            else
              FileTypeIcon(type: file.fileType, size: 56),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                file.filename,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
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
      borderRadius: BorderRadius.circular(8),
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
        placeholder: (_, __) => Container(
          width: 56,
          height: 56,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image_outlined, size: 24),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.image_outlined, size: 40),
      ),
    );
  }
}

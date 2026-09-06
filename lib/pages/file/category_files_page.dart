import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/http_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../services/user_service.dart';
import '../../providers/view_mode_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_type_icon.dart';
import '../../widgets/view_options_sheet.dart';
import 'audio_category_view.dart';
import 'doc_category_view.dart';
import 'image_category_view.dart';
import 'video_category_view.dart';

/// 按文件类型过滤的分类文件列表页
///
/// 由首页 / 文件页的「分类直达」点击进入。复用 `FileService.list(fileTypes:)`，
/// 后端已支持按类型过滤，无需新增接口。根据类型分发到专用视图：
/// 图片=时间轴缩略图、视频=海报网格、文档=子类型Tab+时间轴、音频=歌曲列表，
/// 应用/其他=通用列表/网格。
class CategoryFilesPage extends ConsumerStatefulWidget {
  const CategoryFilesPage({
    super.key,
    required this.title,
    required this.fileTypesParam,
  });

  final String title;
  final String fileTypesParam;

  @override
  ConsumerState<CategoryFilesPage> createState() => _CategoryFilesPageState();
}

/// 分类类型：由标题稳定判定（避免 fileTypesParam 数字歧义，如文档含 image 数字）
enum _CategoryKind { image, video, doc, audio, other }

class _CategoryFilesPageState extends ConsumerState<CategoryFilesPage> {
  List<FileVO> _files = const [];
  bool _loading = true;
  String? _error;

  _CategoryKind get _kind {
    switch (widget.title) {
      case '图片':
        return _CategoryKind.image;
      case '视频':
        return _CategoryKind.video;
      case '文档':
        return _CategoryKind.doc;
      case '音频':
        return _CategoryKind.audio;
      default:
        return _CategoryKind.other;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await FileService.instance.list(
        // -1 表示全盘（后端跳过 parent_id 过滤），跨目录按类型聚合查询
        parentId: '-1',
        fileTypes: widget.fileTypesParam,
      );
      if (!mounted) return;
      setState(() {
        _files = res.records;
        _loading = false;
      });
    } on NeedReloginException {
      // 鉴权失败由全局 relogin 监听统一清理登录态并跳转登录页
      // （HttpClient.onNeedRelogin -> AuthNotifier.forceRelogin），这里仅兜底保留当前页
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mode = ref.watch(fileViewModeProvider);

    // 专用视图无需「视图/排序」按钮（各自已是最优布局）
    final useGenericView = _kind == _CategoryKind.other;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (useGenericView)
            IconButton(
              icon: Icon(
                mode.viewMode == FileViewMode.list
                    ? Icons.grid_view_outlined
                    : Icons.view_list_outlined,
              ),
              tooltip: '视图与排序',
              onPressed: () => showViewOptionsSheet(context),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: AppTokens.bodyMedium.copyWith(
                      color: AppTokens.textSecondary(brightness),
                    ),
                  ),
                )
              : _files.isEmpty
                  ? const EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: '该分类下暂无文件',
                    )
                  : _buildBody(mode.viewMode),
    );
  }

  Widget _buildBody(FileViewMode viewMode) {
    switch (_kind) {
      case _CategoryKind.image:
        return ImageCategoryView(files: _files);
      case _CategoryKind.video:
        return VideoCategoryView(files: _files);
      case _CategoryKind.doc:
        return DocCategoryView(files: _files);
      case _CategoryKind.audio:
        return AudioCategoryView(files: _files);
      case _CategoryKind.other:
        return _buildGeneric(viewMode);
    }
  }

  Widget _buildGeneric(FileViewMode viewMode) {
    if (viewMode == FileViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppTokens.space16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppTokens.space12,
          crossAxisSpacing: AppTokens.space12,
          childAspectRatio: 0.85,
        ),
        itemCount: _files.length,
        itemBuilder: (context, i) => _GridItem(file: _files[i]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      itemCount: _files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _ListItem(file: _files[i]),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({required this.file});
  final FileVO file;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ListTile(
      leading: FileTypeIcon(type: file.fileType, size: 40),
      title: Text(
        file.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTokens.bodyMedium.copyWith(
          color: AppTokens.textPrimary(brightness),
        ),
      ),
      subtitle: Text(
        file.fileSizeDesc ?? file.fileSize ?? '',
        style: AppTokens.bodySmall.copyWith(
          color: AppTokens.textSecondary(brightness),
        ),
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({required this.file});
  final FileVO file;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: FileTypeIcon(type: file.fileType, size: 56),
          ),
        ),
        const SizedBox(height: AppTokens.space8),
        Text(
          file.filename,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTokens.labelSmall.copyWith(
            color: AppTokens.textPrimary(brightness),
          ),
        ),
      ],
    );
  }
}

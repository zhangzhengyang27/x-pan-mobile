import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/http_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../providers/view_mode_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_type_icon.dart';
import '../../widgets/view_options_sheet.dart';

/// 按文件类型过滤的分类文件列表页
///
/// 由首页 / 文件页的「分类直达」点击进入。复用 `FileService.list(fileTypes:)`，
/// 后端已支持按类型过滤，无需新增接口。
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

class _CategoryFilesPageState extends ConsumerState<CategoryFilesPage> {
  List<FileVO> _files = const [];
  bool _loading = true;
  String? _error;

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
        parentId: '0',
        fileTypes: widget.fileTypesParam,
      );
      if (!mounted) return;
      setState(() {
        _files = res.records;
        _loading = false;
      });
    } on NeedReloginException {
      // 鉴权失败由 HttpClient 统一弹登录，这里仅保留当前页
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mode = ref.watch(fileViewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(
              mode.viewMode == FileViewMode.list
                  ? Icons.grid_view_outlined
                  : Icons.view_list_outlined,
            ),
            tooltip: '视图与排序',
            onPressed: () => showViewOptionsSheet(context),
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
                  : _buildList(mode.viewMode),
    );
  }

  Widget _buildList(FileViewMode viewMode) {
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
      onTap: () {},
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/favorite_service.dart';
import '../widgets/app_list_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

enum _ViewMode { list, grid }

/// 收藏（星标）页
class FavoritePage extends ConsumerStatefulWidget {
  const FavoritePage({super.key});

  @override
  ConsumerState<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends ConsumerState<FavoritePage> {
  List<FavoriteFile> _items = [];
  bool _loading = true;
  String? _error;
  _ViewMode _viewMode = _ViewMode.list;

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
      final items = await FavoriteService.instance.list();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unfavorite(FavoriteFile item) async {
    try {
      await FavoriteService.instance.remove([item.fileId]);
      _toast('已取消收藏');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == _ViewMode.list
                  ? Icons.grid_view
                  : Icons.view_list,
            ),
            tooltip: '切换视图',
            onPressed: () => setState(() {
              _viewMode = _viewMode == _ViewMode.list
                  ? _ViewMode.grid
                  : _ViewMode.list;
            }),
          ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
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
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.star_border,
        title: '还没有收藏',
        subtitle: '长按文件即可收藏',
      );
    }
    if (_viewMode == _ViewMode.grid) return _buildGrid();
    return _buildList();
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space8,
      ),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return AppListTile(
          leading: FileTypeIcon(type: item.fileType),
          title: item.filename,
          subtitle: item.fileSizeDesc.isEmpty ? '文件夹' : item.fileSizeDesc,
          trailing: IconButton(
            icon: const Icon(Icons.star, color: AppTokens.warning),
            tooltip: '取消收藏',
            onPressed: () => _unfavorite(item),
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    final brightness = Theme.of(context).brightness;
    return GridView.builder(
      padding: const EdgeInsets.all(AppTokens.space12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: AppTokens.space8,
        crossAxisSpacing: AppTokens.space8,
        childAspectRatio: 0.8,
      ),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return GestureDetector(
          onLongPress: () => _unfavorite(item),
          child: Container(
            decoration: BoxDecoration(
              color: AppTokens.surface(brightness),
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(
                color: AppTokens.divider(brightness).withValues(alpha: 0.5),
                width: 0.5,
              ),
              boxShadow: AppTokens.shadowSm(brightness),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FileTypeIcon(type: item.fileType, size: 56),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    item.filename,
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
          ),
        );
      },
    );
  }
}

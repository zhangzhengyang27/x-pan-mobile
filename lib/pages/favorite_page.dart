import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/favorite_service.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/responsive.dart';

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
      appBar: AppBar(title: const Text('我的收藏')),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无收藏'));
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return ListTile(
          leading: FileTypeIcon(type: item.fileType),
          title: Text(item.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            item.fileSizeDesc.isEmpty ? '文件夹' : item.fileSizeDesc,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.star, color: Colors.amber),
            tooltip: '取消收藏',
            onPressed: () => _unfavorite(item),
          ),
        );
      },
    );
  }
}

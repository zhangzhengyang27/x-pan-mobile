import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_vo.dart';
import '../services/user_service.dart';
import '../utils/format.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/responsive.dart';

/// 文件搜索页
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _ctrl = TextEditingController();
  List<FileVO> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _ctrl.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await FileService.instance.search(keyword: keyword);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: '搜索文件',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('搜索失败：$_error'));
    }
    if (!_searched) {
      return const Center(child: Text('输入关键词开始搜索'));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('未找到相关文件'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (ctx, i) {
        final file = _results[i];
        return ListTile(
          leading: FileTypeIcon(type: file.fileType),
          title: Text(file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            file.fileSizeDesc ?? translateFileSize(parseFileSize(file.fileSize)),
          ),
        );
      },
    );
  }
}

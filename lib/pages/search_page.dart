import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/user_service.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

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
  String _keyword = '';

  /// 会话内搜索历史（最新在前，最多 8 条）
  final List<String> _history = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search([String? keyword]) async {
    final kw = (keyword ?? _ctrl.text).trim();
    if (kw.isEmpty) return;
    if (keyword != null) _ctrl.text = kw;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      _keyword = kw;
    });
    _history.remove(kw);
    _history.insert(0, kw);
    if (_history.length > 8) _history.removeLast();
    try {
      final results = await FileService.instance.search(keyword: kw);
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
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: ResponsiveContent(
        child: Column(
          children: [
            // 置顶搜索栏
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space8,
                AppTokens.space16,
                AppTokens.space12,
              ),
              decoration: BoxDecoration(
                color: AppTokens.surface(brightness),
                borderRadius:
                    BorderRadius.circular(AppTokens.radiusFull),
                boxShadow: AppTokens.shadowSm(brightness),
                border: Border.all(
                  color: AppTokens.divider(brightness).withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: AppTokens.space16),
                  Icon(
                    Icons.search,
                    color: AppTokens.textTertiary(brightness),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: '搜索文件',
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTokens.textTertiary(brightness),
                    onPressed: _ctrl.text.isEmpty
                        ? null
                        : () {
                            _ctrl.clear();
                            setState(() {
                              _searched = false;
                              _results = [];
                              _error = null;
                            });
                          },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(brightness)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Brightness brightness) {
    if (_loading) {
      return const FileListSkeleton(itemCount: 6);
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: '搜索失败',
        subtitle: _error,
        actionLabel: '重试',
        actionIcon: Icons.refresh,
        onAction: () => _search(),
      );
    }
    if (!_searched) {
      // 搜索历史
      if (_history.isNotEmpty) {
        return ListView(
          padding: const EdgeInsets.all(AppTokens.space16),
          children: [
            Text(
              '搜索历史',
              style: AppTokens.labelSmall.copyWith(
                color: AppTokens.textTertiary(brightness),
              ),
            ),
            const SizedBox(height: AppTokens.space12),
            Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space8,
              children: [
                for (final kw in _history)
                  ActionChip(
                    label: Text(kw),
                    avatar: Icon(
                      Icons.history,
                      size: 16,
                      color: AppTokens.textSecondary(brightness),
                    ),
                    onPressed: () => _search(kw),
                  ),
              ],
            ),
          ],
        );
      }
      return EmptyState(
        icon: Icons.search,
        title: '输入关键词开始搜索',
        subtitle: '支持按文件名模糊搜索',
      );
    }
    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: '未找到相关文件',
        subtitle: '换个关键词试试吧',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.space16),
      itemCount: _results.length,
      itemBuilder: (ctx, i) {
        final file = _results[i];
        return AppCard(
          elevation: CardElevation.low,
          margin: const EdgeInsets.only(bottom: AppTokens.space12),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space12,
          ),
          child: Row(
            children: [
              FileTypeIcon(type: file.fileType),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedName(brightness, file.filename),
                    const SizedBox(height: 2),
                    Text(
                      file.fileSizeDesc ??
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
      },
    );
  }

  /// 高亮匹配关键词的文件名
  Widget _buildHighlightedName(Brightness brightness, String name) {
    if (_keyword.isEmpty) {
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTokens.bodyLarge.copyWith(
          color: AppTokens.textPrimary(brightness),
          fontWeight: FontWeight.w500,
        ),
      );
    }
    final spans = <TextSpan>[];
    var rest = name;
    final lowerKw = _keyword.toLowerCase();
    while (true) {
      final idx = rest.toLowerCase().indexOf(lowerKw);
      if (idx < 0) {
        spans.add(TextSpan(text: rest));
        break;
      }
      if (idx > 0) spans.add(TextSpan(text: rest.substring(0, idx)));
      spans.add(
        TextSpan(
          text: rest.substring(idx, idx + _keyword.length),
          style: const TextStyle(
            color: AppTokens.brandPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      rest = rest.substring(idx + _keyword.length);
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTokens.bodyLarge.copyWith(
          color: AppTokens.textPrimary(brightness),
          fontWeight: FontWeight.w500,
        ),
        children: spans,
      ),
    );
  }
}

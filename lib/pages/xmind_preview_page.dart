import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/download_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

/// XMind 思维导图预览页
///
/// XMind 文件本质是 ZIP，核心内容在 content.json（XMind 8+）。
/// 这里下载后解压读取 content.json，递归解析 topic 树并渲染可折叠树。
class XmindPreviewPage extends ConsumerStatefulWidget {
  const XmindPreviewPage({super.key, required this.file});

  final FileVO file;

  @override
  ConsumerState<XmindPreviewPage> createState() => _XmindPreviewPageState();
}

/// 思维导图节点
class TopicNode {
  TopicNode({
    required this.id,
    required this.title,
    this.note,
    this.branchColor,
    this.children = const [],
  });

  final String id;
  final String title;
  final String? note;
  final String? branchColor;
  final List<TopicNode> children;

  int get totalNodes => 1 + children.fold(0, (acc, c) => acc + c.totalNodes);
}

class _XmindPreviewPageState extends ConsumerState<XmindPreviewPage> {
  TopicNode? _root;
  String _sheetTitle = '思维导图';
  bool _loading = true;
  String? _error;
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // 下载到临时文件
      final path = await DownloadService.instance.download(
        fileId: widget.file.fileId,
        filename: widget.file.filename,
      );
      final bytes = await File(path).readAsBytes();

      // 解压 ZIP
      final archive = ZipDecoder().decodeBytes(bytes);

      // 读 content.json
      final jsonEntry = archive.files.firstWhere(
        (f) => f.name == 'content.json',
        orElse: () => ArchiveFile('', 0, <int>[]),
      );
      if (jsonEntry.name.isEmpty) {
        throw Exception('暂不支持旧版 XMind（content.xml）格式');
      }
      final text = utf8.decode(jsonEntry.content as List<int>);
      final parsed = jsonDecode(text);

      // 解析 sheet[0]
      final sheets = parsed is List ? parsed : parsed['sheets'];
      final sheet = sheets is List
          ? (sheets.isNotEmpty ? sheets[0] : null)
          : (sheets?[0] ?? sheets);

      if (sheet == null) {
        throw Exception('XMind 内容为空');
      }

      _sheetTitle = sheet['title']?.toString() ?? '思维导图';
      final rootTopic = sheet['rootTopic'];
      if (rootTopic == null) {
        throw Exception('XMind 内容为空');
      }

      final root = _parseTopic(rootTopic, '', 0);
      if (mounted) {
        setState(() {
          _root = root;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  TopicNode _parseTopic(dynamic raw, String parentPath, int index) {
    final titleRaw = raw['title'];
    final title = titleRaw is String
        ? titleRaw
        : (titleRaw?['text'] ?? titleRaw?['plain'] ?? '').toString();
    final id = '$parentPath/$index-$title'.substring(
      0,
      '$parentPath/$index-$title'.length > 200
          ? 200
          : '$parentPath/$index-$title'.length,
    );

    final noteRaw = raw['note'];
    final note = noteRaw is String
        ? noteRaw
        : (noteRaw?['plain'] ?? noteRaw?['text'] ?? '').toString();

    final branchColor =
        raw['style']?['properties']?['svg:fill']?.toString();

    final children = <TopicNode>[];
    final attached = raw['children']?['attached'];
    if (attached is List) {
      for (var i = 0; i < attached.length; i++) {
        children.add(_parseTopic(attached[i], id, i));
      }
    }

    return TopicNode(
      id: id,
      title: title.isEmpty ? '(未命名主题)' : title,
      note: note.isEmpty ? null : note,
      branchColor: branchColor,
      children: children,
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_collapsed.contains(id)) {
        _collapsed.remove(id);
      } else {
        _collapsed.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const FileListSkeleton(itemCount: 6);
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '解析失败',
        subtitle: _error,
      );
    }
    final root = _root;
    if (root == null) {
      return const EmptyState(
        icon: Icons.account_tree_outlined,
        title: '内容为空',
      );
    }

    return Column(
      children: [
        // 头部
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _sheetTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.titleMedium.copyWith(
                    color: AppTokens.textPrimary(brightness),
                  ),
                ),
              ),
              Text(
                '${root.totalNodes} 个主题',
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: AppTokens.divider(brightness)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: _buildNode(root, 0, brightness),
          ),
        ),
      ],
    );
  }

  Widget _buildNode(TopicNode node, int depth, Brightness b) {
    final isCollapsed = _collapsed.contains(node.id);
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasChildren ? () => _toggle(node.id) : null,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: Container(
            padding: EdgeInsets.only(
              left: depth * 20.0,
              top: 6,
              bottom: 6,
              right: AppTokens.space8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasChildren)
                  Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 18,
                    color: node.branchColor != null
                        ? _parseColor(node.branchColor!)
                        : AppTokens.brandPrimary,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: AppTokens.space4),
                Flexible(
                  child: Text(
                    node.title,
                    style: (depth == 0
                            ? AppTokens.titleLarge
                            : AppTokens.bodyMedium)
                        .copyWith(
                      color: AppTokens.textPrimary(b),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasChildren && !isCollapsed)
          for (final child in node.children) _buildNode(child, depth + 1, b),
      ],
    );
  }

  Color _parseColor(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      h = 'FF$h';
    }
    final value = int.tryParse(h, radix: 16);
    return value != null ? Color(value) : Colors.grey;
  }
}

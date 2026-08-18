import 'package:flutter/material.dart';

import '../models/folder_node.dart';
import '../services/user_service.dart';

/// 文件夹选择器对话框（用于移动/复制）
///
/// 返回选中的目标文件夹 id；null 表示取消或选择根目录。
Future<String?> showFolderPickerDialog(
  BuildContext context, {
  required String title,
  required String confirmText,
}) async {
  List<FolderNode> tree = [];
  var loading = true;
  String? error;
  String? selectedId;
  String selectedLabel = '根目录';

  try {
    tree = await FileService.instance.getFolderTree();
  } catch (e) {
    error = e.toString();
  } finally {
    loading = false;
  }

  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text('加载失败：$error'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 根目录选项
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.home_outlined),
                            title: const Text('根目录'),
                            selected: selectedId == null,
                            onTap: () => setState(() {
                              selectedId = null;
                              selectedLabel = '根目录';
                            }),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView(
                              children: tree
                                  .map((n) => _FolderNodeTile(
                                        node: n,
                                        depth: 0,
                                        selectedId: selectedId,
                                        onSelect: (id, label) => setState(() {
                                          selectedId = id;
                                          selectedLabel = label;
                                        }),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selectedId),
              child: Text('$confirmText${selectedLabel != '根目录' ? '（$selectedLabel）' : ''}'),
            ),
          ],
        );
      },
    ),
  );
}

class _FolderNodeTile extends StatelessWidget {
  const _FolderNodeTile({
    required this.node,
    required this.depth,
    required this.selectedId,
    required this.onSelect,
  });

  final FolderNode node;
  final int depth;
  final String? selectedId;
  final void Function(String id, String label) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.only(left: 16.0 + depth * 16.0),
          leading: Icon(
            node.isLeaf ? Icons.folder_outlined : Icons.folder,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          selected: selectedId == node.id,
          onTap: () => onSelect(node.id, node.name),
        ),
        for (final child in node.children)
          _FolderNodeTile(
            node: child,
            depth: depth + 1,
            selectedId: selectedId,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

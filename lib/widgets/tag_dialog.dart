import 'package:flutter/material.dart';

import '../models/file_vo.dart';
import '../services/file_tag_service.dart';

/// 文件标签编辑对话框
///
/// 展示标签列表、自动打标、手动添加/删除标签。
Future<void> showTagDialog(BuildContext context, FileVO file) async {
  final tags = await FileTagService.instance.list(file.fileId);

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => TagDialog(file: file, initialTags: tags),
  );
}

class TagDialog extends StatefulWidget {
  const TagDialog({super.key, required this.file, required this.initialTags});

  final FileVO file;
  final List<FileTagItem> initialTags;

  @override
  State<TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<TagDialog> {
  late List<FileTagItem> _tags;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tags = List.of(widget.initialTags);
  }

  Future<void> _autoTag() async {
    setState(() => _loading = true);
    try {
      final result = await FileTagService.instance.autoTag(widget.file.fileId);
      if (mounted) setState(() => _tags = result);
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addTag() async {
    final ctrl = TextEditingController();
    final String? name;
    try {
      name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('添加标签'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: '标签名称'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('添加'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (name == null || name.isEmpty) return;
    try {
      final item = await FileTagService.instance.addTag(widget.file.fileId, name);
      if (mounted) setState(() => _tags = [..._tags, item]);
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _removeTag(FileTagItem tag) async {
    try {
      await FileTagService.instance.removeTag(tag.id);
      if (mounted) {
        setState(() => _tags = _tags.where((t) => t.id != tag.id).toList());
      }
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
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        widget.file.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_tags.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('暂无标签')),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tags)
                    InputChip(
                      label: Text(tag.tagName),
                      avatar: tag.isAuto
                          ? Icon(Icons.auto_awesome,
                              size: 16, color: scheme.primary)
                          : null,
                      onDeleted: () => _removeTag(tag),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _autoTag,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_loading ? '打标中…' : '自动打标'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('手动添加'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

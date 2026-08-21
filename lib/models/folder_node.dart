/// 文件夹树节点，对齐后端 FolderTreeNodeVO（folder/tree）返回结构
///
/// 契约字段固定为：{ id, label, parentId, children }。移除此前 id/fileId、
/// name/label/filename 多字段名猜测的兜底。
class FolderNode {
  const FolderNode({
    required this.id,
    required this.label,
    this.children = const [],
  });

  final String id;
  final String label;
  final List<FolderNode> children;

  bool get isLeaf => children.isEmpty;

  factory FolderNode.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final label = json['label'] as String?;
    if (id == null || id.isEmpty) {
      throw FormatException('FolderNode.id 缺失或为空');
    }
    if (label == null || label.isEmpty) {
      throw FormatException('FolderNode.label 缺失或为空');
    }
    final rawChildren = json['children'] as List<dynamic>? ?? const [];
    return FolderNode(
      id: id,
      label: label,
      children: rawChildren
          .map((e) => FolderNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

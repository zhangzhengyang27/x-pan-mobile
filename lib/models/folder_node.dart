/// 文件夹树节点，对齐后端 folder/tree 返回结构
///
/// 字段兼容 id/fileId、name/label/filename
class FolderNode {
  const FolderNode({
    required this.id,
    required this.name,
    this.children = const [],
  });

  final String id;
  final String name;
  final List<FolderNode> children;

  bool get isLeaf => children.isEmpty;

  factory FolderNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List<dynamic>? ?? const [];
    return FolderNode(
      id: (json['id'] ?? json['fileId'] ?? '') as String,
      name: (json['name'] ?? json['label'] ?? json['filename'] ?? '未命名')
          as String,
      children: rawChildren
          .map((e) => FolderNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

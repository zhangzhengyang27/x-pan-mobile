import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_vo.dart';
import '../services/user_service.dart';

/// 文件列表状态
class FileListState {
  const FileListState({
    this.files = const [],
    this.loading = false,
    this.error,
  });

  final List<FileVO> files;
  final bool loading;
  final String? error;

  FileListState copyWith({
    List<FileVO>? files,
    bool? loading,
    String? error,
  }) {
    return FileListState(
      files: files ?? this.files,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

/// 文件列表控制器
///
/// 维护当前目录栈（面包屑导航）：进入子文件夹压栈，返回上级弹栈。
class FileListNotifier extends StateNotifier<FileListState> {
  FileListNotifier(this._fileService) : super(const FileListState());

  final FileService _fileService;

  /// 当前目录导航栈（最后一项为当前目录）
  final List<BreadcrumbItem> _breadcrumbStack = [];

  List<BreadcrumbItem> get breadcrumbs => List.unmodifiable(_breadcrumbStack);

  String? get currentFolderId =>
      _breadcrumbStack.isEmpty ? null : _breadcrumbStack.last.id;

  bool get canGoBack => _breadcrumbStack.length > 1;

  /// 初始化根目录
  Future<void> initRoot(String rootFileId, String rootName) async {
    _breadcrumbStack.clear();
    _breadcrumbStack.add(BreadcrumbItem(id: rootFileId, name: rootName));
    await load();
  }

  /// 加载当前目录
  Future<void> load() async {
    final parentId = currentFolderId;
    if (parentId == null) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _fileService.list(parentId: parentId);
      state = FileListState(files: page.records);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();

  /// 进入子文件夹（压栈 + 加载）
  Future<void> openFolder(FileVO folder) async {
    _breadcrumbStack.add(BreadcrumbItem(id: folder.fileId, name: folder.filename));
    await load();
  }

  /// 返回上级（弹栈 + 加载）
  Future<void> goBack() async {
    if (_breadcrumbStack.length <= 1) return;
    _breadcrumbStack.removeLast();
    await load();
  }

  /// 跳转到面包屑指定层级
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _breadcrumbStack.length - 1) return;
    _breadcrumbStack.removeRange(index + 1, _breadcrumbStack.length);
    await load();
  }

  /// 新建文件夹
  Future<void> createFolder(String name) async {
    final parentId = currentFolderId;
    if (parentId == null) return;
    await _fileService.createFolder(parentId: parentId, filename: name);
    await load();
  }

  /// 删除文件（fileIds 以 __,__ 分隔）
  Future<void> delete(String fileIds) async {
    await _fileService.delete(fileIds);
    await load();
  }

  /// 重命名
  Future<void> rename(String fileId, String newName) async {
    await _fileService.update(fileId: fileId, filename: newName);
    await load();
  }

  /// 移动
  Future<void> move(String fileIds, String targetParentId) async {
    await _fileService.transfer(
      fileIds: fileIds,
      targetParentId: targetParentId,
    );
    await load();
  }

  /// 复制
  Future<void> copy(String fileIds, String targetParentId) async {
    await _fileService.copy(fileIds: fileIds, targetParentId: targetParentId);
    await load();
  }
}

final fileListProvider =
    StateNotifierProvider<FileListNotifier, FileListState>((ref) {
  return FileListNotifier(FileService.instance);
});

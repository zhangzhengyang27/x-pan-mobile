import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api_response.dart';
import '../models/file_vo.dart';
import '../services/user_service.dart';
import 'view_mode_provider.dart';

/// 每页条数（与后端默认一致，后端上限 1000）
const int _pageSize = 50;

/// 排序字段映射为后端 orderBy 白名单值
///
/// 后端 XPanUserFileMapper.xml 的 SafeOrderBy 仅接受 snake_case 字段
/// （filename / file_size / update_time / create_time），与 Web 端
/// stores/file.ts getOrderBy 的映射保持一致。
String _orderByParam(FileSortField field) {
  switch (field) {
    case FileSortField.name:
      return 'filename';
    case FileSortField.createTime:
      return 'create_time';
    case FileSortField.updateTime:
      return 'update_time';
    case FileSortField.size:
      return 'file_size';
  }
}

/// 文件列表状态
class FileListState {
  const FileListState({
    this.files = const [],
    this.loading = false,
    this.error,
    this.pageNo = 1,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<FileVO> files;
  final bool loading;
  final String? error;

  /// 当前已加载页码（从 1 开始）
  final int pageNo;

  /// 是否还有下一页（滚动加载用）
  final bool hasMore;

  /// 是否正在加载下一页
  final bool loadingMore;

  FileListState copyWith({
    List<FileVO>? files,
    bool? loading,
    String? error,
    int? pageNo,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return FileListState(
      files: files ?? this.files,
      loading: loading ?? this.loading,
      error: error,
      pageNo: pageNo ?? this.pageNo,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// 文件列表控制器
///
/// 维护当前目录栈（面包屑导航）：进入子文件夹压栈，返回上级弹栈。
/// 分页：load() 重置到第 1 页（切目录/排序变更/增删改后都会走这里），
/// loadMore() 追加下一页（列表滚动到底触发）。
class FileListNotifier extends StateNotifier<FileListState> {
  FileListNotifier(this._fileService, this._ref) : super(const FileListState());

  final FileService _fileService;
  final Ref _ref;

  /// 竞态防护：每次请求前自增，响应回来序号不匹配说明已有更新请求，
  /// 直接丢弃过期响应，避免慢请求覆盖新数据。
  int _seq = 0;

  /// 当前目录导航栈（最后一项为当前目录）
  final List<BreadcrumbItem> _breadcrumbStack = [];

  List<BreadcrumbItem> get breadcrumbs => List.unmodifiable(_breadcrumbStack);

  String? get currentFolderId =>
      _breadcrumbStack.isEmpty ? null : _breadcrumbStack.last.id;

  bool get canGoBack => _breadcrumbStack.length > 1;

  /// 当前排序参数（orderBy, order），取自 fileViewModeProvider
  (String, String) get _sortParams {
    final mode = _ref.read(fileViewModeProvider);
    return (_orderByParam(mode.sortField), mode.sortOrder.value);
  }

  /// 初始化根目录
  Future<void> initRoot(String rootFileId, String rootName) async {
    _breadcrumbStack.clear();
    _breadcrumbStack.add(BreadcrumbItem(id: rootFileId, name: rootName));
    await load();
  }

  /// 加载当前目录（重置到第 1 页）
  Future<void> load() async {
    final parentId = currentFolderId;
    if (parentId == null) return;
    final seq = ++_seq;
    final (orderBy, order) = _sortParams;
    state = state.copyWith(loading: true, error: null, loadingMore: false);
    try {
      final page = await _fileService.list(
        parentId: parentId,
        pageNum: 1,
        pageSize: _pageSize,
        orderBy: orderBy,
        order: order,
      );
      if (seq != _seq) return;
      state = FileListState(
        files: page.records,
        pageNo: 1,
        hasMore: _hasMore(page),
      );
    } catch (e) {
      if (seq != _seq) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// 加载下一页（追加模式；由列表滚动到底触发）
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final parentId = currentFolderId;
    if (parentId == null) return;
    final seq = ++_seq;
    final (orderBy, order) = _sortParams;
    final nextPage = state.pageNo + 1;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _fileService.list(
        parentId: parentId,
        pageNum: nextPage,
        pageSize: _pageSize,
        orderBy: orderBy,
        order: order,
      );
      if (seq != _seq) return;
      // 按 fileId 去重追加，避免分页漂移导致重复项
      final known = state.files.map((f) => f.fileId).toSet();
      final fresh =
          page.records.where((f) => !known.contains(f.fileId)).toList();
      state = state.copyWith(
        files: [...state.files, ...fresh],
        pageNo: nextPage,
        hasMore: _hasMore(page),
        loadingMore: false,
      );
    } catch (_) {
      if (seq != _seq) return;
      // 翻页失败不打断现有列表，仅结束本次加载（再次滚动到底可重试）
      state = state.copyWith(loadingMore: false);
    }
  }

  /// 依据后端 PageVO 判断是否还有下一页
  bool _hasMore(PageVO<FileVO> page) {
    if (page.hasMore != null) return page.hasMore!;
    // 对齐后端 PageVO.of：hasMore = pageNum * pageSize < total
    return page.pageNum * _pageSize < page.total;
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
  Future<void> delete(List<String> fileIds) async {
    await _fileService.delete(fileIds);
    await load();
  }

  /// 重命名
  Future<void> rename(String fileId, String newName) async {
    await _fileService.update(fileId: fileId, filename: newName);
    await load();
  }

  /// 移动
  Future<void> move(List<String> fileIds, String targetParentId) async {
    await _fileService.transfer(
      fileIds: fileIds,
      targetParentId: targetParentId,
    );
    await load();
  }

  /// 复制
  Future<void> copy(List<String> fileIds, String targetParentId) async {
    await _fileService.copy(fileIds: fileIds, targetParentId: targetParentId);
    await load();
  }
}

final fileListProvider =
    StateNotifierProvider<FileListNotifier, FileListState>((ref) {
  return FileListNotifier(FileService.instance, ref);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 文件浏览视图模式（对齐主流网盘的列表/网格切换）
enum FileViewMode {
  list, // 列表视图
  grid, // 图标/网格视图
}

/// 排序字段（对应后端 orderBy 参数）
enum FileSortField {
  name('filename'),
  createTime('createTime'),
  updateTime('updateTime'),
  size('fileSize');

  const FileSortField(this.value);
  final String value;
}

/// 排序方向（对应后端 order 参数）
enum FileSortOrder {
  asc('asc'),
  desc('desc');

  const FileSortOrder(this.value);
  final String value;
}

/// 全局文件浏览视图偏好
///
/// 在文件页与分类视图之间共享，切换分类时保留用户选择的视图模式。
class FileViewModeState {
  const FileViewModeState({
    this.viewMode = FileViewMode.list,
    this.sortField = FileSortField.updateTime,
    this.sortOrder = FileSortOrder.desc,
    this.groupByTime = false,
  });

  final FileViewMode viewMode;
  final FileSortField sortField;
  final FileSortOrder sortOrder;
  final bool groupByTime;

  FileViewModeState copyWith({
    FileViewMode? viewMode,
    FileSortField? sortField,
    FileSortOrder? sortOrder,
    bool? groupByTime,
  }) {
    return FileViewModeState(
      viewMode: viewMode ?? this.viewMode,
      sortField: sortField ?? this.sortField,
      sortOrder: sortOrder ?? this.sortOrder,
      groupByTime: groupByTime ?? this.groupByTime,
    );
  }

  String get orderByValue => sortField.value;
  String get orderValue => sortOrder.value;
}

class FileViewModeNotifier extends StateNotifier<FileViewModeState> {
  FileViewModeNotifier() : super(const FileViewModeState());

  void setViewMode(FileViewMode mode) =>
      state = state.copyWith(viewMode: mode);

  void toggleViewMode() => state = state.copyWith(
        viewMode: state.viewMode == FileViewMode.list
            ? FileViewMode.grid
            : FileViewMode.list,
      );

  void setSort(FileSortField field, FileSortOrder order) =>
      state = state.copyWith(sortField: field, sortOrder: order);

  void toggleSortOrder() => state = state.copyWith(
        sortOrder:
            state.sortOrder == FileSortOrder.asc
                ? FileSortOrder.desc
                : FileSortOrder.asc,
      );

  void setGroupByTime(bool group) =>
      state = state.copyWith(groupByTime: group);
}

/// 全局文件浏览视图偏好 Provider
final fileViewModeProvider =
    StateNotifierProvider<FileViewModeNotifier, FileViewModeState>(
  (ref) => FileViewModeNotifier(),
);

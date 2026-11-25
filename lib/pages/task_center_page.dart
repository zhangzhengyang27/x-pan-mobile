import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../services/extract_service.dart';
import '../services/offline_service.dart';
import '../services/task_center_service.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// 统一任务中心：离线下载、在线解压、预览转换、在线压缩。
///
/// 后端已经把多类任务归一成同一状态口径；客户端只负责筛选和动作，
/// 不在本地推断任务状态，避免与服务端状态机分叉。
class TaskCenterPage extends ConsumerStatefulWidget {
  const TaskCenterPage({super.key});

  @override
  ConsumerState<TaskCenterPage> createState() => _TaskCenterPageState();
}

class _TaskCenterPageState extends ConsumerState<TaskCenterPage> {
  List<TaskCenterItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _type;
  int? _status;
  int _page = 1;
  int _total = 0;

  static const _typeOptions = <String?, String>{
    null: '全部',
    'offline': '离线',
    'extract': '解压',
    'archive': '压缩',
    'preview': '预览',
  };
  static const _statusOptions = <int?, String>{
    null: '全部状态',
    0: '等待中',
    1: '进行中',
    2: '已完成',
    3: '失败',
    4: '已取消',
  };

  /// 筛选/刷新可能并发；只允许最后一次请求改写列表。
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (!refresh && (_loading || _loadingMore || _items.length >= _total)) return;
    final seq = ++_loadSeq;
    if (refresh) {
      setState(() {
        _page = 1;
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await TaskCenterService.instance.list(
        types: _type,
        status: _status,
        page: _page,
      );
      if (mounted && seq == _loadSeq) {
        setState(() {
          _items = refresh
              ? page.records
              : [..._items, ...page.records];
          _total = page.total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && seq == _loadSeq) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } finally {
      if (mounted && seq == _loadSeq) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_items.length >= _total) return;
    _page++;
    await _load();
  }

  Future<void> _action(TaskCenterItem item, String action) async {
    try {
      switch (action) {
        case 'cancelOffline':
          await TaskCenterService.instance.cancelOffline(item.taskId);
        case 'cancelArchive':
          await TaskCenterService.instance.cancelArchive(item.taskId);
        case 'retryArchive':
          await TaskCenterService.instance.retryArchive(item.taskId);
        case 'retryOffline':
          await OfflineService.instance.retry(item.taskId);
        case 'retryExtract':
          await ExtractService.instance.retry(item.taskId);
      }
      _toast('操作成功');
      await _load(refresh: true);
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _statusColor(int status) {
    return switch (status) {
      0 => AppTokens.info,
      1 => AppTokens.brandPrimary,
      2 => AppTokens.success,
      3 => AppTokens.error,
      4 => AppTokens.neutral400,
      _ => AppTokens.neutral400,
    };
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'offline' => Icons.cloud_download_outlined,
      'extract' => Icons.unarchive_outlined,
      'archive' => Icons.archive_outlined,
      'preview' => Icons.auto_awesome_outlined,
      _ => Icons.task_alt,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => _load(refresh: true),
          ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final brightness = Theme.of(context).brightness;
    if (_loading) return const FileListSkeleton(itemCount: 5);
    return Column(
      children: [
        _buildFilters(brightness),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppTokens.space8),
            child: Text(
              _error!,
              style: AppTokens.bodySmall.copyWith(color: AppTokens.error),
            ),
          ),
        Expanded(
          child: _items.isEmpty
              ? EmptyState(
                  icon: Icons.task_alt,
                  title: '暂无任务',
                  subtitle: '离线下载、解压和预览转换任务会集中显示在这里',
                  actionLabel: '刷新',
                  actionIcon: Icons.refresh,
                  onAction: () => _load(refresh: true),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space16,
                      vertical: AppTokens.space8,
                    ),
                    itemCount: _items.length + (_items.length < _total ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.space12,
                          ),
                          child: Center(
                            child: _loadingMore
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: _loadMore,
                                    child: const Text('加载更多'),
                                  ),
                          ),
                        );
                      }
                      return _buildItem(_items[i], brightness);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilters(Brightness brightness) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space12,
        AppTokens.space8,
        AppTokens.space12,
        0,
      ),
      child: Row(
        children: [
          ..._typeOptions.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: AppTokens.space8),
              child: FilterChip(
                label: Text(e.value),
                selected: _type == e.key,
                onSelected: (_) {
                  setState(() => _type = e.key);
                  _load(refresh: true);
                },
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          DropdownButton<int?>(
            value: _status,
            hint: const Text('全部状态'),
            underline: const SizedBox.shrink(),
            items: _statusOptions.entries
                .map(
                  (e) => DropdownMenuItem<int?>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _status = value);
              _load(refresh: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItem(TaskCenterItem item, Brightness brightness) {
    final color = _statusColor(item.status);
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      elevation: CardElevation.low,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Icon(_typeIcon(item.taskType), color: color, size: 19),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.taskName.isEmpty ? item.typeText : item.taskName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.titleMedium.copyWith(
                          color: AppTokens.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.typeText} · ${item.statusText} · ${item.createTime}',
                        style: AppTokens.bodySmall.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
                if (item.canCancelOffline)
                  TextButton(
                    onPressed: () => _action(item, 'cancelOffline'),
                    child: const Text('取消'),
                  ),
                if (item.taskType == 'offline' && item.canRetry)
                  TextButton(
                    onPressed: () => _action(item, 'retryOffline'),
                    child: const Text('重试'),
                  ),
                if (item.canCancelArchive)
                  TextButton(
                    onPressed: () => _action(item, 'cancelArchive'),
                    child: const Text('取消'),
                  ),
                if (item.canRetryArchive)
                  TextButton(
                    onPressed: () => _action(item, 'retryArchive'),
                    child: const Text('重试'),
                  ),
                if (item.canRetryExtract)
                  TextButton(
                    onPressed: () => _action(item, 'retryExtract'),
                    child: const Text('重试'),
                  ),
              ],
            ),
            if (item.status == 1) ...[
              const SizedBox(height: AppTokens.space12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                child: LinearProgressIndicator(
                  value: ((item.progress ?? 0) / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppTokens.divider(brightness),
                ),
              ),
            ],
            if (item.errorMsg != null && item.errorMsg!.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space8),
              Text(
                item.errorMsg!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTokens.labelSmall.copyWith(color: AppTokens.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

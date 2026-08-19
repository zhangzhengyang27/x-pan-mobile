import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/recent_storage.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../models/user_info.dart';
import '../../providers/auth_provider.dart';
import '../../providers/upload_provider.dart';
import '../../providers/view_mode_provider.dart';
import '../../services/favorite_service.dart';
import '../../widgets/category_grid.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_type_icon.dart';
import '../dashboard_page.dart';
import '../file/category_files_page.dart';
import '../notification_page.dart';
import '../search_page.dart';
import '../settings_page.dart';

/// 首页容量卡（问候 + 进度条 + 去管理）
class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.user});

  final UserInfo user;

  String _humanize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 100 || i <= 1 ? 0 : 1)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final used = user.usedSize;
    final total = user.totalSize;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.all(AppTokens.space16),
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3366FF), Color(0xFF165DFF)],
        ),
        boxShadow: AppTokens.shadowBrand(brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: Colors.white),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  '网盘空间',
                  style: AppTokens.bodyMedium.copyWith(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .push(AppTokens.route(const DashboardPage())),
                child: const Text(
                  '空间管理 ›',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          Text(
            '已用 ${_humanize(used)} / 共 ${_humanize(total)}',
            style: AppTokens.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// 聚合首页（底部 Tab 的「首页」）
///
/// 内容：容量卡 + 分类直达 + 最近/收藏/下载三 Tab。
class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCategory(
    BuildContext context,
    String label,
    String fileTypesParam,
  ) {
    Navigator.of(context).push(
      AppTokens.route(
        CategoryFilesPage(
          title: label,
          fileTypesParam: fileTypesParam,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final user = ref.watch(authProvider).user;
    final isGrid =
        ref.watch(fileViewModeProvider).viewMode == FileViewMode.grid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('X-Pan'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            tooltip: '搜索',
            onPressed: () => Navigator.of(context)
                .push(AppTokens.route(const SearchPage())),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: '通知',
            onPressed: () => Navigator.of(context)
                .push(AppTokens.route(const NotificationPage())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.of(context)
                .push(AppTokens.route(const SettingsPage())),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (user != null) _StorageCard(user: user),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
            child: Text(
              '分类直达',
              style: AppTokens.titleMedium.copyWith(
                color: AppTokens.textPrimary(brightness),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: CategoryGrid(
              crossAxisCount: isGrid ? 3 : 3,
              onTapCategory: (c) => _openCategory(
                context,
                c.label,
                c.fileTypes.map((t) => t.value).join(','),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTokens.brandPrimary,
              unselectedLabelColor: AppTokens.textSecondary(brightness),
              indicatorColor: AppTokens.brandPrimary,
              tabs: const [
                Tab(text: '最近访问'),
                Tab(text: '我的收藏'),
                Tab(text: '传输中'),
              ],
            ),
          ),
          SizedBox(
            height: 360,
            child: TabBarView(
              controller: _tabController,
              children: const [
                _RecentTab(),
                _FavoriteTab(),
                _TransferTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTab extends ConsumerStatefulWidget {
  const _RecentTab();

  @override
  ConsumerState<_RecentTab> createState() => _RecentTabState();
}

class _RecentTabState extends ConsumerState<_RecentTab> {
  List<RecentItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await RecentStorage.getAll();
    if (mounted) setState(() => _items = items);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const EmptyState(icon: Icons.history, title: '暂无最近访问');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppTokens.space12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = _items[i];
        return ListTile(
          leading: FileTypeIcon(
            type: FileType.fromCode(item.fileType),
            size: 40,
          ),
          title: Text(
            item.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.bodyMedium.copyWith(
              color: AppTokens.textPrimary(brightness),
            ),
          ),
          subtitle: Text(
            item.visitTime,
            style: AppTokens.bodySmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteTab extends ConsumerStatefulWidget {
  const _FavoriteTab();

  @override
  ConsumerState<_FavoriteTab> createState() => _FavoriteTabState();
}

class _FavoriteTabState extends ConsumerState<_FavoriteTab> {
  List<FavoriteFile> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await FavoriteService.instance.list();
      if (mounted) setState(() => _items = list);
    } catch (_) {
      // 收藏接口失败不影响首页
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const EmptyState(icon: Icons.star_outline, title: '暂无收藏');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppTokens.space12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final f = _items[i];
        return ListTile(
          leading: FileTypeIcon(type: f.fileType, size: 40),
          title: Text(
            f.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.bodyMedium.copyWith(
              color: AppTokens.textPrimary(brightness),
            ),
          ),
          subtitle: Text(
            f.fileSizeDesc,
            style: AppTokens.bodySmall.copyWith(
              color: AppTokens.textSecondary(brightness),
            ),
          ),
        );
      },
    );
  }
}

class _TransferTab extends ConsumerWidget {
  const _TransferTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final queue = ref.watch(uploadManagerProvider);
    final active = queue.tasks
        .where(
          (t) =>
              t.status == UploadStatus.uploading ||
              t.status == UploadStatus.waiting,
        )
        .toList();
    if (active.isEmpty) {
      return const EmptyState(
        icon: Icons.cloud_sync_outlined,
        title: '暂无传输任务',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppTokens.space12),
      itemCount: active.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final t = active[i];
        final pct = (t.progress * 100).toStringAsFixed(0);
        return ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: Text(
            t.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.bodyMedium.copyWith(
              color: AppTokens.textPrimary(brightness),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t.statusText} · $pct%',
                style: AppTokens.bodySmall.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: t.progress,
                minHeight: 4,
                backgroundColor: AppTokens.divider(brightness),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTokens.brandPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

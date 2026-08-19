import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../utils/file_open.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_type_icon.dart';

/// 文档分类视图：顶部子类型 Tab（全部/Word/Excel/PPT/PDF/文本）+ 时间轴列表
/// （参考前端 DocViewer 的子类型过滤 + 时间轴分组）
class DocCategoryView extends StatefulWidget {
  const DocCategoryView({super.key, required this.files});

  final List<FileVO> files;

  @override
  State<DocCategoryView> createState() => _DocCategoryViewState();
}

class _DocCategoryViewState extends State<DocCategoryView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    ('全部', null),
    ('Word', FileType.word),
    ('Excel', FileType.excel),
    ('PPT', FileType.ppt),
    ('PDF', FileType.pdf),
    ('文本', FileType.txt),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<FileVO> _filtered(int index) {
    final type = _tabs[index].$2;
    if (type == null) return widget.files;
    return widget.files.where((f) => f.fileType == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Container(
          color: AppTokens.surface(brightness),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerHeight: 0,
            indicatorColor: brightness == Brightness.dark
                ? AppTokens.brandPrimaryDark
                : AppTokens.brandPrimary,
            labelColor: AppTokens.textPrimary(brightness),
            unselectedLabelColor: AppTokens.textSecondary(brightness),
            labelStyle: AppTokens.labelSmall,
            tabs: [
              for (final t in _tabs) Tab(text: t.$1),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (int i = 0; i < _tabs.length; i++)
                _DocList(files: _filtered(i)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocList extends StatelessWidget {
  const _DocList({required this.files});
  final List<FileVO> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const EmptyState(icon: Icons.description_outlined, title: '暂无文档');
    }
    final groups = groupByTimeline(files);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      itemCount: groups.length,
      itemBuilder: (ctx, gi) {
        final (label, files) = groups[gi];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space16,
                AppTokens.space16,
                AppTokens.space4,
              ),
              child: Text(
                label,
                style: AppTokens.labelSmall.copyWith(
                  color: AppTokens.textSecondary(
                    Theme.of(context).brightness,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final file in files)
              _DocTile(
                file: file,
                onTap: () => openFileByType(context, file),
              ),
          ],
        );
      },
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.file, required this.onTap});
  final FileVO file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ListTile(
      leading: FileTypeIcon(type: file.fileType, size: 40),
      title: Text(
        file.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTokens.bodyMedium.copyWith(
          color: AppTokens.textPrimary(brightness),
        ),
      ),
      subtitle: Text(
        file.fileSizeDesc ?? '',
        style: AppTokens.bodySmall.copyWith(
          color: AppTokens.textSecondary(brightness),
        ),
      ),
      onTap: onTap,
    );
  }
}

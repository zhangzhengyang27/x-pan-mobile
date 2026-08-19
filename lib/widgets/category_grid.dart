import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';

/// 文件分类定义（首页/文件页分类直达）
class FileCategory {
  const FileCategory({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.fileTypes,
  });

  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final List<FileType> fileTypes;
}

/// 分类配置（图片/视频/文档/音频/应用/其他）
///
/// fileTypes 用于拼接 `FileService.list(fileTypes:)` 的逗号分隔参数。
const List<FileCategory> kFileCategories = [
  FileCategory(
    label: '图片',
    icon: Icons.image_outlined,
    gradient: LinearGradient(
      colors: [Color(0xFF5B8DEF), Color(0xFF3B6FE0)],
    ),
    fileTypes: [FileType.image],
  ),
  FileCategory(
    label: '视频',
    icon: Icons.play_circle_outline,
    gradient: LinearGradient(
      colors: [Color(0xFFE06BA6), Color(0xFFC44B8F)],
    ),
    fileTypes: [FileType.video],
  ),
  FileCategory(
    label: '文档',
    icon: Icons.description_outlined,
    gradient: LinearGradient(
      colors: [Color(0xFF4FB0A5), Color(0xFF2E8E84)],
    ),
    fileTypes: [
      FileType.excel,
      FileType.word,
      FileType.pdf,
      FileType.txt,
      FileType.ppt,
      FileType.csv,
    ],
  ),
  FileCategory(
    label: '音频',
    icon: Icons.audiotrack_outlined,
    gradient: LinearGradient(
      colors: [Color(0xFF9B7BE0), Color(0xFF7A57C8)],
    ),
    fileTypes: [FileType.audio],
  ),
  FileCategory(
    label: '应用',
    icon: Icons.apps_outlined,
    gradient: LinearGradient(
      colors: [Color(0xFFF0A04B), Color(0xFFE0802B)],
    ),
    fileTypes: [FileType.code, FileType.archive],
  ),
  FileCategory(
    label: '其他',
    icon: Icons.folder_outlined,
    gradient: LinearGradient(
      colors: [Color(0xFF7C8794), Color(0xFF5C6773)],
    ),
    fileTypes: [FileType.normal],
  ),
];

/// 把 FileType 列表拼成后端需要的逗号分隔字符串
String categoryToFileTypesParam(List<FileType> types) =>
    types.map((t) => t.value).join(',');

/// 分类网格组件（首页/文件页共用）
///
/// 采用 2 列等宽网格（左大右 2x2 在首页由调用方排版，这里统一网格）。
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    this.crossAxisCount = 3,
    this.onTapCategory,
  });

  final int crossAxisCount;
  final void Function(FileCategory category)? onTapCategory;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppTokens.space12,
      crossAxisSpacing: AppTokens.space12,
      childAspectRatio: 1.15,
      children: [
        for (final c in kFileCategories)
          _CategoryCell(
            category: c,
            brightness: brightness,
            onTap: onTapCategory == null ? null : () => onTapCategory!(c),
          ),
      ],
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.category,
    required this.brightness,
    this.onTap,
  });

  final FileCategory category;
  final Brightness brightness;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          color: AppTokens.surfaceElevated(brightness),
          border: Border.all(
            color: AppTokens.divider(brightness).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: category.gradient,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Icon(category.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              category.label,
              style: AppTokens.labelSmall.copyWith(
                color: AppTokens.textPrimary(brightness),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

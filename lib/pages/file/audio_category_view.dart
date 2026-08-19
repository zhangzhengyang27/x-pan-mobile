import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/file_vo.dart';
import '../../utils/file_open.dart';
import '../../widgets/empty_state.dart';

/// 音频分类视图：歌曲列表 + 播放按钮（参考前端 MusicViewer）
class AudioCategoryView extends StatelessWidget {
  const AudioCategoryView({super.key, required this.files});

  final List<FileVO> files;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (files.isEmpty) {
      return const EmptyState(icon: Icons.audiotrack_outlined, title: '暂无音频');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
      itemCount: files.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: AppTokens.space16 + 56,
        color: AppTokens.divider(brightness),
      ),
      itemBuilder: (ctx, i) {
        final file = files[i];
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (brightness == Brightness.dark
                    ? AppTokens.brandPrimaryDark
                    : AppTokens.brandPrimary)
                .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Icon(
              Icons.music_note,
              color: brightness == Brightness.dark
                  ? AppTokens.brandPrimaryDark
                  : AppTokens.brandPrimary,
            ),
          ),
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
          trailing: Icon(
            Icons.play_circle_outline,
            color: brightness == Brightness.dark
                ? AppTokens.brandPrimaryDark
                : AppTokens.brandPrimary,
          ),
          onTap: () => openFileByType(context, file),
        );
      },
    );
  }
}

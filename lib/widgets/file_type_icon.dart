import 'package:flutter/material.dart';

import '../models/file_vo.dart';

/// 文件类型图标（对齐前端 getFileFontElement）
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({super.key, required this.type, this.size = 40});

  final FileType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _resolve(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }

  (IconData, Color) _resolve(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case FileType.folder:
        return (Icons.folder, const Color(0xFFF59E0B));
      case FileType.archive:
        return (Icons.inventory_2_outlined, const Color(0xFF8B5CF6));
      case FileType.excel:
        return (Icons.grid_on, const Color(0xFF10B981));
      case FileType.word:
        return (Icons.description_outlined, const Color(0xFF3B82F6));
      case FileType.pdf:
        return (Icons.picture_as_pdf_outlined, const Color(0xFFEF4444));
      case FileType.txt:
        return (Icons.notes_outlined, const Color(0xFF64748B));
      case FileType.image:
        return (Icons.image_outlined, const Color(0xFFEC4899));
      case FileType.audio:
        return (Icons.headphones_outlined, const Color(0xFF14B8A6));
      case FileType.video:
        return (Icons.videocam_outlined, const Color(0xFFF97316));
      case FileType.ppt:
        return (Icons.slideshow_outlined, const Color(0xFFF43F5E));
      case FileType.code:
        return (Icons.code, const Color(0xFF0EA5E9));
      case FileType.csv:
        return (Icons.table_chart_outlined, const Color(0xFF22C55E));
      case FileType.normal:
        return (Icons.insert_drive_file_outlined, scheme.onSurfaceVariant);
    }
  }
}

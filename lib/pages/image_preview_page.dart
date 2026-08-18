import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/file_vo.dart';
import '../services/user_service.dart';

/// 图片预览页
class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.files,
    required this.initialIndex,
  });

  final List<FileVO> files;
  final int initialIndex;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late int _index;
  final Map<String, Future<String>> _urlCache = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  Future<String> _urlOf(FileVO file) {
    return _urlCache.putIfAbsent(
      file.fileId,
      () => FileService.instance.resolvePreviewUrl(file.fileId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.files[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          file.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: GestureDetector(
        onTapDown: (details) {
          // 左右点击区域翻页
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 2) {
            _prev();
          } else {
            _next();
          }
        },
        child: Center(
          child: FutureBuilder<String>(
            future: _urlOf(file),
            builder: (ctx, snapshot) {
              if (snapshot.hasData) {
                return CachedNetworkImage(
                  imageUrl: snapshot.data!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white54, size: 64),
                  ),
                );
              }
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  void _next() {
    if (_index < widget.files.length - 1) {
      setState(() => _index++);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
    }
  }
}

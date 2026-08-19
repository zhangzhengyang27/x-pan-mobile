import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_tokens.dart';
import '../models/file_vo.dart';
import '../services/user_service.dart';
import '../widgets/skeleton.dart';

/// 图片预览页
///
/// PageView 滑动翻页 + 双指缩放 + 透明渐隐 AppBar + 底部翻页指示器。
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
  late final PageController _pageCtrl;
  final Map<String, Future<String>> _urlCache = {};
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    // 沉浸式：隐藏状态栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<String> _urlOf(FileVO file) {
    return _urlCache.putIfAbsent(
      file.fileId,
      () => FileService.instance.resolvePreviewUrl(file.fileId)
          .catchError((e) {
        // 解析失败不缓存错误 Future，下次翻页可重试
        _urlCache.remove(file.fileId);
        throw e;
      }),
    );
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  @override
  Widget build(BuildContext context) {
    final file = widget.files[_index];
    final total = widget.files.length;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _chromeVisible
            ? const Color(0x99000000)
            : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: _chromeVisible
            ? Text(
                file.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTokens.titleLarge.copyWith(color: Colors.white),
              )
            : null,
      ),
      body: Stack(
        children: [
          // PageView 翻页 + 双指缩放
          PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (ctx, i) => _buildImage(widget.files[i]),
          ),
          // 底部翻页指示器（圆角胶囊）
          if (_chromeVisible && total > 1)
            Positioned(
              bottom: AppTokens.space32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space16,
                    vertical: AppTokens.space8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusFull),
                  ),
                  child: Text(
                    '${_index + 1} / $total',
                    style: AppTokens.labelLarge.copyWith(
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(FileVO file) {
    return GestureDetector(
      onTap: _toggleChrome,
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: FutureBuilder<String>(
            future: _urlOf(file),
            builder: (ctx, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                );
              }
              if (snapshot.hasData) {
                return CachedNetworkImage(
                  imageUrl: snapshot.data!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SkeletonBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                );
              }
              return const SkeletonBox(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              );
            },
          ),
        ),
      ),
    );
  }
}

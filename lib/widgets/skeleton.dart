import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// 骨架屏加载组件
///
/// 微光 shimmer 动效，用于替换 `CircularProgressIndicator` 的加载态。
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppTokens.radiusSm,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final baseColor = brightness == Brightness.dark
        ? AppTokens.darkSurfaceElevated
        : AppTokens.neutral100;
    final highlightColor = brightness == Brightness.dark
        ? AppTokens.darkBorder
        : AppTokens.neutral200;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => ShaderMask(
        shaderCallback: (rect) {
          final dx = _controller.value * rect.width * 2 - rect.width;
          return LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.topRight,
            colors: [baseColor, highlightColor, baseColor],
            stops: [0.0, 0.5, 1.0],
            transform: GradientTranslation(dx),
          ).createShader(rect);
        },
        child: child,
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// 渐变平移变换，用于 shimmer
class GradientTranslation extends GradientTransform {
  const GradientTranslation(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// 文件列表骨架屏
class FileListSkeleton extends StatelessWidget {
  const FileListSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space8,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTokens.space12),
        child: Row(
          children: [
            SkeletonBox(width: 40, height: 40, borderRadius: 10),
            SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14),
                  SizedBox(height: 6),
                  SkeletonBox(width: 120, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片骨架屏（用于仪表盘等）
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 120, height: 16),
          SizedBox(height: AppTokens.space16),
          SkeletonBox(height: 10),
          SizedBox(height: AppTokens.space8),
          SkeletonBox(height: 10),
        ],
      ),
    );
  }
}

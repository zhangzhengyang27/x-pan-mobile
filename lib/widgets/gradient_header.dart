import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// 渐变头部组件
///
/// 用于登录页、仪表盘等需要品牌氛围的页面顶部，呈现深邃蓝渐变背景。
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.child,
    this.height = 220,
    this.gradient = AppTokens.brandGradient,
    this.safeArea = true,
  });

  final Widget child;
  final double height;
  final Gradient gradient;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      child: SizedBox(height: height, child: child),
    );
    if (safeArea) {
      content = SafeArea(bottom: false, child: content);
    }
    return content;
  }
}

/// 品牌圆形 Logo 容器（玻璃拟态）
class BrandLogoBadge extends StatelessWidget {
  const BrandLogoBadge({
    super.key,
    this.size = 64,
    this.icon = Icons.cloud_outlined,
  });

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTokens.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppTokens.brandPrimary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: Colors.white,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// 高级感卡片组件
///
/// 多层柔和阴影 + 圆角 + 可选渐变边框，用于替换裸 `Card`。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.margin,
    this.onTap,
    this.gradient,
    this.elevation = CardElevation.medium,
    this.borderRadius = AppTokens.radiusLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final CardElevation elevation;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final shadows = switch (elevation) {
      CardElevation.none => <BoxShadow>[],
      CardElevation.low => AppTokens.shadowSm(brightness),
      CardElevation.medium => AppTokens.shadowMd(brightness),
      CardElevation.high => AppTokens.shadowLg(brightness),
    };

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? AppTokens.surface(brightness) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
        border: gradient == null
            ? Border.all(
                color: AppTokens.divider(brightness).withValues(alpha: 0.5),
                width: 0.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum CardElevation { none, low, medium, high }

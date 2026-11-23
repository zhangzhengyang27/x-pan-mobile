import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// 高级感空状态组件
///
/// 统一空状态：中性图标框 + 标题 + 副标题 + 可选操作按钮。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 操作按钮图标，默认 +（新建语义）；重试类场景可传 Icons.refresh
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space32,
          vertical: AppTokens.space48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 统一空态：低层级品牌底 + 中性 border，不再使用高饱和渐变
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTokens.brandPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTokens.radiusPanel),
                border: Border.all(
                  color: AppTokens.divider(brightness),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 28,
                color: AppTokens.brandAction,
              ),
            ),
            const SizedBox(height: AppTokens.space24),
            Text(
              title,
              style: AppTokens.titleMedium.copyWith(
                color: AppTokens.textPrimary(brightness),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTokens.space8),
              Text(
                subtitle!,
                style: AppTokens.bodyMedium.copyWith(
                  color: AppTokens.textSecondary(brightness),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTokens.space24),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

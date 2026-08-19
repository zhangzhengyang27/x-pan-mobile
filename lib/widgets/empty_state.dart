import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// 高级感空状态组件
///
/// 渐变图标背景 + 标题 + 副标题 + 可选操作按钮，替换裸图标+文字。
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
            // 渐变圆形图标背景
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTokens.brandPrimary.withValues(alpha: 0.12),
                    AppTokens.brandSecondary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              ),
              child: Icon(
                icon,
                size: 44,
                color: AppTokens.brandPrimary,
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

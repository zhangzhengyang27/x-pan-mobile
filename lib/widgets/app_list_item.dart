import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// 高级感列表项
///
/// 用于文件列表、设置项等，提供统一的留白、圆角、选中态与点击反馈。
class AppListItem extends StatefulWidget {
  const AppListItem({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTokens.space16,
      vertical: AppTokens.space12,
    ),
    this.showDivider = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  @override
  State<AppListItem> createState() => _AppListItemState();
}

class _AppListItemState extends State<AppListItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: AppTokens.durationFast,
        curve: AppTokens.curveStandard,
        decoration: BoxDecoration(
          color: widget.selected
              ? AppTokens.brandPrimary.withValues(alpha: 0.08)
              : _pressed
                  ? AppTokens.surface(brightness).withValues(alpha: 0.6)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 带前缀图标 + 标题 + 副标题 + 尾部的标准列表项
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AppListItem(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppTokens.space12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTokens.bodyLarge.copyWith(
                    color: AppTokens.textPrimary(brightness),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTokens.bodySmall.copyWith(
                      color: AppTokens.textSecondary(brightness),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTokens.space8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

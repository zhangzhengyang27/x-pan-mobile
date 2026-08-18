import 'package:flutter/material.dart';

/// 桌面端断点阈值（逻辑像素宽度）
const double kDesktopBreakpoint = 900;

/// 判断当前是否为宽屏（桌面端）
///
/// 移动端窄屏返回 false，保持原有移动布局；
/// 桌面端宽屏返回 true，启用侧边栏 / 居中限宽布局。
bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= kDesktopBreakpoint;

/// 二级页面内容的响应式包裹
///
/// 桌面端宽屏时内容居中并限制最大宽度，移动端保持全宽。
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.horizontalPadding = 16,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) {
      return child;
    }
    // 占满宽高，内部水平居中并限制最大宽度
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 8,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

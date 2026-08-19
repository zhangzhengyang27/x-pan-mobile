import 'package:flutter/material.dart';

/// X-Pan Design Token 体系
///
/// 科技动感风格（阿里云盘风）—— 深邃蓝主色 + 卡片化 + 数据可视化突出。
/// 所有视觉数值集中于此，页面与组件只引用 Token，禁止硬编码。
class AppTokens {
  AppTokens._();

  // ─── 品牌色（深邃蓝 #3366FF）─────────────────────────────────
  static const Color brandPrimary = Color(0xFF3366FF);
  static const Color brandPrimaryDark = Color(0xFF165DFF);
  static const Color brandSecondary = Color(0xFF00D4C7); // 数据可视化辅色
  static const Color brandAccent = Color(0xFF7C3AED); // 强调态辅色

  /// 品牌渐变（主按钮 / 品牌区头部）
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3366FF), Color(0xFF165DFF)],
  );

  /// 品牌渐变（数据可视化，蓝→青）
  static const LinearGradient dataGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF3366FF), Color(0xFF00D4C7)],
  );

  /// 品牌色阶 50-900
  static const Map<int, Color> brandScale = {
    50: Color(0xFFEBF1FF),
    100: Color(0xFFD6E4FF),
    200: Color(0xFFADC8FF),
    300: Color(0xFF84ABFF),
    400: Color(0xFF5B8FFF),
    500: Color(0xFF3366FF), // 主色
    600: Color(0xFF1A55F0),
    700: Color(0xFF165DFF),
    800: Color(0xFF0F47CC),
    900: Color(0xFF0A3299),
  };

  // ─── 语义色 ────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3366FF);

  // ─── 中性色阶（浅色）──────────────────────────────────────────
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF7F9FC);
  static const Color neutral100 = Color(0xFFF1F4F9);
  static const Color neutral200 = Color(0xFFE4E9F2);
  static const Color neutral300 = Color(0xFFCBD3E0);
  static const Color neutral400 = Color(0xFF94A0B8);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);

  // ─── 中性色阶（暗色）──────────────────────────────────────────
  static const Color darkBg = Color(0xFF0B0E14); // 最底层
  static const Color darkSurface = Color(0xFF131722); // 卡片
  static const Color darkSurfaceElevated = Color(0xFF1B2030); // 弹层
  static const Color darkBorder = Color(0xFF252B3B);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // ─── 字体梯度 ──────────────────────────────────────────────────
  static const String fontFamily = 'SF Pro Display'; // iOS 系统字体，Android 回退 Roboto

  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.1,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.3,
  );

  // ─── 间距（8pt 栅格）──────────────────────────────────────────
  static const double space3 = 3; // 细分隔
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // ─── 圆角 ──────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;

  // ─── 阴影（多层柔和阴影，营造立体感）──────────────────────────
  static List<BoxShadow> shadowSm(Brightness brightness) => [
        BoxShadow(
          color: (brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF1E293B))
              .withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> shadowMd(Brightness brightness) => [
        BoxShadow(
          color: (brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF1E293B))
              .withValues(alpha: brightness == Brightness.dark ? 0.3 : 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: (brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF1E293B))
              .withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> shadowLg(Brightness brightness) => [
        BoxShadow(
          color: (brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF1E293B))
              .withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: (brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF1E293B))
              .withValues(alpha: brightness == Brightness.dark ? 0.25 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// 品牌色阴影（用于主按钮 / FAB，带品牌色光晕）
  static List<BoxShadow> shadowBrand(Brightness brightness) => [
        BoxShadow(
          color: brandPrimary.withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.3),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  // ─── 动效 ──────────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationBase = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationSlower = Duration(milliseconds: 600);

  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEmphasized = Curves.easeInOutCubicEmphasized;
  static const Curve curveDecelerate = Curves.decelerate;

  // ─── 页面转场 ──────────────────────────────────────────────────
  /// 从右滑入 + 淡入，带 emphasized 曲线
  static Route<T> route<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: curveEmphasized);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: durationBase,
      reverseTransitionDuration: durationFast,
    );
  }

  // ─── 便捷语义访问 ──────────────────────────────────────────────
  static Color surface(Brightness b) =>
      b == Brightness.dark ? darkSurface : neutral0;
  static Color surfaceElevated(Brightness b) =>
      b == Brightness.dark ? darkSurfaceElevated : neutral0;
  static Color background(Brightness b) =>
      b == Brightness.dark ? darkBg : neutral50;
  static Color textPrimary(Brightness b) =>
      b == Brightness.dark ? darkTextPrimary : neutral900;
  static Color textSecondary(Brightness b) =>
      b == Brightness.dark ? darkTextSecondary : neutral500;
  static Color textTertiary(Brightness b) =>
      b == Brightness.dark ? darkTextSecondary.withValues(alpha: 0.6) : neutral400;
  static Color divider(Brightness b) =>
      b == Brightness.dark ? darkBorder : neutral200;
  static Color outline(Brightness b) =>
      b == Brightness.dark ? darkBorder : neutral300;
}

import 'package:flutter/material.dart';

/// X-Pan Design Token 体系
///
/// 统一设计系统 —— X-Pan Blue + 中性表面阶梯 + 克制阴影。
/// 所有视觉数值集中于此，页面与组件只引用 Token，禁止硬编码。
class AppTokens {
  AppTokens._();

  // ─── 品牌色（深邃蓝 #3366FF）─────────────────────────────────
  static const Color brandPrimary = Color(0xFF3366FF);
  static const Color brandPrimaryDark = Color(0xFF1A55F0);
  static const Color brandAction = Color(0xFF245BFF); // 白字按钮/链接，AA 5.23:1
  static const Color brandActionActive = Color(0xFF1B47C4); // 按下态
  static const Color brandSecondary = Color(0xFF5B8FFF); // 数据可视化辅色，保持蓝色单色系
  static const Color brandAccent = Color(0xFF84ABFF); // 强调态辅色
  static const Color brandSoft = Color(0xFFEDF2FF); // 浅色品牌底
  static const Color brandSky = Color(0xFF00A3FF); // 仅装饰/插画，不承托白字

  /// 品牌渐变（主按钮 / 品牌区头部）
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3366FF), Color(0xFF245BFF)],
  );

  /// 品牌渐变（数据可视化，深浅两级蓝）
  static const LinearGradient dataGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF3366FF), Color(0xFF5B8FFF)],
  );

  /// 品牌色阶 50-900
  static const Map<int, Color> brandScale = {
    50: Color(0xFFEBF1FF),
    100: Color(0xFFD6E4FF),
    200: Color(0xFFADC8FF),
    300: Color(0xFF84ABFF),
    400: Color(0xFF5B8FFF),
    500: Color(0xFF3366FF), // 主色
    600: Color(0xFF245BFF), // 交互填充
    700: Color(0xFF1A55F0),
    800: Color(0xFF15399E),
    900: Color(0xFF102C78),
  };

  // ─── 语义色 ────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3366FF);

  /// 状态前景对：浅底小字/深色填充，避免白字或亮色小字不可读
  static const Color successText = Color(0xFF067647);
  static const Color warningText = Color(0xFFB54708);
  static const Color dangerText = Color(0xFFB42318);
  static const Color successTextDark = Color(0xFF6CE9A6);
  static const Color warningTextDark = Color(0xFFFEC84B);
  static const Color dangerTextDark = Color(0xFFFDA29B);

  // ─── 中性色阶（浅色）──────────────────────────────────────────
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF7F8F8);
  static const Color neutral100 = Color(0xFFF3F4F5);
  static const Color neutral150 = Color(0xFFE9EAEC); // 表头/三级表面
  static const Color neutral200 = Color(0xFFE4E6E8);
  static const Color neutral300 = Color(0xFFD0D6E0);
  static const Color neutral400 = Color(0xFFB4B8BE);
  static const Color neutral500 = Color(0xFF8A8F98);
  static const Color neutral600 = Color(0xFF4B5058);
  static const Color neutral700 = Color(0xFF34373B);
  static const Color neutral800 = Color(0xFF232528);
  static const Color neutral900 = Color(0xFF1D1D1F);

  // ─── 中性色阶（暗色）──────────────────────────────────────────
  static const Color darkBg = Color(0xFF08090A); // 最底层
  static const Color darkSurface = Color(0xFF0F1011); // 卡片
  static const Color darkSurfaceElevated = Color(0xFF191A1B); // 弹层
  static const Color darkSurface3 = Color(0xFF28282C); // 高层容器
  static const Color darkBorder = Color(0xFF2A2B2E);
  static const Color darkBorderStrong = Color(0xFF34343A);
  static const Color darkTextPrimary = Color(0xFFF7F8F8);
  static const Color darkTextSecondary = Color(0xFFD0D6E0);
  static const Color darkTextMuted = Color(0xFF8A8F98);
  static const Color darkTextDisabled = Color(0xFF62666D);

  // ─── 字体梯度 ──────────────────────────────────────────────────
  static const String fontFamily = 'SF Pro Display'; // iOS 系统字体，Android 回退 Roboto

  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
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

  // ─── 圆角：形状层级与 Web/Desktop 对齐，移动端整体 +2px 适配触控 ───
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;
  static const double radiusControl = 8;
  static const double radiusCard = 12;
  static const double radiusPanel = 16;
  static const double radiusSheet = 16;

  // ─── 阴影：低层级、低透明度；不依赖品牌光晕建立层级 ───────────────
  static List<BoxShadow> shadowSm(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.28 : 0.03,
          ),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> shadowMd(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.32 : 0.04,
          ),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.16 : 0.02,
          ),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> shadowLg(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.38 : 0.06,
          ),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.20 : 0.03,
          ),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// 品牌色阴影：仅用于主按钮/FAB 的轻提示，不再做大面积光晕
  static List<BoxShadow> shadowBrand(Brightness brightness) => [
        BoxShadow(
          color: brandAction.withValues(
            alpha: brightness == Brightness.dark ? 0.20 : 0.12,
          ),
          blurRadius: 10,
          offset: const Offset(0, 2),
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
  static Color textDisabled(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF62666D) : neutral400;
  static Color divider(Brightness b) =>
      b == Brightness.dark ? darkBorder : neutral200;
  static Color outline(Brightness b) =>
      b == Brightness.dark ? darkBorder : neutral300;
  static Color action(Brightness b) =>
      b == Brightness.dark ? brandSecondary : brandAction;
}

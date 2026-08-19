import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

/// 全局主题
///
/// 科技动感风格 —— 深邃蓝品牌色 #3366FF，卡片化 + 多层阴影 + 精细动效。
/// 所有视觉数值来自 [AppTokens]，禁止在此硬编码颜色/间距/圆角。
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.brandPrimary,
      brightness: brightness,
      primary: AppTokens.brandPrimary,
      secondary: AppTokens.brandSecondary,
      error: AppTokens.error,
      surface: AppTokens.surface(brightness),
      onSurface: AppTokens.textPrimary(brightness),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppTokens.background(brightness),
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,

      // ─── 字体 ──────────────────────────────────────────────
      textTheme: _buildTextTheme(brightness),
      primaryTextTheme: _buildTextTheme(brightness),

      // ─── AppBar ───────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppTokens.background(brightness),
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTokens.textPrimary(brightness),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: AppTokens.titleLarge.copyWith(
          color: AppTokens.textPrimary(brightness),
        ),
        iconTheme: IconThemeData(
          color: AppTokens.textPrimary(brightness),
          size: 22,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // ─── Card ─────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppTokens.surface(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── 输入框 ───────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppTokens.darkSurfaceElevated
            : AppTokens.neutral100,
        hintStyle: AppTokens.bodyMedium.copyWith(
          color: AppTokens.textTertiary(brightness),
        ),
        labelStyle: AppTokens.bodyMedium.copyWith(
          color: AppTokens.textSecondary(brightness),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(
            color: AppTokens.divider(brightness),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(
            color: AppTokens.brandPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space14,
        ),
      ),

      // ─── 按钮 ─────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 仅约束高度、不撑满宽度（保证弹窗内取消/确定按钮可并排展示）
          minimumSize: const Size(0, 48),
          backgroundColor: AppTokens.brandPrimary,
          foregroundColor: Colors.white,
          textStyle: AppTokens.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.surface(brightness),
          foregroundColor: AppTokens.textPrimary(brightness),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          side: BorderSide(color: AppTokens.divider(brightness)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppTokens.brandPrimary,
          textStyle: AppTokens.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.brandPrimary,
          side: const BorderSide(color: AppTokens.brandPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),

      // ─── FAB ──────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppTokens.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),

      // ─── ListTile ─────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: AppTokens.textSecondary(brightness),
        textColor: AppTokens.textPrimary(brightness),
        titleTextStyle: AppTokens.bodyLarge.copyWith(
          color: AppTokens.textPrimary(brightness),
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: AppTokens.bodySmall.copyWith(
          color: AppTokens.textSecondary(brightness),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),

      // ─── Divider ──────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: AppTokens.divider(brightness),
        thickness: 1,
        space: 1,
      ),

      // ─── SnackBar ─────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppTokens.darkSurfaceElevated : AppTokens.neutral900,
        contentTextStyle: AppTokens.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        elevation: 4,
      ),

      // ─── BottomSheet ──────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppTokens.surface(brightness),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppTokens.surface(brightness),
        modalElevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusXl),
          ),
        ),
      ),

      // ─── Dialog ───────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.surface(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        titleTextStyle: AppTokens.titleLarge.copyWith(
          color: AppTokens.textPrimary(brightness),
        ),
        contentTextStyle: AppTokens.bodyMedium.copyWith(
          color: AppTokens.textSecondary(brightness),
        ),
      ),

      // ─── ProgressIndicator ────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppTokens.brandPrimary,
        linearTrackColor: Color(0x1A3366FF),
      ),

      // ─── Chip ─────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppTokens.darkSurfaceElevated
            : AppTokens.neutral100,
        selectedColor: AppTokens.brandPrimary.withValues(alpha: 0.12),
        labelStyle: AppTokens.labelSmall.copyWith(
          color: AppTokens.textSecondary(brightness),
        ),
        side: BorderSide(color: AppTokens.divider(brightness)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        ),
      ),

      // ─── Icon ─────────────────────────────────────────────
      iconTheme: IconThemeData(
        color: AppTokens.textSecondary(brightness),
        size: 22,
      ),

      // ─── 页面转场 ─────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _ZoomFadeTransitionBuilder(),
          TargetPlatform.iOS: _ZoomFadeTransitionBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final primary = AppTokens.textPrimary(brightness);
    final secondary = AppTokens.textSecondary(brightness);
    return TextTheme(
      displayLarge: AppTokens.displayLarge.copyWith(color: primary),
      displayMedium: AppTokens.displayMedium.copyWith(color: primary),
      headlineLarge: AppTokens.headlineLarge.copyWith(color: primary),
      headlineMedium: AppTokens.headlineMedium.copyWith(color: primary),
      titleLarge: AppTokens.titleLarge.copyWith(color: primary),
      titleMedium: AppTokens.titleMedium.copyWith(color: primary),
      bodyLarge: AppTokens.bodyLarge.copyWith(color: primary),
      bodyMedium: AppTokens.bodyMedium.copyWith(color: secondary),
      bodySmall: AppTokens.bodySmall.copyWith(color: secondary),
      labelLarge: AppTokens.labelLarge.copyWith(color: primary),
      labelSmall: AppTokens.labelSmall.copyWith(color: secondary),
    );
  }
}

/// 自定义页面转场：缩放 + 淡入，营造高级感
class _ZoomFadeTransitionBuilder extends PageTransitionsBuilder {
  const _ZoomFadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppTokens.curveEmphasized,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

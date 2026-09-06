import 'package:flutter/material.dart';

/// Color palette scoped ONLY to the Admin Web (Owner) side, following
/// the 60-30-10 rule from the design brief:
/// - 60%: pure white — main background, content area
/// - 30%: soft pastel brown/beige — sidebar, secondary surfaces, borders
/// - 10%: warm medium brown — active nav, icons, key numbers, buttons
///
/// Deliberately separate from theme/app_theme.dart (AppColors), which
/// stays untouched for the Staff/Driver mobile apps. This keeps the
/// glassmorphism redesign contained to admin_web/ only.
class AdminWebColors {
  AdminWebColors._();

  // 60% — main background
  static const Color background = Color(0xFFFFFFFF);

  // 30% — sidebar / secondary surfaces / borders
  static const Color sidebarBackground = Color(0xFFF3E9DC);
  static const Color surfaceTint = Color(0xFFF7EFE4);
  static const Color border = Color(0xFFE8D9C5);

  // 10% — warm medium brown accent
  static const Color accent = Color(0xFF9A6F4F);
  static const Color accentDark = Color(0xFF7C5A3F);

  // Text
  static const Color textPrimary = Color(0xFF3B2E24);
  static const Color textSecondary = Color(0xFF8A7863);

  // Status (kept muted/earthy, no saturated colors per brief)
  static const Color success = Color(0xFF6E8F5C);
  static const Color warning = Color(0xFFC98A3B);
  static const Color error = Color(0xFFB3554A);

  // Chart bars — two closely related pastel brown shades
  static const Color chartBarPrimary = Color(0xFFB08968);
  static const Color chartBarSecondary = Color(0xFFDCC3A6);

  /// Semi-transparent white/beige for glass cards — pair with
  /// [glassBorder] and a BackdropFilter blur.
  static Color glassFill = Colors.white.withValues(alpha: 0.55);
  static Color glassBorder = border.withValues(alpha: 0.7);
}

/// Full Material [ThemeData] for Admin Web — wrapped around the whole
/// [AdminWebShell] subtree via a [Theme] widget, so every standard
/// Flutter widget (AppBar, Card, TextField, FloatingActionButton,
/// Switch, PopupMenu, Dialog, Chip) on every admin page automatically
/// picks up the brown/beige 60-30-10 palette — without each page
/// having to hardcode colors on every single widget. Pages that are
/// fully custom-built (like DashboardScreen) aren't affected either
/// way since they don't read from the ambient Theme.
class AdminWebTheme {
  const AdminWebTheme._();

  static ThemeData get themeData {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AdminWebColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AdminWebColors.accent,
        brightness: Brightness.light,
        primary: AdminWebColors.accent,
        error: AdminWebColors.error,
        surface: AdminWebColors.background,
      ),
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminWebColors.background,
        foregroundColor: AdminWebColors.textPrimary,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AdminWebColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AdminWebColors.accent),
      ),
      cardTheme: CardThemeData(
        color: AdminWebColors.background,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AdminWebColors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AdminWebColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminWebColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminWebColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminWebColors.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminWebColors.error),
        ),
        labelStyle: const TextStyle(color: AdminWebColors.textSecondary),
        hintStyle: const TextStyle(color: AdminWebColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminWebColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AdminWebColors.accent.withValues(alpha: 0.35),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminWebColors.textPrimary,
          side: BorderSide(color: AdminWebColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminWebColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AdminWebColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AdminWebColors.accent,
        unselectedLabelColor: AdminWebColors.textSecondary,
        indicatorColor: AdminWebColors.accent,
        dividerColor: AdminWebColors.border,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AdminWebColors.surfaceTint,
        selectedColor: AdminWebColors.accent,
        labelStyle: const TextStyle(color: AdminWebColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: AdminWebColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminWebColors.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AdminWebColors.accent
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AdminWebColors.accent.withValues(alpha: 0.4)
              : null,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AdminWebColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AdminWebColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

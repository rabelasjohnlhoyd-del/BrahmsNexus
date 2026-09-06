import 'package:flutter/material.dart';

/// Color palette + Material theme for the **Web Admin dashboard only**.
///
/// Deliberately separate from [AppColors] (theme/app_theme.dart), which
/// is the warm brown palette used by the Driver and Staff mobile apps
/// and the shared auth screens. Admin Web is a desktop-first dashboard
/// used exclusively by the Owner, so it gets its own professional
/// slate + indigo palette instead of inheriting the mobile brand
/// colors. Nothing in here is imported outside lib/pages/admin_web/**
/// and lib/widgets/admin_*.dart, so Driver/Staff/auth are unaffected.
class AdminColors {
  const AdminColors._();

  // --- Core brand: rich indigo/violet, the dominant color of the
  // reference dashboard (used for the active sidebar item, primary
  // buttons, and the darkest stat-card blocks). ---
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF4B3CC4); // deepest stat-card block, hover/pressed states
  static const Color primarySoft = Color(0xFFEEECFF); // pale lavender tint
  static const Color primaryMedium = Color(0xFF7A72E9); // mid-tone stat-card block, between primary and primaryDark

  // --- Surfaces (pale lavender-white, so the white content cards and
  // colored stat blocks stand out against it) ---
  static const Color background = Color(0xFFF5F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE7E8F3);

  // --- Text ---
  static const Color textPrimary = Color(0xFF1E1E2C);
  static const Color textSecondary = Color(0xFF6B6D80);

  // --- Semantic ---
  static const Color success = Color(0xFF34B1AA); // teal
  static const Color warning = Color(0xFFE0B50F); // gold
  static const Color error = Color(0xFFF9727C); // soft coral — also used as a stat-card block color
  static const Color info = Color(0xFF3B8FF3); // blue — used for "Delivered" status etc.

  /// Soft lavender tint used for avatar backgrounds, chip fills, and
  /// low-emphasis highlights — the admin-palette equivalent of
  /// AppColors.pastelBrown.
  static const Color tint = Color(0xFFE3E0FA);

  // --- Sidebar --- Light, not dark: a near-white panel with dark text
  // for unselected items, and a solid violet pill (sidebarActiveFill)
  // with WHITE text/icon for the selected item — matching the
  // reference's own light-sidebar-with-solid-active-pill convention.
  static const Color sidebarBackground = Color(0xFFFAFAFE);
  static const Color sidebarBackgroundElevated = Color(0xFFF2F1FA); // subtle hover tint
  static const Color sidebarBorder = Color(0xFFEDEDF5);
  static const Color sidebarText = Color(0xFF6E7191);
  static const Color sidebarTextActive = Colors.white;
  static const Color sidebarActiveFill = Color(0xFF6C63FF);
}

/// Full Material [ThemeData] for Admin Web — wrapped around the whole
/// [AdminWebShell] subtree via a [Theme] widget, so every Card,
/// TextField, Button, Tab, and Chip on every admin page automatically
/// picks up the admin palette without each page having to set its own
/// widget-level styling.
class AdminTheme {
  const AdminTheme._();

  static ThemeData get themeData {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AdminColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AdminColors.primary,
        brightness: Brightness.light,
        primary: AdminColors.primary,
        error: AdminColors.error,
        surface: AdminColors.surface,
      ),
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        labelStyle: const TextStyle(color: AdminColors.textSecondary),
        hintStyle: const TextStyle(color: AdminColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AdminColors.primary.withValues(alpha: 0.35),
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
          foregroundColor: AdminColors.textPrimary,
          side: const BorderSide(color: AdminColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AdminColors.primary,
        unselectedLabelColor: AdminColors.textSecondary,
        indicatorColor: AdminColors.primary,
        dividerColor: AdminColors.border,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.background,
        selectedColor: AdminColors.primary,
        labelStyle: const TextStyle(color: AdminColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: const BorderSide(color: AdminColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminColors.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AdminColors.primary
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AdminColors.primary.withValues(alpha: 0.4)
              : null,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AdminColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AdminColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

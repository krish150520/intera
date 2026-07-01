import 'package:flutter/material.dart';
import 'colors.dart';

/// Centralized ThemeData for INTERA — light and dark.
/// Use AppTheme.light / AppTheme.dark in your MaterialApp, then access
/// values anywhere via Theme.of(context) instead of hardcoding hex colors.
///
/// Usage in main.dart:
///   MaterialApp(
///     theme: AppTheme.light,
///     darkTheme: AppTheme.dark,
///     themeMode: ThemeMode.system, // or .light / .dark
///     ...
///   )
///
/// Usage in widgets — prefer this over AppColors.* where possible so the
/// widget automatically adapts to light/dark mode:
///   final cs = Theme.of(context).colorScheme;
///   Container(color: cs.surface)
///   Text('Hi', style: Theme.of(context).textTheme.titleMedium)
class AppTheme {
  AppTheme._();

  // ── Shared values ─────────────────────────────────────────────────────────
  static const String _fontFamily = 'Roboto'; // swap for your app's font

  static const BorderRadius _radiusSm = BorderRadius.all(Radius.circular(10));
  static const BorderRadius _radiusMd = BorderRadius.all(Radius.circular(14));
  static const BorderRadius _radiusLg = BorderRadius.all(Radius.circular(18));

  // ── LIGHT THEME ───────────────────────────────────────────────────────────
  static ThemeData get light {
    const cs = ColorScheme.light(
      brightness: Brightness.light,
      primary:          AppColors.primary,
      onPrimary:        Colors.white,
      primaryContainer: AppColors.lightField,
      secondary:        AppColors.accent,
      onSecondary:      Colors.white,
      surface:          AppColors.lightSurface,
      onSurface:        AppColors.lightTextSecondary,
      surfaceContainerHighest: AppColors.lightField,
      error:            AppColors.error,
      onError:          Colors.white,
      outline:          AppColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.lightBg,
      fontFamily: _fontFamily,
      dividerColor: AppColors.lightDivider,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextSecondary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.primary),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: AppColors.lightTextPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5),
        headlineMedium: TextStyle(
            color: AppColors.lightTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800),
        titleLarge: TextStyle(
            color: AppColors.lightTextSecondary,
            fontSize: 17,
            fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            color: AppColors.lightTextSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
        bodyMedium: TextStyle(
            color: Color(0xFF5A587A), fontSize: 13, height: 1.4),
        bodySmall: TextStyle(color: AppColors.lightTextMuted, fontSize: 12),
        labelSmall: TextStyle(
            color: AppColors.lightTextMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8),
      ),

      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _radiusLg,
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightField,
        hintStyle: const TextStyle(color: Color(0xFFB0ADDE), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: _radiusMd,
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radiusMd,
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: _radiusMd),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.lightChipBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: _radiusSm),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      iconTheme: const IconThemeData(color: AppColors.primary),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.lightTextMuted,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        indicatorColor: AppColors.primary,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.lightTextDim,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: _radiusSm),
        backgroundColor: AppColors.lightTextSecondary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20))),
        titleTextStyle: const TextStyle(
            color: AppColors.lightTextSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w700),
        contentTextStyle:
            const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightField,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500),
        secondaryLabelStyle:
            const TextStyle(color: Colors.white, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: const BorderSide(color: AppColors.lightChipBorder),
        ),
      ),
    );
  }

  // ── DARK THEME ────────────────────────────────────────────────────────────
  static ThemeData get dark {
    const cs = ColorScheme.dark(
      brightness: Brightness.dark,
      primary:          AppColors.primaryLight,
      onPrimary:        Color(0xFF1E1B3A),
      primaryContainer: AppColors.darkField,
      secondary:        AppColors.accent,
      onSecondary:      Colors.white,
      surface:          AppColors.darkSurface,
      onSurface:        AppColors.darkTextSecondary,
      surfaceContainerHighest: AppColors.darkField,
      error:            Color(0xFFEF5350),
      onError:          Colors.white,
      outline:          AppColors.darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.darkBg,
      fontFamily: _fontFamily,
      dividerColor: AppColors.darkDivider,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextSecondary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.primaryLight),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5),
        headlineMedium: TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800),
        titleLarge: TextStyle(
            color: AppColors.darkTextSecondary,
            fontSize: 17,
            fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            color: AppColors.darkTextSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
        bodyMedium: TextStyle(
            color: Color(0xFFC4C0E8), fontSize: 13, height: 1.4),
        bodySmall: TextStyle(color: AppColors.darkTextMuted, fontSize: 12),
        labelSmall: TextStyle(
            color: AppColors.darkTextMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8),
      ),

      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _radiusLg,
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkField,
        hintStyle: const TextStyle(color: Color(0xFF6E6896), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: _radiusMd,
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radiusMd,
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radiusMd,
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: const Color(0xFF1E1B3A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: _radiusMd),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.darkChipBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: _radiusSm),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
      ),

      iconTheme: const IconThemeData(color: AppColors.primaryLight),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primaryLight,
        unselectedLabelColor: AppColors.darkTextMuted,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        indicatorColor: AppColors.primaryLight,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.darkTextDim,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: _radiusSm),
        backgroundColor: AppColors.darkField,
        contentTextStyle:
            const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20))),
        titleTextStyle: const TextStyle(
            color: AppColors.darkTextSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w700),
        contentTextStyle:
            const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkField,
        selectedColor: AppColors.primaryLight,
        labelStyle: const TextStyle(
            color: AppColors.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w500),
        secondaryLabelStyle:
            const TextStyle(color: Color(0xFF1E1B3A), fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: const BorderSide(color: AppColors.darkChipBorder),
        ),
      ),
    );
  }
}

// ── Convenience extension ───────────────────────────────────────────────────
// Lets you write `context.colors.primary` etc instead of
// `Theme.of(context).colorScheme.primary` everywhere.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
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
      extensions: [
        AppColorsExtension(
          primary: AppColors.primary,
          primaryDark: AppColors.primaryDark,
          primaryLight: AppColors.primaryLight,
          accent: AppColors.accent,
          bg: AppColors.lightBg,
          surface: AppColors.lightSurface,
          field: AppColors.lightField,
          border: AppColors.lightBorder,
          chipBorder: AppColors.lightChipBorder,
          divider: AppColors.lightDivider,
          textPrimary: AppColors.lightTextPrimary,
          textSecondary: AppColors.lightTextSecondary,
          textMuted: AppColors.lightTextMuted,
          textDim: AppColors.lightTextDim,
          success: AppColors.success,
          successBg: AppColors.successBg,
          successBorder: AppColors.successBorder,
          error: AppColors.error,
          errorBg: AppColors.errorBg,
          warningKarma: AppColors.warningKarma,
          warningKarmaBg: AppColors.warningKarmaBg,
          warningKarmaBorder: AppColors.warningKarmaBorder,
          info: AppColors.info,
          primaryGradient: AppColors.primaryGradient,
          storyRingGradient: AppColors.storyRingGradient,
          karmaGoldGradient: AppColors.karmaGoldGradient,
        ),
      ],
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
      extensions: [
        AppColorsExtension(
          primary: AppColors.primaryLight,
          primaryDark: AppColors.primary,
          primaryLight: AppColors.primaryLight,
          accent: AppColors.accent,
          bg: AppColors.darkBg,
          surface: AppColors.darkSurface,
          field: AppColors.darkField,
          border: AppColors.darkBorder,
          chipBorder: AppColors.darkChipBorder,
          divider: AppColors.darkDivider,
          textPrimary: AppColors.darkTextPrimary,
          textSecondary: AppColors.darkTextSecondary,
          textMuted: AppColors.darkTextMuted,
          textDim: AppColors.darkTextDim,
          success: AppColors.success,
          successBg: AppColors.successBg.withValues(alpha: 0.1),
          successBorder: AppColors.successBorder.withValues(alpha: 0.2),
          error: AppColors.error,
          errorBg: AppColors.errorBg.withValues(alpha: 0.1),
          warningKarma: AppColors.warningKarma,
          warningKarmaBg: AppColors.warningKarmaBg.withValues(alpha: 0.1),
          warningKarmaBorder: AppColors.warningKarmaBorder.withValues(alpha: 0.2),
          info: AppColors.info,
          primaryGradient: AppColors.primaryGradient,
          storyRingGradient: AppColors.storyRingGradient,
          karmaGoldGradient: AppColors.karmaGoldGradient,
        ),
      ],
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
  AppColorsExtension get appColors => Theme.of(this).extension<AppColorsExtension>()!;
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  
  final Color bg;
  final Color surface;
  final Color field;
  final Color border;
  final Color chipBorder;
  final Color divider;
  
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDim;
  
  final Color success;
  final Color successBg;
  final Color successBorder;
  
  final Color error;
  final Color errorBg;
  
  final Color warningKarma;
  final Color warningKarmaBg;
  final Color warningKarmaBorder;
  
  final Color info;
  
  final LinearGradient primaryGradient;
  final LinearGradient storyRingGradient;
  final LinearGradient karmaGoldGradient;

  Color get textHi => textPrimary;
  Color get pill => field;
  Color get inactive => textDim;
  Color get primaryTint => field;
  Color get panelBg => field;
  Color get panelBorder => border;

  AppColorsExtension({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.field,
    required this.border,
    required this.chipBorder,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDim,
    required this.success,
    required this.successBg,
    required this.successBorder,
    required this.error,
    required this.errorBg,
    required this.warningKarma,
    required this.warningKarmaBg,
    required this.warningKarmaBorder,
    required this.info,
    required this.primaryGradient,
    required this.storyRingGradient,
    required this.karmaGoldGradient,
  });

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accent,
    Color? bg,
    Color? surface,
    Color? field,
    Color? border,
    Color? chipBorder,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDim,
    Color? success,
    Color? successBg,
    Color? successBorder,
    Color? error,
    Color? errorBg,
    Color? warningKarma,
    Color? warningKarmaBg,
    Color? warningKarmaBorder,
    Color? info,
    LinearGradient? primaryGradient,
    LinearGradient? storyRingGradient,
    LinearGradient? karmaGoldGradient,
  }) {
    return AppColorsExtension(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      field: field ?? this.field,
      border: border ?? this.border,
      chipBorder: chipBorder ?? this.chipBorder,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDim: textDim ?? this.textDim,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      successBorder: successBorder ?? this.successBorder,
      error: error ?? this.error,
      errorBg: errorBg ?? this.errorBg,
      warningKarma: warningKarma ?? this.warningKarma,
      warningKarmaBg: warningKarmaBg ?? this.warningKarmaBg,
      warningKarmaBorder: warningKarmaBorder ?? this.warningKarmaBorder,
      info: info ?? this.info,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      storyRingGradient: storyRingGradient ?? this.storyRingGradient,
      karmaGoldGradient: karmaGoldGradient ?? this.karmaGoldGradient,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      field: Color.lerp(field, other.field, t)!,
      border: Color.lerp(border, other.border, t)!,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      warningKarma: Color.lerp(warningKarma, other.warningKarma, t)!,
      warningKarmaBg: Color.lerp(warningKarmaBg, other.warningKarmaBg, t)!,
      warningKarmaBorder: Color.lerp(warningKarmaBorder, other.warningKarmaBorder, t)!,
      info: Color.lerp(info, other.info, t)!,
      primaryGradient: LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      storyRingGradient: LinearGradient.lerp(storyRingGradient, other.storyRingGradient, t)!,
      karmaGoldGradient: LinearGradient.lerp(karmaGoldGradient, other.karmaGoldGradient, t)!,
    );
  }
}
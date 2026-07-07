import 'package:flutter/material.dart';

/// Static color references — use these for one-off Color needs
/// (e.g. inside const widgets where Theme.of(context) isn't available).
/// For anything that should react to light/dark mode, prefer
/// Theme.of(context).colorScheme.* or AppTheme.of(context) helpers.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF6374E8); // Twilight Indigo
  static const Color primaryDark   = Color(0xFF4C5BB2); // Deep Twilight Indigo
  static const Color primaryLight  = Color(0xFF8E9DF6); // Soft Twilight Lilac
  static const Color accent        = Color(0xFF9EA7EC); // Twilight Accent Blue

  // ── Light theme surfaces ──────────────────────────────────────────────────
  static const Color lightBg       = Color(0xFFD8E2FF); // Twilight Haze Start
  static const Color lightSurface  = Color(0xFFF3F6FF); // Twilight Soft White
  static const Color lightField    = Color(0xFFE2E9FF); // Twilight Field Fill
  static const Color lightBorder   = Color(0xFFC5D1F6); // Twilight Border
  static const Color lightChipBorder = Color(0xFFB5C2EB);
  static const Color lightDivider  = Color(0xFFCDD7F5);

  // ── Light theme text ──────────────────────────────────────────────────────
  static const Color lightTextPrimary   = Color(0xFF1F2445); // Deep Indigo text
  static const Color lightTextSecondary = Color(0xFF454C75); // Dark blue-gray
  static const Color lightTextMuted     = Color(0xFF7079A3); // Muted twilight blue-gray
  static const Color lightTextDim       = Color(0xFF949EB8); // Placeholders

  // ── Dark theme surfaces ───────────────────────────────────────────────────
  static const Color darkBg        = Color(0xFF171A30); // Deep Twilight Space
  static const Color darkSurface   = Color(0xFF202340); // Twilight Space Surface
  static const Color darkField     = Color(0xFF26294C); // Twilight Space Field
  static const Color darkBorder    = Color(0xFF343968); // Twilight Border Line
  static const Color darkChipBorder= Color(0xFF3D437A);
  static const Color darkDivider   = Color(0xFF282B4E);

  // ── Dark theme text ───────────────────────────────────────────────────────
  static const Color darkTextPrimary   = Color(0xFFFFFFFF); // Crisp White
  static const Color darkTextSecondary = Color(0xFFD8E2FF); // Soft Twilight Haze Blue
  static const Color darkTextMuted     = Color(0xFFA7B7E7); // Muted Lavender Blue
  static const Color darkTextDim       = Color(0xFF707B9E); // Dimmed slate

  // ── Semantic (same in both themes — kept vivid for visibility) ────────────
  static const Color success      = Color(0xFF388E3C);
  static const Color successBg    = Color(0xFFE8F5E9);
  static const Color successBorder= Color(0xFFA5D6A7);

  static const Color error        = Color(0xFFE53935);
  static const Color errorBg      = Color(0xFFFFEBEE);

  static const Color warningKarma       = Color(0xFFC9830A); // ⚡ karma gold
  static const Color warningKarmaBg     = Color(0xFFFFF8EC);
  static const Color warningKarmaBorder = Color(0xFFF5DCAA);

  static const Color info         = Color(0xFF0288D1);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient storyRingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  static const LinearGradient karmaGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF3CD), Color(0xFFFFE082)],
  );
}
import 'package:flutter/material.dart';

/// Static color references — use these for one-off Color needs
/// (e.g. inside const widgets where Theme.of(context) isn't available).
/// For anything that should react to light/dark mode, prefer
/// Theme.of(context).colorScheme.* or AppTheme.of(context) helpers.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF7E69FF); // Bright violet-purple
  static const Color primaryDark   = Color(0xFF6552E6); // pressed/hover state
  static const Color primaryLight  = Color(0xFF9E8FFF); // gradients, highlights
  static const Color accent        = Color(0xFFB06EE8); // secondary gradient stop

  // ── Light theme surfaces ──────────────────────────────────────────────────
  static const Color lightBg       = Color(0xFFEEF0FB);
  static const Color lightSurface  = Color(0xFFFFFFFF);
  static const Color lightField    = Color(0xFFF5F4FF);
  static const Color lightBorder   = Color(0xFFE4E2F8);
  static const Color lightChipBorder = Color(0xFFD8D5F8);
  static const Color lightDivider  = Color(0xFFEAE8FB);

  // ── Light theme text ──────────────────────────────────────────────────────
  static const Color lightTextPrimary   = Color(0xFF2D1B69); // headings / hi-emphasis
  static const Color lightTextSecondary = Color(0xFF5A587A); // body text
  static const Color lightTextMuted     = Color(0xFF8884BB); // labels / captions
  static const Color lightTextDim       = Color(0xFF9E9BD0); // placeholders / icons

  // ── Dark theme surfaces ───────────────────────────────────────────────────
  static const Color darkBg        = Color(0xFF131124); // Rich deep navy-purple
  static const Color darkSurface   = Color(0xFF1D1A32); // Premium dark purple-grey surface
  static const Color darkField     = Color(0xFF24203F);
  static const Color darkBorder    = Color(0xFF282542); // Subtle dark outline
  static const Color darkChipBorder= Color(0xFF322E54);
  static const Color darkDivider   = Color(0xFF201D38);

  // ── Dark theme text ───────────────────────────────────────────────────────
  static const Color darkTextPrimary   = Color(0xFFFFFFFF); // Crisp white
  static const Color darkTextSecondary = Color(0xFFC5C2E6); // Soft purple-gray
  static const Color darkTextMuted     = Color(0xFF8B86B7); // Muted purple-gray
  static const Color darkTextDim       = Color(0xFF655F94);

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
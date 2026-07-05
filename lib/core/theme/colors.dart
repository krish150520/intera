import 'package:flutter/material.dart';

/// Minimal monochrome + single violet accent palette.
/// Inspired by BeReal / Locket — raw, clean, no decoration noise.
class AppColors {
  AppColors._();

  // ── Accent (the ONE vivid color) ─────────────────────────────────────────
  static const Color primary      = Color(0xFF7C3AED); // vivid violet
  static const Color primaryDark  = Color(0xFF6D28D9); // pressed
  static const Color primaryLight = Color(0xFF8B5CF6); // hover / gradient end
  static const Color accent       = Color(0xFF7C3AED); // same as primary (mono)

  // ── Light theme surfaces ──────────────────────────────────────────────────
  static const Color lightBg       = Color(0xFFF9F9F9);
  static const Color lightSurface  = Color(0xFFFFFFFF);
  static const Color lightField    = Color(0xFFF3F3F3);
  static const Color lightBorder   = Color(0xFFE5E5E5);
  static const Color lightChipBorder = Color(0xFFD4D4D4);
  static const Color lightDivider  = Color(0xFFEEEEEE);

  // ── Light theme text ──────────────────────────────────────────────────────
  static const Color lightTextPrimary   = Color(0xFF0A0A0A);
  static const Color lightTextSecondary = Color(0xFF404040);
  static const Color lightTextMuted     = Color(0xFF737373);
  static const Color lightTextDim       = Color(0xFF9E9E9E);

  // ── Dark theme surfaces (near-black monochrome) ───────────────────────────
  static const Color darkBg        = Color(0xFF0A0A0A); // pure near-black
  static const Color darkSurface   = Color(0xFF141414); // card bg
  static const Color darkField     = Color(0xFF1E1E1E); // input / elevated
  static const Color darkBorder    = Color(0xFF262626); // subtle divider
  static const Color darkChipBorder= Color(0xFF303030);
  static const Color darkDivider   = Color(0xFF1C1C1C);

  // ── Dark theme text ───────────────────────────────────────────────────────
  static const Color darkTextPrimary   = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFD4D4D4);
  static const Color darkTextMuted     = Color(0xFF888888);
  static const Color darkTextDim       = Color(0xFF555555);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success       = Color(0xFF22C55E);
  static const Color successBg     = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);

  static const Color error         = Color(0xFFEF4444);
  static const Color errorBg       = Color(0xFFFEF2F2);

  static const Color warningKarma       = Color(0xFFF59E0B);
  static const Color warningKarmaBg     = Color(0xFFFFFBEB);
  static const Color warningKarmaBorder = Color(0xFFFDE68A);

  static const Color info          = Color(0xFF3B82F6);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient storyRingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFFA855F7)],
  );

  static const LinearGradient karmaGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
  );
}
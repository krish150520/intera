import 'package:flutter/material.dart';
import 'colors.dart';

/// Centralized text styles for INTERA.
///
/// NOTE on color application: these base styles are intentionally
/// color-less (or use semantic colors like success/error that don't change
/// between themes) so the same TextStyle works in both light and dark mode
/// when combined with .copyWith(color: ...) using the current theme's text
/// color. See the `light` / `dark` helpers at the bottom for ready-made
/// colored variants, or just do:
///   Text('Hi', style: AppTextStyles.heading1.copyWith(
///     color: Theme.of(context).colorScheme.onSurface,
///   ))
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Roboto';

  // ── Base styles (no color — apply via .copyWith or theme) ─────────────────

  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  // ── Pre-colored styles — LIGHT theme ───────────────────────────────────────

  static const TextStyle captionLight = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.lightTextMuted,
  );

  static const TextStyle heading1Light =
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: AppColors.lightTextPrimary);
  static const TextStyle heading2Light =
      TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.lightTextPrimary);
  static const TextStyle heading3Light =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightTextSecondary);
  static const TextStyle bodyLargeLight =
      TextStyle(fontSize: 16, color: AppColors.lightTextSecondary);
  static const TextStyle bodyMediumLight =
      TextStyle(fontSize: 14, color: AppColors.lightTextSecondary);
  static const TextStyle bodySmallLight =
      TextStyle(fontSize: 12, color: AppColors.lightTextMuted);

  // ── Pre-colored styles — DARK theme ────────────────────────────────────────

  static const TextStyle captionDark = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.darkTextMuted,
  );

  static const TextStyle heading1Dark =
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: AppColors.darkTextPrimary);
  static const TextStyle heading2Dark =
      TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary);
  static const TextStyle heading3Dark =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkTextSecondary);
  static const TextStyle bodyLargeDark =
      TextStyle(fontSize: 16, color: AppColors.darkTextSecondary);
  static const TextStyle bodyMediumDark =
      TextStyle(fontSize: 14, color: AppColors.darkTextSecondary);
  static const TextStyle bodySmallDark =
      TextStyle(fontSize: 12, color: AppColors.darkTextMuted);

  // ── Legacy alias — kept so existing call-sites using `caption` don't break.
  // Defaults to light theme; prefer captionLight/captionDark or the
  // BuildContext extension below in new code. ─────────────────────────────────
  static const TextStyle caption = captionLight;

  // ── Semantic (color is the same regardless of theme) ───────────────────────

  static const TextStyle karmaPositive = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppColors.success,
  );

  static const TextStyle karmaNegative = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppColors.error,
  );

  static const TextStyle karmaGold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppColors.warningKarma,
  );
}

/// Convenience extension — auto-picks the light or dark variant based on
/// the current theme brightness, so call-sites don't need if/else.
///
/// Usage:
///   Text('Hello', style: context.textStyles.heading1)
///   Text('caption', style: context.textStyles.caption)
extension AppTextStylesContext on BuildContext {
  _ThemedTextStyles get appTextStyles => _ThemedTextStyles(this);
}

class _ThemedTextStyles {
  final BuildContext context;
  const _ThemedTextStyles(this.context);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  TextStyle get heading1 => _isDark ? AppTextStyles.heading1Dark : AppTextStyles.heading1Light;
  TextStyle get heading2 => _isDark ? AppTextStyles.heading2Dark : AppTextStyles.heading2Light;
  TextStyle get heading3 => _isDark ? AppTextStyles.heading3Dark : AppTextStyles.heading3Light;
  TextStyle get bodyLarge => _isDark ? AppTextStyles.bodyLargeDark : AppTextStyles.bodyLargeLight;
  TextStyle get bodyMedium => _isDark ? AppTextStyles.bodyMediumDark : AppTextStyles.bodyMediumLight;
  TextStyle get bodySmall => _isDark ? AppTextStyles.bodySmallDark : AppTextStyles.bodySmallLight;
  TextStyle get caption => _isDark ? AppTextStyles.captionDark : AppTextStyles.captionLight;
  TextStyle get button => AppTextStyles.button;
  TextStyle get karmaPositive => AppTextStyles.karmaPositive;
  TextStyle get karmaNegative => AppTextStyles.karmaNegative;
  TextStyle get karmaGold => AppTextStyles.karmaGold;
}
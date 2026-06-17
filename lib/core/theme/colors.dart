import 'package:flutter/material.dart';

/// Centralized color palette for INTERA.
/// Primary accent is a teal-green, consistent across light & dark themes.
class AppColors {
  AppColors._();

  // Brand
  // Brand
static const Color primary = Color(0xFF212121);
static const Color primaryDark = Color(0xFF000000);
static const Color primaryLight = Color(0xFF616161);

  // Karma colors
  static const Color karmaPositive = Color(0xFF12B886);
  static const Color karmaNegative = Color(0xFFFF6B6B);

  // Light theme
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF212529);
  static const Color lightTextSecondary = Color(0xFF6C757D);
  static const Color lightBorder = Color(0xFFE9ECEF);

  // Dark theme
  static const Color darkBackground = Color(0xFF121417);
  static const Color darkSurface = Color(0xFF1E2125);
  static const Color darkTextPrimary = Color(0xFFF1F3F5);
  static const Color darkTextSecondary = Color(0xFFADB5BD);
  static const Color darkBorder = Color(0xFF2C2F33);

  // Status
  static const Color error = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFC078);
  static const Color success = Color(0xFF40C057);
}

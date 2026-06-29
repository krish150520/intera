import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  //==========================
  // Brand Colors
  //==========================

  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5248D8);
  static const Color primaryLight = Color(0xFFEDE9FF);

  static const Color secondary = Color(0xFFFFB84D);

  // Status
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF5C5C);
  static const Color info = Color(0xFF42A5F5);

  // Karma
  static const Color karma = Color(0xFFF59F00);

  // Like
  static const Color like = Color(0xFFFF4D6D);

  //==========================
  // Light Theme
  //==========================

  static const Color lightBackground = Color(0xFFF4F5FB);

  static const Color lightSurface = Colors.white;

  static const Color lightCard = Color(0xFFFFFFFF);

  static const Color lightPanel = Color(0xFFF8F7FF);

  static const Color lightBorder = Color(0xFFE4E4F2);

  static const Color lightDivider = Color(0xFFEAEAF4);

  static const Color lightTextPrimary = Color(0xFF1E1E2C);

  static const Color lightTextSecondary = Color(0xFF75758B);

  static const Color lightHint = Color(0xFFA0A0B2);

  //==========================
  // Dark Theme
  //==========================

  static const Color darkBackground = Color(0xFF11111B);

  static const Color darkSurface = Color(0xFF1A1A27);

  static const Color darkCard = Color(0xFF202031);

  static const Color darkPanel = Color(0xFF25253A);

  static const Color darkBorder = Color(0xFF32324B);

  static const Color darkDivider = Color(0xFF2B2B42);

  static const Color darkTextPrimary = Color(0xFFF8F8FF);

  static const Color darkTextSecondary = Color(0xFFB0B0C3);

  static const Color darkHint = Color(0xFF7C7C93);

  //==========================
  // Story Colors
  //==========================

  static const Color storyRing = primary;

  static const Color storyViewed = Color(0xFFC5C5D6);

  //==========================
  // Chat
  //==========================

  static const Color sentBubble = primary;

  static const Color receivedBubble = Color(0xFFF1F2F8);

  static const Color darkReceivedBubble = Color(0xFF2A2A3D);

  //==========================
  // Misc
  //==========================

  static const Color white = Colors.white;

  static const Color black = Colors.black;

  static const Color transparent = Colors.transparent;
}
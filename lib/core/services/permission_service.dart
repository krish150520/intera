import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  PermissionService._();

  static const String _keyNotificationPrompt = 'has_prompted_notifications';
  static const String _keyCameraPrompt = 'has_prompted_camera';
  static const String _keyGalleryPrompt = 'has_prompted_gallery';

  /// Requests camera permission, showing the custom dialog first if not yet granted.
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      return await _showPermanentlyDeniedDialog(
        context,
        permissionName: 'Camera',
        message: 'Intera needs camera access to capture photos and videos for your sparks.',
      );
    }

    // Show custom explanation dialog
    final shouldProceed = await _showExplanationDialog(
      context,
      title: 'Camera Access Needed',
      message: 'Intera uses your camera to let you take photos and record videos directly for your sparks and posts.',
      icon: Icons.camera_alt_rounded,
      iconGradient: const [Color(0xFF9B59F5), Color(0xFF6C27C8)],
      prefKey: _keyCameraPrompt,
    );

    if (!shouldProceed) return false;

    // Request native permission
    final result = await Permission.camera.request();

    if (result.isGranted) {
      return true;
    } else if (result.isDenied) {
      _showSnackbar(context, 'Camera permission denied.');
    }
    return false;
  }

  /// Requests gallery (photos) permission, showing the custom dialog first if not yet granted.
  static Future<bool> requestGalleryPermission(BuildContext context) async {
    final status = await Permission.photos.status;

    // Handles limited gallery access on iOS / Android 14+ as granted
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      return await _showPermanentlyDeniedDialog(
        context,
        permissionName: 'Gallery',
        message: 'Intera needs photos access to select media files for your sparks and posts.',
      );
    }

    // Show custom explanation dialog
    final shouldProceed = await _showExplanationDialog(
      context,
      title: 'Gallery Access Needed',
      message: 'Intera needs access to your gallery so you can choose and upload photos or videos from your library.',
      icon: Icons.photo_library_rounded,
      iconGradient: const [Color(0xFFE100FF), Color(0xFF7F00FF)],
      prefKey: _keyGalleryPrompt,
    );

    if (!shouldProceed) return false;

    // Request native permission
    final result = await Permission.photos.request();

    if (result.isGranted || result.isLimited) {
      return true;
    } else if (result.isDenied) {
      _showSnackbar(context, 'Gallery permission denied.');
    }
    return false;
  }

  /// Requests notification permission, showing the custom dialog first if not yet granted.
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    final status = await Permission.notification.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      // For notifications, we don't block heavily but we can offer a settings prompt
      return await _showPermanentlyDeniedDialog(
        context,
        permissionName: 'Notifications',
        message: 'Intera needs notification access to send you real-time chat messages, likes, and replies.',
      );
    }

    // Show custom explanation dialog
    final shouldProceed = await _showExplanationDialog(
      context,
      title: 'Enable Notifications',
      message: 'Allow notification permissions to get real-time alerts for replies, likes, messages, and active sparks.',
      icon: Icons.notifications_active_rounded,
      iconGradient: const [Color(0xFFFF9A56), Color(0xFFFF355E)],
      prefKey: _keyNotificationPrompt,
    );

    if (!shouldProceed) return false;

    // Request native permission
    final result = await Permission.notification.request();

    if (result.isGranted) {
      return true;
    } else if (result.isDenied) {
      _showSnackbar(context, 'Notification permission denied.');
    }
    return false;
  }

  // ── HELPER SYSTEM DIALOGS ──────────────────────────────────────────────────

  static Future<bool> _showExplanationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required List<Color> iconGradient,
    required String prefKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool(prefKey) ?? false;

    // If already prompted once, don't show custom explanation dialog again, proceed directly
    if (hasPrompted) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InteraPermissionDialog(
        title: title,
        message: message,
        icon: icon,
        iconGradient: iconGradient,
        onContinue: () async {
          await prefs.setBool(prefKey, true);
          Navigator.pop(ctx, true);
        },
        onCancel: () {
          Navigator.pop(ctx, false);
        },
      ),
    );

    return result ?? false;
  }

  static Future<bool> _showPermanentlyDeniedDialog(
    BuildContext context, {
    required String permissionName,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _InteraPermanentlyDeniedDialog(
        permissionName: permissionName,
        message: message,
      ),
    );
    return result ?? false;
  }

  static void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ── CUSTOM DIALOG WIDGETS ────────────────────────────────────────────────────

class _InteraPermissionDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final List<Color> iconGradient;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const _InteraPermissionDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconGradient,
    required this.onContinue,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1828).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Beautiful icon with gradient background
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: iconGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradient.first.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onCancel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Not Now',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onContinue();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9B59F5), Color(0xFF6C27C8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9B59F5).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InteraPermanentlyDeniedDialog extends StatelessWidget {
  final String permissionName;
  final String message;

  const _InteraPermanentlyDeniedDialog({
    required this.permissionName,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1828).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$permissionName Permission Needed',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, true);
                          await openAppSettings();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Open Settings',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

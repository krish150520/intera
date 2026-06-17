import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// A circular user avatar with image fallback to initials.
///
/// Usage:
/// ```dart
/// CustomAvatar(name: 'Krish Sharma', imageUrl: user.avatarUrl, radius: 24)
/// ```
class CustomAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const CustomAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: AppColors.primaryLight,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

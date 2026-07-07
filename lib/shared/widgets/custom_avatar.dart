import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A circular user avatar with image fallback to initials.
///
/// Usage:
/// ```dart
/// CustomAvatar(name: 'Krish Sharma', imageUrl: user.avatarUrl, radius: 24)
/// ```
class CustomAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? userId;
  final double radius;

  const CustomAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.userId,
    this.radius = 22,
  });

  String _getInitials(String nameText) {
    final parts = nameText.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _buildAvatar(BuildContext context, String displayName, String? url) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.primary.withValues(alpha: 0.15),
      child: Text(
        _getInitials(displayName),
        style: TextStyle(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );

    if (url != null && url.isNotEmpty) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return fallback;
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: radius,
                  height: radius,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null && userId!.isNotEmpty) {
      if (userId == currentUid) {
        final user = FirebaseAuth.instance.currentUser;
        return _buildAvatar(
          context,
          user?.displayName ?? name,
          user?.photoURL ?? imageUrl,
        );
      }
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final liveUrl = data['avatarUrl'] as String?;
            final liveName = data['name'] as String? ?? name;
            return _buildAvatar(context, liveName, liveUrl);
          }
          return _buildAvatar(context, name, imageUrl);
        },
      );
    }

    return _buildAvatar(context, name, imageUrl);
  }
}

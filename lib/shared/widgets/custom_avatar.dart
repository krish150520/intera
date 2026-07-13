import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../features/profile/screens/my_profile_screen.dart';
import '../../features/profile/screens/user_profile_screen.dart';

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
  final String? heroTag;
  final bool clickable;

  const CustomAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.userId,
    this.radius = 22,
    this.heroTag,
    this.clickable = true,
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

    Widget avatarWidget;
    if (userId != null && userId!.isNotEmpty) {
      if (userId == currentUid) {
        final user = FirebaseAuth.instance.currentUser;
        avatarWidget = _buildAvatar(
          context,
          user?.displayName ?? name,
          user?.photoURL ?? imageUrl,
        );
      } else {
        avatarWidget = FutureBuilder<DocumentSnapshot>(
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
    } else {
      avatarWidget = _buildAvatar(context, name, imageUrl);
    }

    final String passedTag = heroTag ?? 'avatar_${userId ?? 'default'}_${identityHashCode(avatarWidget)}';

    if (!clickable || userId == null || userId!.isEmpty || userId == 'anonymous') {
      return heroTag != null
          ? Hero(tag: heroTag!, child: avatarWidget)
          : avatarWidget;
    }

    return GestureDetector(
      onTap: () {
        if (userId != null && userId!.isNotEmpty) {
          if (userId == currentUid) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MyProfileScreen(heroTag: passedTag),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  userId: userId!,
                  userName: name,
                  userAvatar: imageUrl ?? '',
                  heroTag: passedTag,
                ),
              ),
            );
          }
        }
      },
      child: heroTag != null
          ? Hero(tag: heroTag!, child: avatarWidget)
          : avatarWidget,
    );
  }
}

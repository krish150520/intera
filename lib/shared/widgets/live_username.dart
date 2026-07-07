import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A widget that dynamically fetches and displays the latest username of a user.
///
/// If the Firestore fetch is pending or fails, it falls back to the provided fallback username.
class LiveUsername extends StatelessWidget {
  final String? userId;
  final String fallback;
  final TextStyle? style;
  final String suffix;
  final TextStyle? suffixStyle;

  const LiveUsername({
    super.key,
    required this.userId,
    required this.fallback,
    this.style,
    this.suffix = '',
    this.suffixStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (userId != null && userId!.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          String display = fallback;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final username = data['username'] as String?;
            if (username != null && username.isNotEmpty) {
              display = username;
            }
          }
          
          // Ensure it starts with '@' for username presentation if needed
          if (!display.startsWith('@')) {
            display = '@$display';
          }

          return Text.rich(
            TextSpan(
              text: display,
              style: style,
              children: [
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: suffixStyle ?? style,
                  ),
              ],
            ),
          );
        },
      );
    }

    String display = fallback;
    if (!display.startsWith('@')) {
      display = '@$display';
    }

    return Text.rich(
      TextSpan(
        text: display,
        style: style,
        children: [
          if (suffix.isNotEmpty)
            TextSpan(
              text: suffix,
              style: suffixStyle ?? style,
            ),
        ],
      ),
    );
  }
}

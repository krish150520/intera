import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'karma_service.dart';

// ── Sizes ──────────────────────────────────────────────────────────────────
enum KarmaBadgeSize { small, medium, large }

/// Reusable karma badge — streams live balance for [uid].
/// Drop onto any profile, leaderboard row, or app-bar action.
class KarmaBadge extends StatelessWidget {
  final String uid;
  final KarmaBadgeSize size;
  final bool showLabel;   // show "Karma" text below number
  final bool showIcon;

  const KarmaBadge({
    super.key,
    required this.uid,
    this.size = KarmaBadgeSize.medium,
    this.showLabel = false,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: KarmaService.balanceStream(uid),
      builder: (context, snap) {
        final karma = snap.data ?? 0;
        return _BadgeChip(
          karma: karma,
          size: size,
          showLabel: showLabel,
          showIcon: showIcon,
        );
      },
    );
  }
}

/// Convenience variant that auto-uses the currently logged-in user.
class MyKarmaBadge extends StatelessWidget {
  final KarmaBadgeSize size;
  final bool showLabel;

  const MyKarmaBadge({
    super.key,
    this.size = KarmaBadgeSize.medium,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();
    return KarmaBadge(uid: uid, size: size, showLabel: showLabel);
  }
}

// ── Internal chip ──────────────────────────────────────────────────────────

class _BadgeChip extends StatelessWidget {
  final int karma;
  final KarmaBadgeSize size;
  final bool showLabel;
  final bool showIcon;

  const _BadgeChip({
    required this.karma,
    required this.size,
    required this.showLabel,
    required this.showIcon,
  });

  double get _fontSize => switch (size) {
    KarmaBadgeSize.small  => 11,
    KarmaBadgeSize.medium => 13,
    KarmaBadgeSize.large  => 18,
  };

  double get _iconSize => switch (size) {
    KarmaBadgeSize.small  => 12,
    KarmaBadgeSize.medium => 15,
    KarmaBadgeSize.large  => 22,
  };

  EdgeInsets get _padding => switch (size) {
    KarmaBadgeSize.small  => const EdgeInsets.symmetric(horizontal: 7,  vertical: 3),
    KarmaBadgeSize.medium => const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    KarmaBadgeSize.large  => const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  };

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3CD), Color(0xFFFFE082)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCA28), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFCA28).withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(Icons.bolt_rounded, color: const Color(0xFFC9830A), size: _iconSize),
                const SizedBox(width: 3),
              ],
              Text(
                _compact(karma),
                style: TextStyle(
                  color: const Color(0xFF7A5010),
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (showLabel) ...[
            const SizedBox(height: 1),
            Text(
              'karma',
              style: TextStyle(
                color: const Color(0xFFA06820),
                fontSize: _fontSize - 3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

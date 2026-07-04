import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'karma_service.dart';
import 'karma_badge.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';

class KarmaLedgerScreen extends StatelessWidget {
  const KarmaLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: context.colors.primary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Karma',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _ThemeResolver.textHi(context),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: KarmaBadge(
                uid: uid,
                size: KarmaBadgeSize.medium,
                showLabel: false,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: context.colors.surface,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              children: [
                StreamBuilder<int>(
                  stream: KarmaService.balanceStream(uid),
                  builder: (context, snap) {
                    final karma = snap.data ?? 0;
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              color: AppColors.warningKarma,
                              size: 32,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$karma',
                              style: const TextStyle(
                                color: AppColors.warningKarma,
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          karma == 1 ? '1 karma point' : '$karma karma points',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _ThemeResolver.textDim(context),
                                fontSize: 13,
                              ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Earn karma by answering help requests · Tip great answers',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _ThemeResolver.textDim(context),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'HISTORY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _ThemeResolver.textDim(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: KarmaService.transactionStream(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primary,
                      strokeWidth: 2,
                    ),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_outlined,
                          color: _ThemeResolver.textDim(context),
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No karma activity yet',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _ThemeResolver.textDim(context),
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Answer help requests to start earning!',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _ThemeResolver.textDim(context),
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _TxTile(data: data, myUid: uid);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String myUid;

  const _TxTile({required this.data, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final note = data['note'] as String? ?? type;
    final ts = data['createdAt'];
    final toUid = data['toUid'] as String?;

    final isCredit = toUid == myUid;
    final sign = isCredit ? '+' : '-';
    final amtColor = isCredit ? AppColors.success : AppColors.error;

    final (icon, iconBg) = _iconFor(context, type);

    String timeStr = '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours}h ago';
      } else {
        timeStr = '${diff.inDays}d ago';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _ThemeResolver.textHi(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _ThemeResolver.textDim(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$sign $amount ⚡',
            style: TextStyle(
              color: amtColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _iconFor(BuildContext context, String type) {
    return switch (type) {
      'earnedBestAnswer' => (Icons.emoji_events_rounded, AppColors.success),
      'tipGiven' => (Icons.volunteer_activism, context.colors.primary),
      'tipReceived' => (Icons.volunteer_activism, AppColors.success),
      'deductedHelpPost' => (Icons.handshake_outlined, AppColors.warningKarma),
      'refundedHelpPost' => (Icons.undo_rounded, AppColors.info),
      _ => (Icons.bolt_rounded, context.colors.primary),
    };
  }
}

class _ThemeResolver {
  const _ThemeResolver._();

  static Color textHi(BuildContext context) => context.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;

  static Color textDim(BuildContext context) =>
      context.isDarkMode ? AppColors.darkTextDim : AppColors.lightTextDim;
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'karma_service.dart';
import 'karma_badge.dart';

class KarmaLedgerScreen extends StatelessWidget {
  const KarmaLedgerScreen({super.key});

  static const Color _primary  = Color(0xFF6C63D5);
  static const Color _bg       = Color(0xFFEEF0FB);
  static const Color _textDark = Color(0xFF2D2A6E);
  static const Color _muted    = Color(0xFF9E9BD0);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Karma',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: KarmaBadge(uid: uid, size: KarmaBadgeSize.medium, showLabel: false),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Balance hero ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.white,
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
                            const Icon(Icons.bolt_rounded,
                                color: Color(0xFFC9830A), size: 32),
                            const SizedBox(width: 4),
                            Text(
                              '$karma',
                              style: const TextStyle(
                                color: Color(0xFF7A5010),
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
                          style: const TextStyle(
                              color: _muted, fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Info pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F4FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Earn karma by answering help requests · Tip great answers',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Transaction list ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'HISTORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _muted,
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
                  return const Center(
                      child: CircularProgressIndicator(
                          color: _primary, strokeWidth: 2));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_outlined, color: _muted, size: 40),
                        const SizedBox(height: 10),
                        const Text(
                          'No karma activity yet',
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Answer help requests to start earning!',
                          style: TextStyle(color: _muted, fontSize: 12),
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

// ── Transaction tile ─────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String myUid;

  const _TxTile({required this.data, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final type   = data['type'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final note   = data['note'] as String? ?? type;
    final ts     = data['createdAt'];
    final toUid  = data['toUid'] as String?;

    final isCredit = toUid == myUid;
    final sign     = isCredit ? '+' : '−';
    final amtColor = isCredit
        ? const Color(0xFF388E3C)
        : const Color(0xFFD32F2F);

    final (icon, iconBg) = _iconFor(type, isCredit);

    String timeStr = '';
    if (ts is Timestamp) {
      final dt   = ts.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60)      timeStr = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24)   timeStr = '${diff.inHours}h ago';
      else                          timeStr = '${diff.inDays}d ago';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note,
                  style: const TextStyle(
                    color: Color(0xFF2D2A6E),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(timeStr,
                      style: const TextStyle(
                          color: Color(0xFF9E9BD0), fontSize: 11)),
                ],
              ],
            ),
          ),
          // Amount
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

  (IconData, Color) _iconFor(String type, bool isCredit) {
    return switch (type) {
      'earnedBestAnswer' => (Icons.emoji_events_rounded,  const Color(0xFF388E3C)),
      'tipGiven'         => (Icons.volunteer_activism,    const Color(0xFF6C63D5)),
      'tipReceived'      => (Icons.volunteer_activism,    const Color(0xFF388E3C)),
      'deductedHelpPost' => (Icons.handshake_outlined,   const Color(0xFFC9830A)),
      'refundedHelpPost' => (Icons.undo_rounded,         const Color(0xFF0288D1)),
      _                  => (Icons.bolt_rounded,          const Color(0xFF6C63D5)),
    };
  }
}
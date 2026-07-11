import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../screens/post_detail_screen.dart';

class PollCardWidget extends StatefulWidget {
  final Post post;

  const PollCardWidget({
    super.key,
    required this.post,
  });

  @override
  State<PollCardWidget> createState() => _PollCardWidgetState();
}

class _PollCardWidgetState extends State<PollCardWidget> {
  bool _isVoting = false;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _vote(String option) async {
    if (_isVoting || _currentUid.isEmpty) return;

    final votedBy = widget.post.pollVotedBy ?? [];
    if (votedBy.contains(_currentUid)) return; // Already voted

    // Expiry check
    if (widget.post.pollExpiresAt != null &&
        DateTime.now().isAfter(widget.post.pollExpiresAt!)) {
      return; // Expired
    }

    setState(() => _isVoting = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return;

        final data = snap.data() ?? {};
        final Map<String, int> votes = Map<String, int>.from(
          (data['pollVotes'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        );
        final List<String> voters = List<String>.from(data['pollVotedBy'] ?? []);

        if (voters.contains(_currentUid)) return;

        votes[option] = (votes[option] ?? 0) + 1;
        voters.add(_currentUid);
        final total = (data['totalVotes'] as num? ?? 0).toInt() + 1;

        transaction.update(docRef, {
          'pollVotes': votes,
          'pollVotedBy': voters,
          'totalVotes': total,
        });
      });
    } catch (e) {
      debugPrint('Error voting: $e');
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  String _getTimeRemaining() {
    if (widget.post.pollExpiresAt == null) return 'Ongoing poll';
    final diff = widget.post.pollExpiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Closed poll';

    if (diff.inDays > 0) {
      return '${diff.inDays}d remaining';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h remaining';
    } else {
      return '${diff.inMinutes}m remaining';
    }
  }

  Future<void> _showDeleteConfirmDialog() async {
    final c = context.appColors;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Poll?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to permanently delete this poll?', style: TextStyle(color: c.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.post.id)
                    .delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Poll successfully deleted.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: c.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: c.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final options = widget.post.pollOptions ?? [];
    final votes = widget.post.pollVotes ?? {};
    final votedBy = widget.post.pollVotedBy ?? [];
    final totalVotes = widget.post.totalVotes ?? 0;
    final expiresAt = widget.post.pollExpiresAt;

    final hasVoted = votedBy.contains(_currentUid);
    final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);
    final showResults = hasVoted || isExpired;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: widget.post),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.border.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CustomAvatar(
                  name: widget.post.authorName,
                  imageUrl: widget.post.authorAvatarUrl,
                  radius: 18,
                  userId: widget.post.authorId,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.post.authorUsername,
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '📊 Poll',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.post.authorId == _currentUid) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showDeleteConfirmDialog,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: c.error,
                      size: 20,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Question
            Text(
              widget.post.title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Options List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final opt = options[index];
                final count = votes[opt] ?? 0;
                final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: showResults
                      ? _buildResultOption(opt, count, percent, c)
                      : _buildTappableOption(opt, c),
                );
              },
            ),
            const SizedBox(height: 8),

            // Footer / Metadata
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getTimeRemaining(),
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTappableOption(String option, AppColorsExtension c) {
    return InkWell(
      onTap: () => _vote(option),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.radio_button_off_rounded, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildResultOption(
      String option, int count, double percent, AppColorsExtension c) {
    final percentText = '${(percent * 100).toStringAsFixed(0)}%';

    return Stack(
      children: [
        // Percentage background track
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 48,
              decoration: BoxDecoration(
                color: c.field,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border.withValues(alpha: 0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * percent,
                    color: c.primary.withValues(alpha: 0.12),
                  ),
                ],
              ),
            );
          },
        ),

        // Text labels overlay
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    '$count ($percentText)',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

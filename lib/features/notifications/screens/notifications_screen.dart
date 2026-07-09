import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/models/post_model.dart';
import '../../home/screens/post_detail_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../videos/screens/community_detail_screen.dart';
import '../../messaging/screens/chat_screen.dart';
import '../../messaging/services/messaging_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  void _markAllAsRead() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: currentUid)
          .where('isRead', isEqualTo: false)
          .get();
      if (snap.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snap.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  // ─── Visual Helpers ────────────────────────────────────────────────────────
  IconData _iconFor(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.mode_comment_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'community':
        return Icons.groups_rounded;
      case 'karma':
        return Icons.bolt_rounded;
      case 'messageRequest':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type, BuildContext context) {
    final c = context.appColors;
    switch (type) {
      case 'like':
        return c.error;
      case 'comment':
        return c.info;
      case 'follow':
        return c.primary;
      case 'community':
        return Colors.teal;
      case 'karma':
        return c.warningKarma;
      case 'messageRequest':
        return c.primary;
      default:
        return c.textMuted;
    }
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt == null || createdAt is! Timestamp) return 'Now';
    final diff = DateTime.now().difference(createdAt.toDate());
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  // ─── Routing Logic ─────────────────────────────────────────────────────────
  Future<void> _handleTap(BuildContext context, Map<String, dynamic> data,
      String docId, String currentUid) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});

    final String type = data['type'] ?? '';
    final String relatedId = data['relatedId'] ?? '';

    if (relatedId.isEmpty || !context.mounted) return;

    switch (type) {
      case 'like':
      case 'comment':
      case 'karma':
        final doc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(relatedId)
            .get();
        if (doc.exists && context.mounted) {
          final post = Post.fromFirestore(doc, currentUid);
          Navigator.of(context)
              .pushNamed(AppRoutes.postDetail, arguments: post);
        }
        break;
      case 'follow':
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(relatedId)
            .get();
        if (userDoc.exists && context.mounted) {
          final userData = userDoc.data() as Map<String, dynamic>;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              userId: relatedId,
              userName: userData['name'] ?? 'User',
              userAvatar: userData['avatarUrl'] ?? '',
            ),
          ));
        }
        break;
      case 'community':
        final commDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(relatedId)
            .get();
        if (commDoc.exists && context.mounted) {
          final commData = commDoc.data() as Map<String, dynamic>;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(
              communityId: relatedId,
              communityName: commData['name'] ?? 'Community',
              communityDescription: commData['description'] ?? '',
            ),
          ));
        }
        break;
      case 'messageRequest':
        final senderId = data['senderId'] ?? '';
        if (senderId.isEmpty || !context.mounted) return;
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(senderId)
            .get();
        if (senderDoc.exists && context.mounted) {
          final senderData = senderDoc.data() as Map<String, dynamic>;
          final name = senderData['name'] ?? 'User';
          final avatar = senderData['avatarUrl'] ?? '';
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: relatedId,
              otherUid: senderId,
              otherName: name,
              otherAvatar: avatar,
              initialAccess: ConversationAccess.pending,
            ),
          ));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bare widget — no Scaffold/AppBar. Inherits sidebar glass background.
    if (currentUid.isEmpty) {
      return Center(
        child: Text('Please log in to view notifications.',
            style: TextStyle(color: c.textSecondary, fontSize: 12)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: currentUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_none_rounded,
                  size: 40, color: c.textMuted),
              const SizedBox(height: 10),
              Text('Loading…',
                  style: TextStyle(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12)),
            ]),
          );
        }

        final rawDocs = snapshot.data?.docs ?? [];
        final docs = rawDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final type = data['type'] as String? ?? '';
          return type != 'message' && type != 'messageRequest';
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: isDark ? 0.18 : 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(Icons.notifications_none_rounded,
                        size: 24, color: c.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('No notifications yet',
                  style: TextStyle(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
            ]),
          );
        }

        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: TextButton.icon(
                  onPressed: () async {
                    final batch = FirebaseFirestore.instance.batch();
                    for (var doc in docs) {
                      batch.delete(doc.reference);
                    }
                    await batch.commit();
                  },
                  icon: Icon(Icons.delete_sweep_rounded, size: 16, color: c.textDim),
                  label: Text('Clear All', style: TextStyle(fontSize: 12, color: c.textDim)),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final bool isRead = data['isRead'] ?? false;
                  final type = data['type'] ?? '';
                  final iconColor = _colorFor(type, context);

                  return Dismissible(
                    key: Key(docs[index].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      padding: const EdgeInsets.only(right: 16),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: c.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: c.error, size: 20),
                    ),
                    onDismissed: (direction) async {
                      final docId = docs[index].id;
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(docId)
                          .delete();
                    },
                    child: GestureDetector(
                      onTap: () =>
                          _handleTap(context, data, docs[index].id, currentUid),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              // Unread rows get a subtle primary tint on top of glass
                              color: isRead
                                  ? (isDark
                                      ? Colors.white.withValues(alpha: 0.07)
                                      : Colors.white.withValues(alpha: 0.40))
                                  : (isDark
                                      ? c.primary.withValues(alpha: 0.15)
                                      : c.primary.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isRead
                                    ? Colors.white.withValues(
                                        alpha: isDark ? 0.12 : 0.50)
                                    : c.primary.withValues(alpha: 0.35),
                                width: isRead ? 0.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon avatar
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_iconFor(type),
                                      color: iconColor, size: 16),
                                ),
                                const SizedBox(width: 10),
                                // Text content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: c.textHi,
                                          fontWeight: isRead
                                              ? FontWeight.w400
                                              : FontWeight.w700,
                                        ),
                                      ),
                                      if ((data['subtitle'] ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          data['subtitle'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Timestamp + unread dot
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatTime(data['createdAt']),
                                      style: TextStyle(
                                          fontSize: 10, color: c.textDim),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: c.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/models/post_model.dart';
import '../../home/screens/post_detail_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../videos/screens/community_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // ─── Visual Helpers ─────────────────────────────────────────────────────────
  IconData _iconFor(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.mode_comment_rounded;
      case 'follow': return Icons.person_add_rounded;
      case 'community': return Icons.groups_rounded;
      case 'karma': return Icons.bolt_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'like': return Colors.redAccent;
      case 'comment': return Colors.blue;
      case 'follow': return AppColors.primary;
      case 'community': return Colors.teal;
      default: return Colors.grey;
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

  // ─── Routing Logic ──────────────────────────────────────────────────────────
  Future<void> _handleTap(BuildContext context, Map<String, dynamic> data, String docId, String currentUid) async {
    await FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});

    final String type = data['type'] ?? '';
    final String relatedId = data['relatedId'] ?? '';

    if (relatedId.isEmpty || !context.mounted) return;

    switch (type) {
      case 'like':
      case 'comment':
        final doc = await FirebaseFirestore.instance.collection('posts').doc(relatedId).get();
        if (doc.exists && context.mounted) {
          final post = Post.fromFirestore(doc, currentUid);
          Navigator.of(context).pushNamed(AppRoutes.postDetail, arguments: post);
        }
        break;
      case 'follow':
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(relatedId).get();
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
        final commDoc = await FirebaseFirestore.instance.collection('communities').doc(relatedId).get();
        if (commDoc.exists && context.mounted) {
          final data = commDoc.data() as Map<String, dynamic>;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(
              communityId: relatedId,
              communityName: data['name'] ?? 'Community',
              communityDescription: data['description'] ?? '',
            ),
          ));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: currentUid.isEmpty
          ? const Center(child: Text('Please log in to view notifications.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: currentUid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;

                // Single, consolidated empty state
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No recent notifications', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isRead = data['isRead'] ?? false;

                    return Container(
                      color: isRead ? Colors.white : AppColors.primary.withOpacity(0.04),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _colorFor(data['type']).withOpacity(0.12),
                          child: Icon(_iconFor(data['type']), color: _colorFor(data['type']), size: 18),
                        ),
                        title: Text(data['title'] ?? '', style: TextStyle(fontSize: 14, fontWeight: isRead ? FontWeight.w400 : FontWeight.w600)),
                        subtitle: Text(data['subtitle'] ?? '', style: const TextStyle(fontSize: 12)),
                        trailing: Text(_formatTime(data['createdAt']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        onTap: () => _handleTap(context, data, docs[index].id, currentUid),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
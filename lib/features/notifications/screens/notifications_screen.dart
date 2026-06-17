import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';

/// Screen 15: Notifications Screen
/// Displays user real-time live database updates for likes, comments, follows, karma, and messages.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.mode_comment_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'karma':
        return Icons.bolt_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'like':
        return AppColors.error;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return AppColors.primary;
      case 'karma':
        // Safe fallback if AppColors.karmaPositive is an arbitrary custom value
        return Colors.amber.shade700; 
      case 'message':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Helper to convert Firestore Timestamps to a simple relative time layout string
  String _formatTime(dynamic createdAt) {
    if (createdAt == null || createdAt is! Timestamp) return 'Just now';
    final DateTime notificationDate = createdAt.toDate();
    final Duration difference = DateTime.now().difference(notificationDate);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: currentUid.isEmpty
          ? const Center(child: Text('Please log in to view notifications.'))
          : StreamBuilder<QuerySnapshot>(
              // Fetch from the top-level notifications collection filtered by recipient token
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: currentUid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading notifications: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Your inbox is empty',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String type = data['type'] ?? 'text';
                    final String title = data['title'] ?? '';
                    final String subtitle = data['subtitle'] ?? '';
                    final bool isRead = data['isRead'] ?? false;

                    return Container(
                      color: isRead ? Colors.transparent : AppColors.primary.withOpacity(0.03),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _colorFor(type).withOpacity(0.12),
                          child: Icon(_iconFor(type), color: _colorFor(type), size: 20),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: subtitle.isNotEmpty
                            ? Text(
                                subtitle,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Text(
                          _formatTime(data['createdAt']),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                        onTap: () async {
                          // 1. Mark as read on tap atomicity action
                          FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(docs[index].id)
                              .update({'isRead': true});

                          // 2. TODO: Extract navigation payload targets (e.g., data['relatedId'])
                          // to route directly to specific posts/chats
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
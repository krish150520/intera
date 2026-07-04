import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Sends a notification to a specific recipient.
  /// Prevents self-notifications (e.g. if you like/comment on your own post).
  static Future<void> sendNotification({
    required String recipientId,
    required String type,
    required String title,
    required String subtitle,
    required String relatedId,
  }) async {
    final senderId = _auth.currentUser?.uid ?? '';
    // Do not notify oneself
    if (senderId == recipientId) return;

    await _db.collection('notifications').add({
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'relatedId': relatedId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of unread notification count for a user.
  static Stream<int> unreadCountStream(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Handles liking/unliking a post, and triggers a notification if liked.
  static Future<void> toggleLike({
    required String postId,
    required String postAuthorId,
    required String postTitle,
    required String currentUid,
    required List likedBy,
  }) async {
    if (currentUid.isEmpty) return;
    final ref = _db.collection('posts').doc(postId);
    final isLiked = likedBy.contains(currentUid);

    if (isLiked) {
      await ref.update({
        'likeCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([currentUid]),
      });
    } else {
      await ref.update({
        'likeCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([currentUid]),
      });

      // Get current user's name
      String senderName = 'Someone';
      try {
        final userDoc = await _db.collection('users').doc(currentUid).get();
        if (userDoc.exists) {
          senderName = userDoc.data()?['name'] ?? 'Someone';
        }
      } catch (_) {}

      await sendNotification(
        recipientId: postAuthorId,
        type: 'like',
        title: '$senderName liked your post',
        subtitle: postTitle.isNotEmpty ? postTitle : 'View post details',
        relatedId: postId,
      );
    }
  }
}

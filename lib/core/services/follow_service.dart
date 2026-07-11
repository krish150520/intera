import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Toggles follow state transactions securely between two users
  Future<void> toggleFollowUser({
    required String currentUserId,
    required String targetUserId,
    required bool isCurrentlyFollowing,
  }) async {
    // Reference paths pointing straight to unique profile nodes
    final DocumentReference currentUserDoc = _firestore.collection('users').doc(currentUserId);
    final DocumentReference targetUserDoc = _firestore.collection('users').doc(targetUserId);

    final DocumentReference followingRef = currentUserDoc.collection('following').doc(targetUserId);
    final DocumentReference followersRef = targetUserDoc.collection('followers').doc(currentUserId);

    final WriteBatch batch = _firestore.batch();

    if (isCurrentlyFollowing) {
      // 1. Unfollow: Remove tracking documents out of sub-collections
      batch.delete(followingRef);
      batch.delete(followersRef);

      // 2. Decrement historical counter blocks atomatically
      batch.update(currentUserDoc, {'followingCount': FieldValue.increment(-1)});
      batch.update(targetUserDoc, {'followersCount': FieldValue.increment(-1)});
    } else {
      // 1. Follow: Insert document payload markers into sub-collections
      batch.set(followingRef, {
        'uid': targetUserId,
        'followedAt': FieldValue.serverTimestamp(),
      });
      batch.set(followersRef, {
        'uid': currentUserId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      // 2. Increment metric counter aggregates atomatically
      batch.update(currentUserDoc, {'followingCount': FieldValue.increment(1)});
      batch.update(targetUserDoc, {'followersCount': FieldValue.increment(1)});
    }

    // Atomically commit both sub-collection updates and count changes together
    await batch.commit();

    if (!isCurrentlyFollowing) {
      // Trigger follow notification
      try {
        String senderName = 'Someone';
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        if (userDoc.exists) {
          senderName = userDoc.data()?['name'] ?? 'Someone';
        }
        await NotificationService.sendNotification(
          recipientId: targetUserId,
          type: 'follow',
          title: '$senderName started following you',
          subtitle: 'Check out their profile!',
          relatedId: currentUserId,
        );
      } catch (e) {
        // Fail silently so it doesn't interrupt the main follow operation
        debugPrint('Error sending follow notification: $e');
      }
    }
  }

  /// Real-time stream tracker to check if the current user is following a target user
  Stream<bool> isFollowingStream({required String currentUserId, required String targetUserId}) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class ReactionService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Map reaction types to their corresponding count and user points fields.
  static const Map<String, String> _postFields = {
    'beauty': 'beautyCount',
    'art': 'artCount',
    'funny': 'funnyCount',
  };

  static const Map<String, String> _userFields = {
    'beauty': 'beautyPoints',
    'art': 'artPoints',
    'funny': 'funnyPoints',
  };

  static Future<void> toggleReaction({
    required String postId,
    required String postAuthorId,
    required String postTitle,
    required String currentUid,
    required String reactionType, // 'like', 'beauty', 'art', 'funny'
  }) async {
    if (currentUid.isEmpty) return;

    final postRef = _db.collection('posts').doc(postId);
    final authorRef = _db.collection('users').doc(postAuthorId);

    await _db.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) return;

      final postData = postSnap.data() as Map<String, dynamic>;
      final reactions = Map<String, String>.from(postData['reactions'] ?? {});
      final likedBy = List<String>.from(postData['likedBy'] ?? []);

      final String? existingReaction = reactions[currentUid];

      // Prepare updates
      final Map<String, dynamic> postUpdates = {};
      final Map<String, dynamic> authorUpdates = {};

      if (existingReaction == reactionType) {
        // ── Remove Reaction ──────────────────────────────────────────────────
        reactions.remove(currentUid);
        likedBy.remove(currentUid);

        postUpdates['likeCount'] = FieldValue.increment(-1);
        postUpdates['likedBy'] = likedBy;
        postUpdates['reactions'] = reactions;

        // Decrement the category count on the post & author profile
        final postField = _postFields[reactionType];
        if (postField != null) {
          postUpdates[postField] = FieldValue.increment(-1);
        }
        final userField = _userFields[reactionType];
        if (userField != null) {
          authorUpdates[userField] = FieldValue.increment(-1);
        }
      } else {
        // ── Add or Change Reaction ───────────────────────────────────────────
        reactions[currentUid] = reactionType;

        if (existingReaction == null) {
          // Add for the first time
          likedBy.add(currentUid);
          postUpdates['likeCount'] = FieldValue.increment(1);
          postUpdates['likedBy'] = likedBy;
        } else {
          // Change reaction: decrement old reaction counts/points first
          final oldPostField = _postFields[existingReaction];
          if (oldPostField != null) {
            postUpdates[oldPostField] = FieldValue.increment(-1);
          }
          final oldUserField = _userFields[existingReaction];
          if (oldUserField != null) {
            authorUpdates[oldUserField] = FieldValue.increment(-1);
          }
        }

        postUpdates['reactions'] = reactions;

        // Increment the new reaction counts/points
        final newPostField = _postFields[reactionType];
        if (newPostField != null) {
          postUpdates[newPostField] = FieldValue.increment(1);
        }
        final newUserField = _userFields[reactionType];
        if (newUserField != null) {
          authorUpdates[newUserField] = FieldValue.increment(1);
        }
      }

      // Commit changes in transaction
      transaction.update(postRef, postUpdates);
      if (authorUpdates.isNotEmpty) {
        transaction.update(authorRef, authorUpdates);
      }
    });

    // Send a notification if a reaction was added or changed (not removed)
    final postSnap = await postRef.get();
    final reactions = Map<String, String>.from(postSnap.data()?['reactions'] ?? {});
    if (reactions[currentUid] == reactionType) {
      String senderName = 'Someone';
      try {
        final userDoc = await _db.collection('users').doc(currentUid).get();
        if (userDoc.exists) {
          senderName = userDoc.data()?['name'] ?? 'Someone';
        }
      } catch (_) {}

      String reactionEmoji = '👍';
      if (reactionType == 'beauty') reactionEmoji = '💖';
      if (reactionType == 'art') reactionEmoji = '🎨';
      if (reactionType == 'funny') reactionEmoji = '😂';

      await NotificationService.sendNotification(
        recipientId: postAuthorId,
        type: 'reaction',
        title: '$senderName reacted with $reactionEmoji to your post',
        subtitle: postTitle.isNotEmpty ? postTitle : 'View post details',
        relatedId: postId,
      );
    }
  }
}

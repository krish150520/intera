import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Transaction types stored in Firestore ledger.
enum KarmaTxType {
  earnedBestAnswer,   // answerer was marked best → earned reward
  tipGiven,           // poster tipped any commenter
  tipReceived,        // receiver side of tip
  deductedHelpPost,   // reserved karma when help post created
  refundedHelpPost,   // refunded if post cancelled without awarding
}

class KarmaService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Read balance ───────────────────────────────────────────────────────────

  static Stream<int> balanceStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
      (snap) => (snap.data()?['karmaBalance'] as num?)?.toInt() ??
                (snap.data()?['karmaPoints'] as num?)?.toInt() ?? 100,
    );
  }

  static Future<int> getBalance(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['karmaBalance'] as num?)?.toInt() ??
           (snap.data()?['karmaPoints'] as num?)?.toInt() ?? 100;
  }

  // ── Sync incoming karma (TIPS & BEST ANSWER AWARDS) ──────────────────────
  // Since clients cannot modify other users' documents, when a user is tipped
  // or awarded karma, the sender creates the ledger transaction but does not
  // modify the recipient's user document. The recipient's client will pull
  // and sync these updates when they launch the app or open their profile.
  static Future<void> syncKarmaBalance(String uid) async {
    if (uid.isEmpty) return;
    try {
      final userRef = _db.collection('users').doc(uid);
      final userSnap = await userRef.get();
      if (!userSnap.exists) return;

      final userData = userSnap.data() ?? {};
      final currentBalance = (userData['karmaBalance'] as num?)?.toInt() ??
                             (userData['karmaPoints'] as num?)?.toInt() ?? 100;
      final lastSyncTimestamp = userData['lastKarmaSyncTime'] as Timestamp?;

      // Query transactions where we are the recipient
      Query query = _db.collection('karmaTransactions').where('toUid', isEqualTo: uid);
      if (lastSyncTimestamp != null) {
        query = query.where('createdAt', isGreaterThan: lastSyncTimestamp);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) {
        // Even if no new docs, initialize karmaBalance field if it was missing
        if (userData['karmaBalance'] == null) {
          await userRef.update({
            'karmaBalance': currentBalance,
            'lastKarmaSyncTime': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      int addedKarma = 0;
      Timestamp? latestTimestamp = lastSyncTimestamp;

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final fromUid = data['fromUid'] as String?;
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final createdAt = data['createdAt'] as Timestamp?;

        // Only count if it's from another user (i.e. fromUid is not null and not ourselves)
        // Weekly bonus / refund are claimed by ourselves and already applied
        if (fromUid != null && fromUid != uid) {
          addedKarma += amount;
        }

        if (createdAt != null) {
          if (latestTimestamp == null || createdAt.compareTo(latestTimestamp) > 0) {
            latestTimestamp = createdAt;
          }
        }
      }

      final updates = <String, dynamic>{
        'karmaBalance': currentBalance + addedKarma,
        if (latestTimestamp != null) 'lastKarmaSyncTime': latestTimestamp,
      };
      await userRef.update(updates);
    } catch (e) {
      // Fail silently in production
      debugPrint('[KarmaService] Error syncing karma balance: $e');
    }
  }

  // ── Reserve karma on help post creation ───────────────────────────────────
  // Deducts the reward from poster's balance immediately so they can't spend it.

  static Future<void> reserveForHelpPost({
    required String postId,
    required int amount,
  }) async {
    if (amount <= 0) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final balance = await getBalance(uid);
    if (balance < amount) {
      throw Exception('Insufficient karma. You have $balance karma but need $amount.');
    }

    final batch = _db.batch();

    // Deduct from poster
    batch.update(_db.collection('users').doc(uid), {
      'karmaBalance': FieldValue.increment(-amount),
    });

    // Ledger entry
    final txRef = _db.collection('karmaTransactions').doc();
    batch.set(txRef, {
      'fromUid':   uid,
      'toUid':     null,
      'amount':    amount,
      'type':      KarmaTxType.deductedHelpPost.name,
      'postId':    postId,
      'note':      'Reserved for help request',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Award best answer ──────────────────────────────────────────────────────
  // Marks the post completed, transfers the reserved reward to the answerer.

  static Future<void> awardBestAnswer({
    required String postId,
    required String winnerUid,
    required String commentId,
    required int rewardAmount,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw Exception('Not logged in');

    final postRef = _db.collection('posts').doc(postId);
    final postSnap = await postRef.get();
    final postData = postSnap.data() ?? {};

    if (postData['authorId'] != currentUid) {
      throw Exception('Only the post author can award best answer.');
    }
    if (postData['isCompleted'] == true) {
      throw Exception('This help request is already completed.');
    }

    final batch = _db.batch();

    // Mark post completed
    batch.update(postRef, {
      'isCompleted':        true,
      'bestAnswerCommentId': commentId,
      'bestAnswerUid':      winnerUid,
    });

    // Ledger — earn entry for winner (winner's client will pull/sync this transaction)
    final earnRef = _db.collection('karmaTransactions').doc();
    batch.set(earnRef, {
      'fromUid':   currentUid,
      'toUid':     winnerUid,
      'amount':    rewardAmount,
      'type':      KarmaTxType.earnedBestAnswer.name,
      'postId':    postId,
      'commentId': commentId,
      'note':      'Best answer reward',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Tip any commenter ──────────────────────────────────────────────────────

  static Future<void> tipUser({
    required String toUid,
    required String toName,
    required int amount,
    required String postId,
    String? commentId,
  }) async {
    if (amount <= 0) throw Exception('Tip must be at least 1 karma.');
    final fromUid = _auth.currentUser?.uid;
    if (fromUid == null) throw Exception('Not logged in');
    if (fromUid == toUid) throw Exception('Cannot tip yourself.');

    final balance = await getBalance(fromUid);
    if (balance < amount) {
      throw Exception('Insufficient karma. You have $balance karma.');
    }

    final batch = _db.batch();

    // Deduct tipper
    batch.update(_db.collection('users').doc(fromUid), {
      'karmaBalance': FieldValue.increment(-amount),
    });

    // Ledger — given (recipient's client will pull/sync this transaction)
    final givenRef = _db.collection('karmaTransactions').doc();
    batch.set(givenRef, {
      'fromUid':   fromUid,
      'toUid':     toUid,
      'amount':    amount,
      'type':      KarmaTxType.tipGiven.name,
      'postId':    postId,
      if (commentId != null) 'commentId': commentId,
      'note':      'Tip to $toName',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Ledger — received
    final receivedRef = _db.collection('karmaTransactions').doc();
    batch.set(receivedRef, {
      'fromUid':   fromUid,
      'toUid':     toUid,
      'amount':    amount,
      'type':      KarmaTxType.tipReceived.name,
      'postId':    postId,
      if (commentId != null) 'commentId': commentId,
      'note':      'Tip received',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Refund if post deleted before awarding ─────────────────────────────────

  static Future<void> refundHelpPost({
    required String postId,
    required int amount,
  }) async {
    if (amount <= 0) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final batch = _db.batch();

    batch.update(_db.collection('users').doc(uid), {
      'karmaBalance': FieldValue.increment(amount),
    });

    final txRef = _db.collection('karmaTransactions').doc();
    batch.set(txRef, {
      'fromUid':   null,
      'toUid':     uid,
      'amount':    amount,
      'type':      KarmaTxType.refundedHelpPost.name,
      'postId':    postId,
      'note':      'Refunded — help request cancelled',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Transaction history for a user ────────────────────────────────────────

  static Stream<QuerySnapshot> transactionStream(String uid) {
    return _db
        .collection('karmaTransactions')
        .where(Filter.or(
          Filter('fromUid', isEqualTo: uid),
          Filter('toUid',   isEqualTo: uid),
        ))
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }
}

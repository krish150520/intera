import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      (snap) => (snap.data()?['karmaBalance'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<int> getBalance(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['karmaBalance'] as num?)?.toInt() ?? 0;
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

    // Credit winner
    batch.update(_db.collection('users').doc(winnerUid), {
      'karmaBalance': FieldValue.increment(rewardAmount),
    });

    // Ledger — earn entry for winner
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

    // Credit receiver
    batch.update(_db.collection('users').doc(toUid), {
      'karmaBalance': FieldValue.increment(amount),
    });

    // Ledger — given
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
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/services/notification_service.dart';

/// Who can message whom, and what state a new thread starts in:
/// - If [otherUid] already follows me -> they've opted into hearing from
///   me, so the thread opens 'active' immediately, like a normal DM.
/// - If [otherUid] does NOT follow me -> the thread opens 'pending'. I can
///   still send messages into it (an Instagram-style "message request"),
///   but it's flagged for the recipient as a request until they reply,
///   at which point it flips to 'active' for both sides.
enum ConversationAccess { active, pending }

/// Handles all Firestore + Storage operations for 1-on-1 messaging.
class MessagingService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  /// Deterministic conversation id so two users always land in the same
  /// thread, regardless of who initiates - no lookup query required.
  String conversationIdFor(String otherUid) {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Not authenticated');
    final ids = [myUid, otherUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Checks whether [otherUid] follows the current user, i.e. whether my
  /// uid exists in their 'following' subcollection. This is the gate for
  /// whether a new thread opens active or as a pending request.
  Future<bool> doesUserFollowMe(String otherUid) async {
    final myUid = _myUid;
    if (myUid == null) return false;
    final doc = await _db
        .collection('users')
        .doc(myUid)
        .collection('followers')
        .doc(otherUid)
        .get();
    return doc.exists;
  }

  /// Ensures a conversation document exists between the current user and
  /// [otherUid]. Safe to call every time a chat is opened - if the
  /// conversation already exists, its status is left untouched (so an
  /// active thread never gets reset to pending, and a pending thread
  /// isn't silently auto-accepted just by being reopened).
  ///
  /// Returns the conversation id alongside the access level so the caller
  /// (e.g. UserProfileScreen) knows whether to open chat directly or warn
  /// the sender this will go out as a message request.
  Future<({String conversationId, ConversationAccess access})>
      getOrCreateConversation({
    required String otherUid,
    required String myName,
    required String myAvatar,
    required String otherName,
    required String otherAvatar,
  }) async {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Not authenticated');

    final convoId = conversationIdFor(otherUid);
    final docRef = _db.collection('conversations').doc(convoId);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final status = (snapshot.data())?['status'] as String? ?? 'active';
      return (
        conversationId: convoId,
        access: status == 'pending'
            ? ConversationAccess.pending
            : ConversationAccess.active,
      );
    }

    final theyFollowMe = await doesUserFollowMe(otherUid);
    final access =
        theyFollowMe ? ConversationAccess.active : ConversationAccess.pending;

    await docRef.set({
      'participants': [myUid, otherUid],
      'participantInfo': {
        myUid: {'name': myName, 'avatar': myAvatar},
        otherUid: {'name': otherName, 'avatar': otherAvatar},
      },
      'lastMessage': '',
      'lastMessageType': 'text',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': '',
      'unreadCount': {myUid: 0, otherUid: 0},
      'status': access == ConversationAccess.active ? 'active' : 'pending',
      'requestedBy': myUid,
    });

    if (access == ConversationAccess.pending) {
      await NotificationService.sendNotification(
        recipientId: otherUid,
        type: 'messageRequest',
        title: '$myName sent you a message request',
        subtitle: 'Tap to accept and reply',
        relatedId: convoId,
      );
    }

    return (conversationId: convoId, access: access);
  }

  /// Recipient accepts a pending message request - flips the thread to
  /// active for both participants. Call this the moment the recipient
  /// sends a reply, or from an explicit "Accept" action.
  Future<void> acceptMessageRequest(String conversationId) async {
    await _db.collection('conversations').doc(conversationId).update({
      'status': 'active',
    });
  }

  /// Recipient declines a pending request. The thread is left in place
  /// (so the sender's messages aren't lost) but marked declined, which the
  /// UI should treat like a hidden/archived thread for the recipient.
  Future<void> declineMessageRequest(String conversationId) async {
    await _db.collection('conversations').doc(conversationId).update({
      'status': 'declined',
    });
  }

  /// Pending requests sent TO the current user (i.e. people who messaged
  /// me before I followed them back) - surface this as a "Requests" inbox
  /// separate from the main conversations list.
  Stream<QuerySnapshot> pendingRequestsStream() {
    final myUid = _myUid;
    if (myUid == null) return const Stream.empty();
    return _db
        .collection('conversations')
        .where('participants', arrayContains: myUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  /// Stream of conversations the current user is part of, newest first.
  Stream<QuerySnapshot> conversationsStream() {
    final myUid = _myUid;
    if (myUid == null) return const Stream.empty();
    return _db
        .collection('conversations')
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  /// Stream of messages within a conversation, oldest first (for a
  /// bottom-anchored chat list, reverse in the UI as needed).
  Stream<QuerySnapshot> messagesStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String otherUid,
    required String text,
  }) async {
    final myUid = _myUid;
    if (myUid == null || text.trim().isEmpty) return;

    final convoRef = _db.collection('conversations').doc(conversationId);
    final msgRef = convoRef.collection('messages').doc();

    // If this thread is a pending request and I'm the one replying (not
    // the original requester), my reply means I've accepted it.
    final convoSnap = await convoRef.get();
    final convoData = convoSnap.data();
    final isPending = convoData?['status'] == 'pending';
    final requestedBy = convoData?['requestedBy'];
    final shouldAutoAccept = isPending && requestedBy != myUid;

    final batch = _db.batch();
    batch.set(msgRef, {
      'senderId': myUid,
      'text': text.trim(),
      'imageUrl': null,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
    });
    batch.update(convoRef, {
      'lastMessage': text.trim(),
      'lastMessageType': 'text',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': myUid,
      'unreadCount.$otherUid': FieldValue.increment(1),
      if (shouldAutoAccept) 'status': 'active',
    });

    await batch.commit();

    // Trigger mobile system tray notification via database
    String senderName = 'Someone';
    try {
      final userDoc = await _db.collection('users').doc(myUid).get();
      if (userDoc.exists) {
        senderName = userDoc.data()?['name'] ?? 'Someone';
      }
    } catch (_) {}

    await NotificationService.sendNotification(
      recipientId: otherUid,
      type: isPending ? 'messageRequest' : 'message',
      title: isPending ? 'Message request from $senderName' : 'New message from $senderName',
      subtitle: text.trim(),
      relatedId: conversationId,
    );
  }

  Future<void> sendSharedPostMessage({
    required String conversationId,
    required String otherUid,
    required String postId,
    required String postType,
    required String postTitle,
    required String postBody,
    String? postImageUrl,
    String? postVideoThumbnail,
    required String postAuthorUsername,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return;

    final convoRef = _db.collection('conversations').doc(conversationId);
    final msgRef = convoRef.collection('messages').doc();

    final convoSnap = await convoRef.get();
    final convoData = convoSnap.data();
    final isPending = convoData?['status'] == 'pending';
    final requestedBy = convoData?['requestedBy'];
    final shouldAutoAccept = isPending && requestedBy != myUid;

    final textRepresentation = 'Shared a post: "$postTitle" by @$postAuthorUsername';

    final batch = _db.batch();
    batch.set(msgRef, {
      'senderId': myUid,
      'text': textRepresentation,
      'type': 'sharedPost',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
      'sharedPostId': postId,
      'sharedPostType': postType,
      'sharedPostTitle': postTitle,
      'sharedPostBody': postBody,
      if (postImageUrl != null) 'sharedPostImageUrl': postImageUrl,
      if (postVideoThumbnail != null) 'sharedPostVideoThumbnail': postVideoThumbnail,
      'sharedPostAuthorUsername': postAuthorUsername,
    });
    
    batch.update(convoRef, {
      'lastMessage': textRepresentation,
      'lastMessageType': 'sharedPost',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': myUid,
      'unreadCount.$otherUid': FieldValue.increment(1),
      if (shouldAutoAccept) 'status': 'active',
    });

    await batch.commit();

    // Send push notification
    String senderName = 'Someone';
    try {
      final userDoc = await _db.collection('users').doc(myUid).get();
      if (userDoc.exists) {
        senderName = userDoc.data()?['name'] ?? 'Someone';
      }
    } catch (_) {}

    await NotificationService.sendNotification(
      recipientId: otherUid,
      type: isPending ? 'messageRequest' : 'message',
      title: isPending ? 'Message request from $senderName' : 'New message from $senderName',
      subtitle: textRepresentation,
      relatedId: conversationId,
    );
  }

  Future<void> sendImageMessage({
    required String conversationId,
    required String otherUid,
    required File imageFile,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return;

    final convoRef = _db.collection('conversations').doc(conversationId);
    final msgRef = convoRef.collection('messages').doc();

    final convoSnap = await convoRef.get();
    final convoData = convoSnap.data();
    final isPending = convoData?['status'] == 'pending';
    final requestedBy = convoData?['requestedBy'];
    final shouldAutoAccept = isPending && requestedBy != myUid;

    // Upload image to Storage first
    final storageRef = _storage
        .ref()
        .child('chat_images')
        .child(conversationId)
        .child('${msgRef.id}.jpg');
    final uploadTask = await storageRef.putFile(imageFile);
    final imageUrl = await uploadTask.ref.getDownloadURL();

    final batch = _db.batch();
    batch.set(msgRef, {
      'senderId': myUid,
      'text': null,
      'imageUrl': imageUrl,
      'type': 'image',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
    });
    batch.update(convoRef, {
      'lastMessage': '📷 Photo',
      'lastMessageType': 'image',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': myUid,
      'unreadCount.$otherUid': FieldValue.increment(1),
      if (shouldAutoAccept) 'status': 'active',
    });

    await batch.commit();

    // Trigger mobile system tray notification via database
    String senderName = 'Someone';
    try {
      final userDoc = await _db.collection('users').doc(myUid).get();
      if (userDoc.exists) {
        senderName = userDoc.data()?['name'] ?? 'Someone';
      }
    } catch (_) {}

    await NotificationService.sendNotification(
      recipientId: otherUid,
      type: isPending ? 'messageRequest' : 'message',
      title: isPending ? 'Message request from $senderName' : 'New photo from $senderName',
      subtitle: '📷 Photo',
      relatedId: conversationId,
    );
  }

  /// Resets the current user's unread counter for a conversation - call
  /// when entering a ChatScreen.
  Future<void> markConversationRead(String conversationId) async {
    final myUid = _myUid;
    if (myUid == null) return;
    await _db.collection('conversations').doc(conversationId).update({
      'unreadCount.$myUid': 0,
    });
  }

  /// Sum of unread counts across all conversations - useful for a nav-bar
  /// badge.
  Stream<int> totalUnreadStream() {
    final myUid = _myUid;
    if (myUid == null) return const Stream.empty();
    return _db
        .collection('conversations')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final unread = data['unreadCount']?[myUid];
        if (unread is int) total += unread;
      }
      return total;
    });
  }
}

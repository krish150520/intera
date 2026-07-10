import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Chat mode that controls who can send messages in a community chatroom.
///
/// - [everyone]      – All members can read & send (default).
/// - [membersOnly]   – Only joined members can send; non-members can't access.
/// - [announcement]  – Only admins can send; members can read.
enum CommunityChatMode {
  everyone,
  membersOnly,
  announcement;

  /// Firestore string → enum.
  static CommunityChatMode fromString(String? value) {
    switch (value) {
      case 'membersOnly':
        return CommunityChatMode.membersOnly;
      case 'announcement':
        return CommunityChatMode.announcement;
      default:
        return CommunityChatMode.everyone;
    }
  }

  /// Enum → Firestore string.
  String toFirestore() {
    switch (this) {
      case CommunityChatMode.everyone:
        return 'everyone';
      case CommunityChatMode.membersOnly:
        return 'membersOnly';
      case CommunityChatMode.announcement:
        return 'announcement';
    }
  }

  /// Human-readable label.
  String get label {
    switch (this) {
      case CommunityChatMode.everyone:
        return 'Everyone';
      case CommunityChatMode.membersOnly:
        return 'Members Only';
      case CommunityChatMode.announcement:
        return 'Announcement';
    }
  }

  /// Short description for the settings sheet.
  String get description {
    switch (this) {
      case CommunityChatMode.everyone:
        return 'All members can send messages in the chatroom.';
      case CommunityChatMode.membersOnly:
        return 'Only joined members can send messages.';
      case CommunityChatMode.announcement:
        return 'Only admins can send messages. Members can read.';
    }
  }
}

/// Handles all Firestore + Storage operations for community group chat.
class CommunityChatService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns whether [uid] is allowed to send messages in a chatroom given
  /// the current [chatMode], [admins] list, and [members] list.
  static bool canSend({
    required CommunityChatMode chatMode,
    required List admins,
    required List members,
    required String uid,
  }) {
    switch (chatMode) {
      case CommunityChatMode.announcement:
        return admins.contains(uid);
      case CommunityChatMode.membersOnly:
        return members.contains(uid);
      case CommunityChatMode.everyone:
        return members.contains(uid);
    }
  }

  // ── Streams ──────────────────────────────────────────────────────────────

  /// Real-time stream of chat messages for a community, newest first.
  static Stream<QuerySnapshot> messagesStream(String communityId) {
    return _db
        .collection('communities')
        .doc(communityId)
        .collection('chat_messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Sending ──────────────────────────────────────────────────────────────

  /// Sends a text message into the community chatroom.
  /// Returns `true` on success, `false` if the user lacks permission.
  static Future<bool> sendTextMessage({
    required String communityId,
    required String text,
  }) async {
    final uid = _myUid;
    if (uid == null || text.trim().isEmpty) return false;

    // Check permission
    final allowed = await _checkSendPermission(communityId, uid);
    if (!allowed) return false;

    // Fetch sender info
    final senderInfo = await _getSenderInfo(uid);

    await _db
        .collection('communities')
        .doc(communityId)
        .collection('chat_messages')
        .add({
      'senderId': uid,
      'senderName': senderInfo['name'],
      'senderAvatar': senderInfo['avatar'],
      'text': text.trim(),
      'imageUrl': null,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Sends an image message into the community chatroom.
  /// Returns `true` on success, `false` if the user lacks permission.
  static Future<bool> sendImageMessage({
    required String communityId,
    required File imageFile,
  }) async {
    final uid = _myUid;
    if (uid == null) return false;

    final allowed = await _checkSendPermission(communityId, uid);
    if (!allowed) return false;

    final senderInfo = await _getSenderInfo(uid);

    // Upload image
    final msgId = _db
        .collection('communities')
        .doc(communityId)
        .collection('chat_messages')
        .doc()
        .id;

    final storageRef = _storage
        .ref()
        .child('community_chat')
        .child(communityId)
        .child('$msgId.jpg');

    final uploadTask = await storageRef.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final imageUrl = await uploadTask.ref.getDownloadURL();

    await _db
        .collection('communities')
        .doc(communityId)
        .collection('chat_messages')
        .doc(msgId)
        .set({
      'senderId': uid,
      'senderName': senderInfo['name'],
      'senderAvatar': senderInfo['avatar'],
      'text': null,
      'imageUrl': imageUrl,
      'type': 'image',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  // ── Admin Actions ────────────────────────────────────────────────────────

  /// Updates the chat mode for a community (admin-only) and posts a system
  /// message announcing the change.
  static Future<bool> updateChatMode({
    required String communityId,
    required CommunityChatMode newMode,
  }) async {
    final uid = _myUid;
    if (uid == null) return false;

    // Verify caller is admin
    final communityDoc =
        await _db.collection('communities').doc(communityId).get();
    final data = communityDoc.data() ?? {};
    final admins = List.from(data['admins'] ?? []);
    if (!admins.contains(uid)) return false;

    // Update community doc
    await _db.collection('communities').doc(communityId).update({
      'chatMode': newMode.toFirestore(),
    });

    // Post system message
    final senderInfo = await _getSenderInfo(uid);
    await _db
        .collection('communities')
        .doc(communityId)
        .collection('chat_messages')
        .add({
      'senderId': uid,
      'senderName': senderInfo['name'],
      'senderAvatar': null,
      'text': '${senderInfo['name']} changed chat mode to ${newMode.label}',
      'imageUrl': null,
      'type': 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  /// Checks whether the current user is allowed to send in this community.
  static Future<bool> _checkSendPermission(
      String communityId, String uid) async {
    try {
      final doc =
          await _db.collection('communities').doc(communityId).get();
      final data = doc.data() ?? {};
      final chatMode =
          CommunityChatMode.fromString(data['chatMode'] as String?);
      final admins = List.from(data['admins'] ?? []);
      final members = List.from(data['members'] ?? []);
      return canSend(
        chatMode: chatMode,
        admins: admins,
        members: members,
        uid: uid,
      );
    } catch (e) {
      debugPrint('CommunityChatService._checkSendPermission error: $e');
      return false;
    }
  }

  /// Fetches the current user's display name and avatar URL.
  static Future<Map<String, String>> _getSenderInfo(String uid) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final data = userDoc.data() ?? {};
      return {
        'name': data['name'] ?? 'User',
        'avatar': data['profileImageUrl'] ?? '',
      };
    } catch (_) {
      return {'name': 'User', 'avatar': ''};
    }
  }
}

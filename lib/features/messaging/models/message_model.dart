import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, sharedPost }

class MessageModel {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final MessageType type;
  final DateTime createdAt;
  final bool isRead;

  // Shared post metadata fields
  final String? sharedPostId;
  final String? sharedPostType;
  final String? sharedPostTitle;
  final String? sharedPostBody;
  final String? sharedPostImageUrl;
  final String? sharedPostVideoThumbnail;
  final String? sharedPostAuthorUsername;

  MessageModel({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.sharedPostId,
    this.sharedPostType,
    this.sharedPostTitle,
    this.sharedPostBody,
    this.sharedPostImageUrl,
    this.sharedPostVideoThumbnail,
    this.sharedPostAuthorUsername,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    MessageType mType = MessageType.text;
    final typeStr = data['type'] as String?;
    if (typeStr == 'image') {
      mType = MessageType.image;
    } else if (typeStr == 'sharedPost') {
      mType = MessageType.sharedPost;
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'],
      imageUrl: data['imageUrl'],
      type: mType,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['status'] == 'read',
      sharedPostId: data['sharedPostId'],
      sharedPostType: data['sharedPostType'],
      sharedPostTitle: data['sharedPostTitle'],
      sharedPostBody: data['sharedPostBody'],
      sharedPostImageUrl: data['sharedPostImageUrl'],
      sharedPostVideoThumbnail: data['sharedPostVideoThumbnail'],
      sharedPostAuthorUsername: data['sharedPostAuthorUsername'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'type': type == MessageType.image
          ? 'image'
          : type == MessageType.sharedPost
              ? 'sharedPost'
              : 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
      if (sharedPostId != null) 'sharedPostId': sharedPostId,
      if (sharedPostType != null) 'sharedPostType': sharedPostType,
      if (sharedPostTitle != null) 'sharedPostTitle': sharedPostTitle,
      if (sharedPostBody != null) 'sharedPostBody': sharedPostBody,
      if (sharedPostImageUrl != null) 'sharedPostImageUrl': sharedPostImageUrl,
      if (sharedPostVideoThumbnail != null)
        'sharedPostVideoThumbnail': sharedPostVideoThumbnail,
      if (sharedPostAuthorUsername != null)
        'sharedPostAuthorUsername': sharedPostAuthorUsername,
    };
  }
}

class ConversationModel {
  final String id;
  final List<String> participants;
  final Map<String, dynamic> participantInfo;
  final String lastMessage;
  final String lastMessageType;
  final DateTime? lastMessageAt;
  final String lastSenderId;
  final Map<String, dynamic> unreadCount;
  final String status; // 'active' | 'pending' | 'declined'
  final String? requestedBy;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.participantInfo,
    required this.lastMessage,
    required this.lastMessageType,
    this.lastMessageAt,
    required this.lastSenderId,
    required this.unreadCount,
    this.status = 'active',
    this.requestedBy,
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ConversationModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantInfo: Map<String, dynamic>.from(data['participantInfo'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageType: data['lastMessageType'] ?? 'text',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderId: data['lastSenderId'] ?? '',
      unreadCount: Map<String, dynamic>.from(data['unreadCount'] ?? {}),
      status: data['status'] ?? 'active',
      requestedBy: data['requestedBy'],
    );
  }

  bool get isPending => status == 'pending';

  /// True if [myUid] is the one who sent the original request (so the UI
  /// should show "Request sent" rather than "Accept / Decline").
  bool isMyRequest(String myUid) => isPending && requestedBy == myUid;

  /// Returns the other participant's uid relative to [myUid]
  String otherUid(String myUid) {
    return participants.firstWhere((id) => id != myUid, orElse: () => '');
  }

  String otherName(String myUid) {
    final uid = otherUid(myUid);
    return participantInfo[uid]?['name'] ?? 'User';
  }

  String? otherAvatar(String myUid) {
    final uid = otherUid(myUid);
    return participantInfo[uid]?['avatar'];
  }

  int unreadFor(String myUid) {
    final val = unreadCount[myUid];
    if (val is int) return val;
    return 0;
  }
}

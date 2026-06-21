import 'package:cloud_firestore/cloud_firestore.dart';

/// The type of content a post represents.
enum PostType { text, question, helpRequest, achievement, image, video }

/// Represents a single feed item (post, question, help request, etc.)
class Post {
  final String id;
  final String authorId; // FIXED: Brought directly into the class core schema
  final String authorName;
  final String authorUsername;
  final String? authorAvatarUrl;
  final PostType type;
  final String content;
  final String? imageUrl; // Serves as the storage asset URL for both Images and Videos
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final bool isSaved;
  final DateTime createdAt;
  static const String typeHelpRequest = 'helpRequest';
  // Help-request specific
  final int? rewardKarma;

  const Post({
    required this.id,
    required this.authorId, // FIXED: Required initialization field
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.type,
    required this.content,
    this.imageUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    required this.createdAt,
    this.rewardKarma,
  });

  /// Factory constructor to cleanly deserialize incoming Cloud Firestore documents
  factory Post.fromFirestore(DocumentSnapshot doc, String currentUid) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final List likedBy = data['likedBy'] ?? [];
    final List savedBy = data['savedBy'] ?? [];
    
    // Parse Date
    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    }

    // Robust Type Parsing: Handles both "helpRequest" and "PostType.helpRequest"
    String rawType = (data['type'] ?? 'text').toString();
    if (rawType.contains('.')) rawType = rawType.split('.').last;

    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      authorUsername: data['authorUsername'] ?? '@user',
      authorAvatarUrl: data['authorAvatarUrl'] ?? data['authorAvatar'],
      type: PostType.values.asNameMap()[rawType] ?? PostType.text,
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'] ?? data['mediaUrl'],
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      isLiked: likedBy.contains(currentUid),
      isSaved: savedBy.contains(currentUid),
      createdAt: parsedDate,
      rewardKarma: data['karmaReward'] ?? data['rewardKarma'],
    );
  }
}
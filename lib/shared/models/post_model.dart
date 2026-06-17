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
    
    // Safely extract Firestore Timestamp and convert to native Dart DateTime
    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    }

    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '', // FIXED: Maps cleanly to the core schema field
      authorName: data['authorName'] ?? 'Anonymous',
      authorUsername: data['authorUsername'] ?? '@user',
      authorAvatarUrl: data['authorAvatarUrl'] ?? data['authorAvatar'], // Cross-compat fallback
      type: PostType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => PostType.text,
      ),
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'] ?? data['mediaUrl'], // Cross-compat fallback
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      isLiked: likedBy.contains(currentUid),
      isSaved: savedBy.contains(currentUid),
      createdAt: parsedDate,
      rewardKarma: data['karmaReward'] ?? data['rewardKarma'],
    );
  }

  Post copyWith({
    int? likeCount,
    int? commentCount,
    int? shareCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return Post(
      id: id,
      authorId: authorId, // FIXED: Maintained immutable tracking copy
      authorName: authorName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      type: type,
      content: content,
      imageUrl: imageUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt,
      rewardKarma: rewardKarma,
    );
  }

  /// Sample posts for UI development before backend integration.
  static List<Post> samples() {
    final now = DateTime.now();
    return [
      Post(
        id: 'p1',
        authorId: 'u_mock1',
        authorName: 'Aditi Rao',
        authorUsername: '@aditi.codes',
        type: PostType.text,
        content: 'Finally got my Flutter app to build for Windows after fixing the MSVC toolchain issue. Feels great!',
        likeCount: 24,
        commentCount: 5,
        shareCount: 2,
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      Post(
        id: 'p2',
        authorId: 'u_mock2',
        authorName: 'Rohan Mehta',
        authorUsername: '@rohan.m',
        type: PostType.question,
        content: 'How do I scan ESP32 channels for nRF24L01 sniffing without missing packets? Any tips on hop timing?',
        likeCount: 8,
        commentCount: 11,
        shareCount: 0,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'p3',
        authorId: 'u_mock3',
        authorName: 'Sneha Kapoor',
        authorUsername: '@sneha.k',
        type: PostType.helpRequest,
        content: 'Need help debugging a PyQt5 + Oracle XE connection issue with PyInstaller builds. Works in dev but fails when packaged.',
        likeCount: 3,
        commentCount: 2,
        shareCount: 1,
        createdAt: now.subtract(const Duration(hours: 5)),
        rewardKarma: 20,
      ),
      Post(
        id: 'p4',
        authorId: 'u_mock4',
        authorName: 'Vikram Singh',
        authorUsername: '@vikram.s',
        type: PostType.achievement,
        content: 'Just crossed 1000 Karma points on INTERA! Thanks to everyone who upvoted my answers 🎉',
        likeCount: 56,
        commentCount: 9,
        shareCount: 4,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

/// The type of content a post represents.
enum PostType { text, question, helpRequest, achievement, image, video }

/// Represents a single feed item (post, question, help request, etc.)
class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String? authorAvatarUrl;
  final PostType type;
  final String title;   // ← NEW: short headline shown on the card
  final String body;    // ← NEW: longer description / caption
  final String content; // kept for backward-compat (= "$title\n$body" on write)
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final bool isSaved;
  final DateTime createdAt;
  static const String typeHelpRequest = 'helpRequest';
  final int? rewardKarma;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.type,
    required this.title,
    required this.body,
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

  factory Post.fromFirestore(DocumentSnapshot doc, String currentUid) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final List likedBy = data['likedBy'] ?? [];
    final List savedBy = data['savedBy'] ?? [];

    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    }

    String rawType = (data['type'] ?? 'text').toString();
    if (rawType.contains('.')) rawType = rawType.split('.').last;

    // ── Title / body resolution ──────────────────────────────────────────
    // New docs store 'title' + 'body' separately.
    // Old docs only have 'content' — split on first newline as fallback.
    final String rawContent = data['content'] ?? '';
    final String resolvedTitle = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : rawContent.contains('\n')
            ? rawContent.split('\n').first.trim()
            : rawContent.trim();
    final String resolvedBody = (data['body'] as String?)?.trim().isNotEmpty == true
        ? data['body'] as String
        : rawContent.contains('\n')
            ? rawContent.substring(rawContent.indexOf('\n') + 1).trim()
            : '';

    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      authorUsername: data['authorUsername'] ?? '@user',
      authorAvatarUrl: data['authorAvatarUrl'] ?? data['authorAvatar'],
      type: PostType.values.asNameMap()[rawType] ?? PostType.text,
      title: resolvedTitle,
      body: resolvedBody,
      content: rawContent,
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

  /// Call this when writing a new post to Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorUsername': authorUsername,
      if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
      'type': type.name,
      'title': title,
      'body': body,
      'content': '$title\n$body', // legacy fallback field
      if (imageUrl != null) 'imageUrl': imageUrl,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'likedBy': [],
      'savedBy': [],
      'createdAt': FieldValue.serverTimestamp(),
      if (rewardKarma != null) 'rewardKarma': rewardKarma,
    };
  }
}
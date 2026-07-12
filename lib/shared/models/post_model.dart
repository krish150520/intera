import 'package:cloud_firestore/cloud_firestore.dart';

/// The type of content a post represents.
enum PostType { text, question, helpRequest, achievement, image, video, poll }

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
  final List<String> tags;
  final int beautyCount;
  final int artCount;
  final int funnyCount;
  final Map<String, String> reactions;
  final DateTime createdAt;
  static const String typeHelpRequest = 'helpRequest';
  final int? rewardKarma;
  final String? communityId;
  final String? videoThumbnailUrl;
  final String? audioId;
  final String? audioTitle;
  final String? audioAuthorId;
  final String? audioUrl;

  // Poll fields
  final List<String>? pollOptions;
  final Map<String, int>? pollVotes;
  final List<String>? pollVotedBy;
  final int? totalVotes;
  final DateTime? pollExpiresAt;

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
    this.tags = const [],
    this.beautyCount = 0,
    this.artCount = 0,
    this.funnyCount = 0,
    this.reactions = const {},
    required this.createdAt,
    this.rewardKarma,
    this.communityId,
    this.videoThumbnailUrl,
    this.audioId,
    this.audioTitle,
    this.audioAuthorId,
    this.audioUrl,
    this.pollOptions,
    this.pollVotes,
    this.pollVotedBy,
    this.totalVotes,
    this.pollExpiresAt,
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
      tags: List<String>.from(data['tags'] ?? []),
      beautyCount: (data['beautyCount'] as num?)?.toInt() ?? 0,
      artCount: (data['artCount'] as num?)?.toInt() ?? 0,
      funnyCount: (data['funnyCount'] as num?)?.toInt() ?? 0,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      createdAt: parsedDate,
      rewardKarma: data['karmaReward'] ?? data['rewardKarma'],
      communityId: data['communityId'] as String?,
      videoThumbnailUrl: data['videoThumbnailUrl'] as String?,
      audioId: data['audioId'] as String?,
      audioTitle: data['audioTitle'] as String?,
      audioAuthorId: data['audioAuthorId'] as String?,
      audioUrl: data['audioUrl'] as String?,
      pollOptions: data['pollOptions'] != null
          ? List<String>.from(data['pollOptions'])
          : null,
      pollVotes: data['pollVotes'] != null
          ? Map<String, int>.from(
              (data['pollVotes'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : null,
      pollVotedBy: data['pollVotedBy'] != null
          ? List<String>.from(data['pollVotedBy'])
          : null,
      totalVotes: (data['totalVotes'] as num?)?.toInt(),
      pollExpiresAt: (data['pollExpiresAt'] as Timestamp?)?.toDate(),
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
      'content': '$title\n$body',
      if (imageUrl != null) 'imageUrl': imageUrl,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'likedBy': [],
      'savedBy': [],
      'tags': tags,
      'beautyCount': beautyCount,
      'artCount': artCount,
      'funnyCount': funnyCount,
      'reactions': reactions,
      'createdAt': FieldValue.serverTimestamp(),
      if (rewardKarma != null) 'rewardKarma': rewardKarma,
      if (communityId != null) 'communityId': communityId,
      if (videoThumbnailUrl != null) 'videoThumbnailUrl': videoThumbnailUrl,
      if (audioId != null) 'audioId': audioId,
      if (audioTitle != null) 'audioTitle': audioTitle,
      if (audioAuthorId != null) 'audioAuthorId': audioAuthorId,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (pollOptions != null) 'pollOptions': pollOptions,
      if (pollVotes != null) 'pollVotes': pollVotes,
      if (pollVotedBy != null) 'pollVotedBy': pollVotedBy,
      if (totalVotes != null) 'totalVotes': totalVotes,
      if (pollExpiresAt != null) 'pollExpiresAt': Timestamp.fromDate(pollExpiresAt!),
    };
  }
}

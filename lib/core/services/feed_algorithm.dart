import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/post_model.dart';

/// All available interest tags users & post authors can choose from.
const List<String> kAllInterestTags = [
  'tech', 'art', 'gaming', 'health', 'education',
  'music', 'food', 'travel', 'sports', 'science', 'fashion', 'business',
];

/// Holds the signals needed to score posts for a specific user.
class UserFeedProfile {
  final String uid;
  final Set<String> followingIds;
  final Set<String> likedPostIds;
  final Set<String> savedPostIds;
  final Set<String> interestTags;
  final Set<String> seenPostIds;

  const UserFeedProfile({
    required this.uid,
    required this.followingIds,
    required this.likedPostIds,
    required this.savedPostIds,
    required this.interestTags,
    required this.seenPostIds,
  });

  static UserFeedProfile empty(String uid) => UserFeedProfile(
        uid: uid,
        followingIds: {},
        likedPostIds: {},
        savedPostIds: {},
        interestTags: {},
        seenPostIds: {},
      );
}

class _ScoredPost {
  final Post post;
  final double score;
  const _ScoredPost(this.post, this.score);
}

/// Client-side feed recommendation engine.
class FeedAlgorithm {
  static const double _wFollowing = 40;
  static const double _wLiked     = 30;
  static const double _wSaved     = 25;
  static const double _wTagMatch  = 20;
  static const double _wLikes     = 15;
  static const double _wComments  = 10;
  static const double _wDecay     = 25;
  static const double _wSeen      = 50;

  /// Ranks [posts] for the given [profile].
  /// Following posts grouped first, then discovery posts.
  static List<Post> rankPosts(List<Post> posts, UserFeedProfile profile) {
    final followingPosts = <_ScoredPost>[];
    final discoveryPosts = <_ScoredPost>[];

    for (final post in posts) {
      final sp = _ScoredPost(post, _score(post, profile));
      if (profile.followingIds.contains(post.authorId) || post.authorId == profile.uid) {
        followingPosts.add(sp);
      } else {
        discoveryPosts.add(sp);
      }
    }

    followingPosts.sort((a, b) => b.score.compareTo(a.score));
    discoveryPosts.sort((a, b) => b.score.compareTo(a.score));

    return [
      ...followingPosts.map((sp) => sp.post),
      ...discoveryPosts.map((sp) => sp.post),
    ];
  }

  /// Returns index where discovery posts start in [rankPosts] output.
  static int discoveryStartIndex(List<Post> posts, UserFeedProfile profile) {
    return posts
        .where((p) => profile.followingIds.contains(p.authorId) || p.authorId == profile.uid)
        .length;
  }

  /// Builds a [UserFeedProfile] by reading Firestore signals for [uid].
  static Future<UserFeedProfile> buildUserProfile(String uid) async {
    if (uid.isEmpty) return UserFeedProfile.empty(uid);
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db.collection('users').doc(uid).collection('following').get(),
        db.collection('posts').where('likedBy', arrayContains: uid).limit(100).get(),
        db.collection('posts').where('savedBy', arrayContains: uid).limit(100).get(),
        db.collection('users').doc(uid).get(),
      ]);

      final followingSnap = results[0] as QuerySnapshot;
      final likedSnap     = results[1] as QuerySnapshot;
      final savedSnap     = results[2] as QuerySnapshot;
      final userDoc       = results[3] as DocumentSnapshot;

      final followingIds = followingSnap.docs.map((d) => d.id).toSet();
      final likedPostIds = likedSnap.docs.map((d) => d.id).toSet();
      final savedPostIds = savedSnap.docs.map((d) => d.id).toSet();

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final rawTags = (userData['hobbies'] as List<dynamic>?)?.cast<String>() ??
          (userData['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final interestTags = rawTags
          .map((t) => t.toLowerCase().trim())
          .where((t) => t.isNotEmpty)
          .toSet();

      final rawSeen = (userData['seenPosts'] as List<dynamic>?)?.cast<String>() ?? [];
      final seenPostIds = rawSeen.toSet();

      return UserFeedProfile(
        uid: uid,
        followingIds: followingIds,
        likedPostIds: likedPostIds,
        savedPostIds: savedPostIds,
        interestTags: interestTags,
        seenPostIds: seenPostIds,
      );
    } catch (_) {
      return UserFeedProfile.empty(uid);
    }
  }

  /// Records that [uid] has seen [postId]. Caps list at 50.
  static Future<void> markPostSeen(String uid, String postId) async {
    if (uid.isEmpty || postId.isEmpty) return;
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await ref.get();
      final data = doc.data() ?? {};
      final current = List<String>.from((data['seenPosts'] as List<dynamic>?) ?? []);
      if (current.contains(postId)) return;
      current.add(postId);
      final trimmed = current.length > 50 ? current.sublist(current.length - 50) : current;
      await ref.update({'seenPosts': trimmed});
    } catch (_) {}
  }

  static double _score(Post post, UserFeedProfile profile) {
    // Baseline so posts with no tags / no signals still appear
    double s = 5;

    if (profile.followingIds.contains(post.authorId)) s += _wFollowing;
    if (profile.likedPostIds.contains(post.id)) s += _wLiked;
    if (profile.savedPostIds.contains(post.id)) s += _wSaved;

    // Tags are purely additive — posts without tags are NOT penalised
    if (post.tags.isNotEmpty) {
      final postTags = post.tags.map((t) => t.toLowerCase()).toSet();
      final matches  = postTags.intersection(profile.interestTags).length;
      s += _wTagMatch * matches.clamp(0, 3);
    }

    s += (post.likeCount / 10).clamp(0, _wLikes);
    s += (post.commentCount / 5).clamp(0, _wComments);

    final ageHours = DateTime.now().difference(post.createdAt).inHours.toDouble();
    s -= (ageHours / (7 * 24)).clamp(0.0, 1.0) * _wDecay;

    if (profile.seenPostIds.contains(post.id)) s -= _wSeen;
    return s;
  }
}

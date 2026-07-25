import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../profile/screens/my_profile_screen.dart';
import '../../../shared/widgets/shimmer.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../core/services/feed_algorithm.dart';
import '../widgets/pinterest_post_card.dart';

class PinterestFeedScreen extends StatefulWidget {
  const PinterestFeedScreen({super.key});

  @override
  State<PinterestFeedScreen> createState() => _PinterestFeedScreenState();
}

class _PinterestFeedScreenState extends State<PinterestFeedScreen> {
  late final Stream<QuerySnapshot> _postsStream;
  UserFeedProfile _feedProfile = UserFeedProfile.empty('');
  String _activeTab = 'explore'; // 'explore' | 'leaderboard'

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  late AppColorsExtension _c;

  @override
  void initState() {
    super.initState();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();

    _loadProfileInBackground();
  }

  Future<void> _loadProfileInBackground() async {
    try {
      final profile = await FeedAlgorithm.buildUserProfile(_myUid)
          .timeout(const Duration(seconds: 6),
              onTimeout: () => UserFeedProfile.empty(_myUid));
      if (mounted) setState(() => _feedProfile = profile);
    } catch (_) {}
  }

  Future<void> _refreshData() async {
    await _loadProfileInBackground();
  }

  @override
  Widget build(BuildContext context) {
    _c = context.appColors;

    return Scaffold(
      backgroundColor: _c.bg,
      appBar: AppBar(
        backgroundColor: _c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Discover',
          style: TextStyle(
            color: _c.primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyProfileScreen())),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_myUid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String? avatarUrl;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    avatarUrl = data?['profileImageUrl'] ?? data?['photoURL'];
                  }
                  return Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _c.border.withValues(alpha: 0.6), width: 0.8),
                    ),
                    child: ClipOval(
                      child: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? Image.network(avatarUrl, fit: BoxFit.cover)
                          : Container(
                              color: _c.surface,
                              child: Icon(Icons.person_rounded,
                                  color: _c.textPrimary, size: 18),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTopTab('explore', 'Explore 🔍'),
                _buildTopTab('leaderboard', 'Leaderboard 🏆'),
              ],
            ),
          ),
          Expanded(
            child: _activeTab == 'explore'
                ? StreamBuilder<QuerySnapshot>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildError(snapshot.error.toString());
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildPinterestGridShimmer();
                }

                final docs = snapshot.data?.docs ?? [];

                // 1. Map to Post models and filter out posts created inside communities, and only select image/video posts
                final List<Post> mediaPosts = docs
                    .map((d) {
                      final post = Post.fromFirestore(d, _myUid);
                      final data = d.data() as Map<String, dynamic>? ?? {};
                      final visibility = data['visibility'] ?? 'Public';
                      final scheduledAt = data['scheduledAt'] as Timestamp?;
                      return _FeedFilterWrapper(post: post, visibility: visibility, scheduledAt: scheduledAt);
                    })
                    .where((w) {
                      if (w.post.communityId != null && w.post.communityId!.isNotEmpty) return false;
                      if (w.post.type != PostType.image && w.post.type != PostType.video) return false;
                      
                      if (w.scheduledAt != null && w.scheduledAt!.toDate().isAfter(DateTime.now())) {
                        if (w.post.authorId != _myUid) return false;
                      }
                      if (w.visibility == 'Only Me' && w.post.authorId != _myUid) return false;
                      if (w.visibility == 'Followers' && 
                          w.post.authorId != _myUid && 
                          !_feedProfile.followingIds.contains(w.post.authorId)) {
                        return false;
                      }
                      return true;
                    })
                    .map((w) => w.post)
                    .toList();

                // 2. Rank using recommendation score (with user interest boosting)
                final List<Post> filteredPosts = FeedAlgorithm.rankPosts(mediaPosts, _feedProfile);

                if (filteredPosts.isEmpty) {
                  return RefreshIndicator(
                    color: _c.primary,
                    backgroundColor: _c.surface,
                    onRefresh: _refreshData,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.explore_off_rounded,
                                  size: 48, color: _c.textDim),
                              const SizedBox(height: 16),
                              Text('No media posts found',
                                  style: TextStyle(
                                      color: _c.textHi,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18)),
                              const SizedBox(height: 6),
                              Text(
                                  'Discover new video & image posts here.',
                                  style: TextStyle(
                                      color: _c.textDim, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: _c.primary,
                  backgroundColor: _c.surface,
                  onRefresh: _refreshData,
                  child: _buildPinterestGrid(filteredPosts),
                );
              },
            )
          : _buildLeaderboardView(),
          ),
        ],
      ),
    );
  }

  Widget _buildPinterestGridShimmer() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StaggeredCardShimmer(height: 220),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StaggeredCardShimmer(height: 180),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StaggeredCardShimmer(height: 250),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StaggeredCardShimmer(height: 170),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StaggeredCardShimmer(height: 240),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StaggeredCardShimmer(height: 200),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinterestGrid(List<Post> posts) {
    final leftColumn = <Post>[];
    final rightColumn = <Post>[];
    for (int i = 0; i < posts.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(posts[i]);
      } else {
        rightColumn.add(posts[i]);
      }
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftColumn
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PinterestPostCard(post: p),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: rightColumn
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PinterestPostCard(post: p),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: _c.textDim, size: 36),
          const SizedBox(height: 10),
          Text('Could not load feed',
              style: TextStyle(color: _c.textHi, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(msg, style: TextStyle(color: _c.textDim, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTopTab(String tab, String label) {
    final selected = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _c.textHi : _c.textMuted,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _leaderboardCategory = 'beauty'; // 'beauty' | 'art' | 'funny'
  String _leaderboardTimeframe = 'allTime'; // 'month' | 'year' | 'allTime'

  String _getFirestoreField() {
    switch (_leaderboardCategory) {
      case 'beauty':
        return _leaderboardTimeframe == 'month'
            ? 'beautyPointsThisMonth'
            : _leaderboardTimeframe == 'year'
                ? 'beautyPointsThisYear'
                : 'beautyPoints';
      case 'art':
        return _leaderboardTimeframe == 'month'
            ? 'artPointsThisMonth'
            : _leaderboardTimeframe == 'year'
                ? 'artPointsThisYear'
                : 'artPoints';
      case 'funny':
        return _leaderboardTimeframe == 'month'
            ? 'funnyPointsThisMonth'
            : _leaderboardTimeframe == 'year'
                ? 'funnyPointsThisYear'
                : 'funnyPoints';
      default:
        return 'beautyPoints';
    }
  }

  Color _getCategoryColor() {
    switch (_leaderboardCategory) {
      case 'beauty':
        return Colors.pinkAccent;
      case 'art':
        return Colors.orangeAccent;
      case 'funny':
        return Colors.amber;
      default:
        return _c.primary;
    }
  }

  Widget _buildLeaderboardView() {
    final orderByField = _getFirestoreField();
    final pointColor = _getCategoryColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildCategoryPill('beauty', '💖 Radiance'),
              const SizedBox(width: 8),
              _buildCategoryPill('art', '🎨 Art'),
              const SizedBox(width: 8),
              _buildCategoryPill('funny', '😂 Funny'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: _c.field,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _c.border, width: 0.8),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                _buildTimeframeBtn('month', 'Monthly'),
                _buildTimeframeBtn('year', 'Yearly'),
                _buildTimeframeBtn('allTime', 'All-Time'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy(orderByField, descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: _c.textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final pts = (data[orderByField] as num?)?.toInt() ?? 0;
                return pts > 0;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 44, color: _c.textDim),
                      const SizedBox(height: 8),
                      Text(
                        'No points registered for this filter.',
                        style: TextStyle(color: _c.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final userDoc = filteredDocs[index];
                  final data = userDoc.data() as Map<String, dynamic>? ?? {};
                  final name = data['name'] ?? 'User';
                  final username = data['username'] ?? 'user';
                  final avatarUrl = data['profileImageUrl'] ?? data['photoURL'] ?? '';
                  final pts = (data[orderByField] as num?)?.toInt() ?? 0;
                  final userId = userDoc.id;

                  final isTop3 = index < 3;
                  final Color rankBgColor = switch (index) {
                    0 => Colors.amber,
                    1 => Colors.grey.shade400,
                    2 => const Color(0xFFCD7F32),
                    _ => Colors.transparent,
                  };

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _c.field.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _c.border.withValues(alpha: 0.5), width: 0.8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: rankBgColor,
                            shape: BoxShape.circle,
                            border: isTop3 ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1) : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isTop3 ? Colors.black87 : _c.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CustomAvatar(
                          name: name,
                          imageUrl: avatarUrl,
                          userId: userId,
                          radius: 16,
                          clickable: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _c.textHi,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '@$username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _c.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: pointColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: pointColor.withValues(alpha: 0.25), width: 0.8),
                          ),
                          child: Text(
                            '$pts',
                            style: TextStyle(
                              color: pointColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String cat, String label) {
    final selected = _leaderboardCategory == cat;
    final catColor = _getCategoryColor();

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _leaderboardCategory = cat),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? catColor.withValues(alpha: 0.15) : _c.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? catColor : _c.border,
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? catColor : _c.textMuted,
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeBtn(String tf, String label) {
    final selected = _leaderboardTimeframe == tf;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _leaderboardTimeframe = tf),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? _c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _c.textHi : _c.textMuted,
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feed filter wrapper helper ────────────────────────────────────────────────

class _FeedFilterWrapper {
  final Post post;
  final String visibility;
  final Timestamp? scheduledAt;
  const _FeedFilterWrapper({
    required this.post,
    required this.visibility,
    required this.scheduledAt,
  });
}

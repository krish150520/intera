import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../profile/screens/my_profile_screen.dart';
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildError(snapshot.error.toString());
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: _c.primary,
                      strokeWidth: 2,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // 1. Map to Post models and filter out posts created inside communities, and only select image/video posts
                final List<Post> mediaPosts = docs
                    .map((d) => Post.fromFirestore(d, _myUid))
                    .where((p) => p.communityId == null || p.communityId!.isEmpty)
                    .where((p) => p.type == PostType.image || p.type == PostType.video)
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
}
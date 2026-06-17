import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intera/features/home/widgets/post_card.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../home/screens/post_detail_screen.dart';
import '../../videos/screens/community_detail_screen.dart';

/// Screen 7: Search Screen
/// Lets users query dynamic prefix matches for Users, Posts, Videos, and Communities.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _bg       = Color(0xFFF5F3FF);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _muted    = Color(0xFFEDE9FF);
  static const Color _border   = Color(0xFFE9E4FF);
  static const Color _primary  = Color(0xFF7C3AED);
  static const Color _textHi   = Color(0xFF2D1B69);
  static const Color _textDim  = Color(0xFFA89FCC);
  static const Color _inputBg  = Color(0xFFEDE9FF);

  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String value) {
    String cleanQuery = value.trim().toLowerCase();
    if (cleanQuery.startsWith('@')) cleanQuery = cleanQuery.substring(1);
    setState(() => _searchQuery = cleanQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        titleSpacing: 16,
        title: _buildSearchBar(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _buildTabBar(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UserResultsList(searchQuery: _searchQuery),
          _PostResultsList(searchQuery: _searchQuery, searchVideos: false),
          _PostResultsList(searchQuery: _searchQuery, searchVideos: true),
          _CommunityResultsList(searchQuery: _searchQuery),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: _onSearchSubmitted,
        style: const TextStyle(color: _textHi, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search people, posts, communities…',
          hintStyle: const TextStyle(color: _textDim, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textDim),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close_rounded, size: 16, color: _textDim),
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: _inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: _primary,
      unselectedLabelColor: _textDim,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      indicator: BoxDecoration(
        color: _muted,
        borderRadius: BorderRadius.circular(20),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      dividerColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tabs: const [
        Tab(text: 'Users'),
        Tab(text: 'Posts'),
        Tab(text: 'Videos'),
        Tab(text: 'Communities'),
      ],
    );
  }
}

// ── Tab 1: Users ──────────────────────────────────────────────────────────────
class _UserResultsList extends StatelessWidget {
  static const Color _primary  = Color(0xFF7C3AED);
  static const Color _border   = Color(0xFFE9E4FF);
  static const Color _textHi   = Color(0xFF2D1B69);
  static const Color _textDim  = Color(0xFFA89FCC);

  final String searchQuery;
  const _UserResultsList({required this.searchQuery});

  // FIXED: Fully synchronized to write parallel index mappings to followerIds/followingIds collections 
  void _toggleFollow(String targetUid, bool isFollowing) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final currentUserDoc = FirebaseFirestore.instance.collection('users').doc(currentUid);
    final targetUserDoc  = FirebaseFirestore.instance.collection('users').doc(targetUid);

    if (isFollowing) {
      await currentUserDoc.update({
        'followingCount': FieldValue.increment(-1),
        'followingIds': FieldValue.arrayRemove([targetUid]),
      });
      await targetUserDoc.update({
        'followersCount': FieldValue.increment(-1),
        'followerIds': FieldValue.arrayRemove([currentUid]),
      });
    } else {
      await currentUserDoc.update({
        'followingCount': FieldValue.increment(1),
        'followingIds': FieldValue.arrayUnion([targetUid]),
      });
      await targetUserDoc.update({
        'followersCount': FieldValue.increment(1),
        'followerIds': FieldValue.arrayUnion([currentUid]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      return const _EmptyResultsPlaceholder(label: 'Type above to explore community members');
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('username')
          .startAt([searchQuery])
          .endAt([searchQuery + '\uF8FF'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Query Index Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2));
        }

        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((d) => d.id != currentUid).toList();

        if (filtered.isEmpty) return const _EmptyResultsPlaceholder(label: 'No users found matching query');

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final docId = filtered[index].id;
            final data  = filtered[index].data() as Map<String, dynamic>;
            final String name      = data['name']      ?? 'User';
            final String username  = data['username']  ?? 'user';
            final String avatarUrl = data['avatarUrl'] ?? '';
            
            // FIXED: Reads your newly synchronized followerIds collection map arrays natively
            final List followerIds = data['followerIds'] ?? [];
            final bool isFollowing = followerIds.contains(currentUid);

            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: docId, userName: name, userAvatar: avatarUrl),
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    CustomAvatar(name: name, imageUrl: avatarUrl, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: _textHi, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            username.startsWith('@') ? username : '@$username',
                            style: const TextStyle(color: _textDim, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _toggleFollow(docId, isFollowing),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: isFollowing ? Colors.transparent : _primary,
                          borderRadius: BorderRadius.circular(20),
                          border: isFollowing ? Border.all(color: _border) : null,
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: isFollowing ? _textDim : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab 2 & 3: Posts & Videos ─────────────────────────────────────────────────
class _PostResultsList extends StatelessWidget {
  static const Color _primary = Color(0xFF7C3AED);

  final String searchQuery;
  final bool searchVideos;
  const _PostResultsList({required this.searchQuery, required this.searchVideos});

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      return _EmptyResultsPlaceholder(
        label: searchVideos ? 'Search for shared community clips' : 'Look up questions and posts',
      );
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('content')
          .startAt([searchQuery])
          .endAt([searchQuery + '\uF8FF'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error rendering feeds: ${snapshot.error}', textAlign: TextAlign.center),
          ));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2));
        }

        final docs = snapshot.data?.docs ?? [];
        final List<Post> parsedPosts = [];

        for (var doc in docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            final String postType = data['type'] ?? 'text';
            if (searchVideos && postType != 'video') continue;
            if (!searchVideos && postType == 'video') continue;
            parsedPosts.add(Post.fromFirestore(doc, currentUid));
          } catch (e) {
            debugPrint('Skipped unparseable post document [${doc.id}]: $e');
          }
        }

        if (parsedPosts.isEmpty) {
          return _EmptyResultsPlaceholder(
            label: searchVideos ? 'No video posts located' : 'No updates located',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: parsedPosts.length,
          itemBuilder: (context, index) {
            final postItem = parsedPosts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                post: postItem,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PostDetailScreen(post: postItem)),
                ),
                onLike: () {
                  final docRef = FirebaseFirestore.instance.collection('posts').doc(postItem.id);
                  if (postItem.isLiked) {
                    docRef.update({'likeCount': FieldValue.increment(-1), 'likedBy': FieldValue.arrayRemove([currentUid])});
                  } else {
                    docRef.update({'likeCount': FieldValue.increment(1), 'likedBy': FieldValue.arrayUnion([currentUid])});
                  }
                },
                onComment: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PostDetailScreen(post: postItem)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab 4: Communities ────────────────────────────────────────────────────────
class _CommunityResultsList extends StatelessWidget {
  static const Color _primary = Color(0xFF7C3AED);
  static const Color _muted   = Color(0xFFEDE9FF);
  static const Color _border  = Color(0xFFE9E4FF);
  static const Color _textHi  = Color(0xFF2D1B69);
  static const Color _textDim = Color(0xFFA89FCC);

  final String searchQuery;
  const _CommunityResultsList({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      return const _EmptyResultsPlaceholder(label: 'Discover sub-hubs and working spaces');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .orderBy('searchName')
          .startAt([searchQuery])
          .endAt([searchQuery + '\uF8FF'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyResultsPlaceholder(label: 'No communities match your parameters');

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc   = docs[index];
            final data  = doc.data() as Map<String, dynamic>;
            final String title     = data['name']        ?? 'Community Hub';
            final String desc      = data['description'] ?? 'No bio statement provided.';
            final String avatarUrl = data['avatarUrl']   ?? '';
            final int    count     = data['memberCount'] ?? 1;

            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(
                  communityId: doc.id,
                  communityName: title,
                  communityDescription: desc,
                ),
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _muted,
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              title.isNotEmpty ? title[0].toUpperCase() : 'C',
                              style: const TextStyle(color: _primary, fontWeight: FontWeight.w700, fontSize: 15),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: _textHi, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _textDim, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _muted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count members',
                        style: const TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyResultsPlaceholder extends StatelessWidget {
  static const Color _primary = Color(0xFF7C3AED);
  static const Color _muted   = Color(0xFFEDE9FF);
  static const Color _textDim = Color(0xFFA89FCC);

  final String label;
  const _EmptyResultsPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: _muted, shape: BoxShape.circle),
            child: const Icon(Icons.search_rounded, color: _primary, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textDim, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
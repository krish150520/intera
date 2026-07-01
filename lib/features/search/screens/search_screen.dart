import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intera/features/home/widgets/post_card.dart';
import '../../../core/theme/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../home/screens/post_detail_screen.dart';
import '../../videos/screens/community_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        titleSpacing: 16,
        title: _buildSearchBar(c),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildTabBar(c),
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

  Widget _buildSearchBar(_ThemeColors c) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        autofocus: false,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: c.textHi, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search people, posts, communities…',
          hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.textMuted),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: c.field,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(_ThemeColors c) {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: c.primary,
      unselectedLabelColor: c.textMuted,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      indicator: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.chipBorder),
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
  final String searchQuery;
  const _UserResultsList({required this.searchQuery});

  Future<void> _toggleFollow(BuildContext context, String targetUid, bool isFollowing) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final db = FirebaseFirestore.instance;
    final currentUserDoc = db.collection('users').doc(currentUid);
    final targetUserDoc  = db.collection('users').doc(targetUid);
    final batch = db.batch();
    if (isFollowing) {
      batch.delete(currentUserDoc.collection('following').doc(targetUid));
      batch.delete(targetUserDoc.collection('followers').doc(currentUid));
      batch.update(currentUserDoc, {'followingCount': FieldValue.increment(-1)});
      batch.update(targetUserDoc,  {'followersCount': FieldValue.increment(-1)});
    } else {
      batch.set(currentUserDoc.collection('following').doc(targetUid), {'createdAt': FieldValue.serverTimestamp()});
      batch.set(targetUserDoc.collection('followers').doc(currentUid), {'createdAt': FieldValue.serverTimestamp()});
      batch.update(currentUserDoc, {'followingCount': FieldValue.increment(1)});
      batch.update(targetUserDoc,  {'followersCount': FieldValue.increment(1)});
    }
    try {
      await batch.commit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors(context);
    if (searchQuery.isEmpty) {
      return _EmptyPlaceholder(icon: Icons.people_outline_rounded, label: 'Type to search community members');
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUid).collection('following').snapshots(),
      builder: (context, followingSnap) {
        final followingIds = followingSnap.data?.docs.map((d) => d.id).toSet() ?? <String>{};
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('users').limit(200).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2));
            }
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            final q = searchQuery.toLowerCase();
            final docs = (snapshot.data?.docs ?? []).where((doc) {
              if (doc.id == currentUid) return false;
              final data = doc.data() as Map<String, dynamic>;
              final name     = (data['name']     ?? '').toString().toLowerCase();
              final username = (data['username'] ?? '').toString().toLowerCase();
              return name.contains(q) || username.contains(q);
            }).toList();
            if (docs.isEmpty) return const _EmptyPlaceholder(icon: Icons.person_search_rounded, label: 'No users found');
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final docId = docs[i].id;
                final data  = docs[i].data() as Map<String, dynamic>;
                final String name      = data['name']      ?? 'User';
                final String username  = data['username']  ?? 'user';
                final String avatarUrl = data['avatarUrl'] ?? '';
                final bool isFollowing = followingIds.contains(docId);
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: docId, userName: name, userAvatar: avatarUrl),
                  )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(children: [
                      CustomAvatar(name: name, imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null, radius: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(color: c.textHi, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(username.startsWith('@') ? username : '@$username',
                              style: TextStyle(color: c.textMuted, fontSize: 12)),
                        ]),
                      ),
                      GestureDetector(
                        onTap: () => _toggleFollow(context, docId, isFollowing),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: isFollowing ? Colors.transparent : c.primary,
                            borderRadius: BorderRadius.circular(20),
                            border: isFollowing ? Border.all(color: c.border) : null,
                          ),
                          child: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: isFollowing ? c.textMuted : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Tab 2 & 3: Posts & Videos ─────────────────────────────────────────────────

class _PostResultsList extends StatelessWidget {
  final String searchQuery;
  final bool searchVideos;
  const _PostResultsList({required this.searchQuery, required this.searchVideos});

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors(context);
    if (searchQuery.isEmpty) {
      return _EmptyPlaceholder(
        icon: searchVideos ? Icons.videocam_outlined : Icons.article_outlined,
        label: searchVideos ? 'Search for video posts' : 'Search questions and posts',
      );
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(300).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2));
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final q = searchQuery.toLowerCase();
        final List<Post> posts = [];
        for (final doc in snapshot.data?.docs ?? []) {
          try {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final type = data['type'] ?? 'text';
            if (searchVideos && type != 'video') continue;
            if (!searchVideos && type == 'video') continue;
            final title      = (data['title']     ?? '').toString().toLowerCase();
            final body       = (data['body']       ?? '').toString().toLowerCase();
            final content    = (data['content']    ?? '').toString().toLowerCase();
            final authorName = (data['authorName'] ?? '').toString().toLowerCase();
            if (!title.contains(q) && !body.contains(q) && !content.contains(q) && !authorName.contains(q)) continue;
            posts.add(Post.fromFirestore(doc, currentUid));
          } catch (e) { debugPrint('Skipped post [${doc.id}]: $e'); }
        }
        if (posts.isEmpty) {
          return _EmptyPlaceholder(
            icon: searchVideos ? Icons.videocam_off_outlined : Icons.search_off_rounded,
            label: searchVideos ? 'No video posts found' : 'No posts found',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final post = posts[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                post: post,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
                onLike: () {
                  final ref = FirebaseFirestore.instance.collection('posts').doc(post.id);
                  if (post.isLiked) {
                    ref.update({'likeCount': FieldValue.increment(-1), 'likedBy': FieldValue.arrayRemove([currentUid])});
                  } else {
                    ref.update({'likeCount': FieldValue.increment(1),  'likedBy': FieldValue.arrayUnion([currentUid])});
                  }
                },
                onComment: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
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
  final String searchQuery;
  const _CommunityResultsList({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors(context);
    if (searchQuery.isEmpty) {
      return const _EmptyPlaceholder(icon: Icons.groups_outlined, label: 'Discover communities');
    }
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('communities').limit(200).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2));
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final q = searchQuery.toLowerCase();
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final desc = (data['description'] ?? '').toString().toLowerCase();
          return name.contains(q) || desc.contains(q);
        }).toList();
        if (docs.isEmpty) return const _EmptyPlaceholder(icon: Icons.group_off_outlined, label: 'No communities found');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final doc   = docs[i];
            final data  = doc.data() as Map<String, dynamic>;
            final String title     = data['name']        ?? 'Community';
            final String desc      = data['description'] ?? '';
            final String avatarUrl = data['avatarUrl']   ?? '';
            final int    count     = (data['memberCount'] as num?)?.toInt() ?? 1;
            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(communityId: doc.id, communityName: title, communityDescription: desc),
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: c.field,
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(title.isNotEmpty ? title[0].toUpperCase() : 'C',
                            style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 15))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: TextStyle(color: c.textHi, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 3),
                      if (desc.isNotEmpty)
                        Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textMuted, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(20)),
                    child: Text('$count members',
                        style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyPlaceholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: c.field, shape: BoxShape.circle),
          child: Icon(icon, color: c.primary, size: 26),
        ),
        const SizedBox(height: 14),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5)),
      ]),
    );
  }
}

// ── Theme resolver ────────────────────────────────────────────────────────────

class _ThemeColors {
  final BuildContext context;
  _ThemeColors(this.context);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get primary   => _dark ? AppColors.primaryLight   : AppColors.primary;
  Color get bg        => _dark ? AppColors.darkBg         : AppColors.lightBg;
  Color get surface   => _dark ? AppColors.darkSurface    : AppColors.lightSurface;
  Color get field     => _dark ? AppColors.darkField      : AppColors.lightField;
  Color get border    => _dark ? AppColors.darkBorder     : AppColors.lightBorder;
  Color get chipBorder=> _dark ? AppColors.darkChipBorder : AppColors.lightChipBorder;
  Color get textHi    => _dark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
  Color get textMuted => _dark ? AppColors.darkTextMuted     : AppColors.lightTextMuted;
  Color get textDim   => _dark ? AppColors.darkTextDim       : AppColors.lightTextDim;
  }
    

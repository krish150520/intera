import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intera/features/home/widgets/post_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../home/screens/post_detail_screen.dart';
import '../../videos/screens/community_detail_screen.dart';
import '../../../core/services/notification_service.dart';
import 'dart:ui';

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

  // ── Glass search bar ───────────────────────────────────────────────────────
  Widget _buildSearchBar(AppColorsExtension c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 38,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.6),
                width: 0.8,
              ),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: c.textHi, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search people, posts, communities…',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 16, color: c.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.close_rounded,
                            size: 14, color: c.textMuted),
                      )
                    : null,
                isDense: true,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Glass tab bar ──────────────────────────────────────────────────────────
  Widget _buildTabBar(AppColorsExtension c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = ['Users', 'Posts', 'Videos', 'Communities'];
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Row(
          children: List.generate(tabs.length, (i) {
            final selected = _tabController.index == i;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tabController.animateTo(i)),
                child: Container(
                  margin: EdgeInsets.only(right: i < tabs.length - 1 ? 4 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? c.primary
                        : Colors.white.withValues(
                            alpha: isDark ? 0.10 : 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : Colors.white.withValues(
                              alpha: isDark ? 0.18 : 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : c.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // Bare Column — no Scaffold, inherits sidebar glass background
    return Column(
      children: [
        _buildSearchBar(c),
        const SizedBox(height: 10),
        _buildTabBar(c),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UserResultsList(searchQuery: _searchQuery),
              _PostResultsList(searchQuery: _searchQuery, searchVideos: false),
              _PostResultsList(searchQuery: _searchQuery, searchVideos: true),
              _CommunityResultsList(searchQuery: _searchQuery),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Users ───────────────────────────────────────────────────────────────

class _UserResultsList extends StatelessWidget {
  final String searchQuery;
  const _UserResultsList({required this.searchQuery});

  Future<void> _toggleFollow(
      BuildContext context, String targetUid, bool isFollowing) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final db = FirebaseFirestore.instance;
    final currentUserDoc = db.collection('users').doc(currentUid);
    final targetUserDoc = db.collection('users').doc(targetUid);
    final batch = db.batch();
    if (isFollowing) {
      batch.delete(currentUserDoc.collection('following').doc(targetUid));
      batch.delete(targetUserDoc.collection('followers').doc(currentUid));
      batch.update(currentUserDoc, {'followingCount': FieldValue.increment(-1)});
      batch.update(targetUserDoc, {'followersCount': FieldValue.increment(-1)});
    } else {
      batch.set(currentUserDoc.collection('following').doc(targetUid),
          {'createdAt': FieldValue.serverTimestamp()});
      batch.set(targetUserDoc.collection('followers').doc(currentUid),
          {'createdAt': FieldValue.serverTimestamp()});
      batch.update(currentUserDoc, {'followingCount': FieldValue.increment(1)});
      batch.update(targetUserDoc, {'followersCount': FieldValue.increment(1)});
    }
    try {
      await batch.commit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not update follow status. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (searchQuery.isEmpty) {
      return _GlassEmptyPlaceholder(
          icon: Icons.people_outline_rounded,
          label: 'Type to search community members');
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .snapshots(),
      builder: (context, followingSnap) {
        final followingIds =
            followingSnap.data?.docs.map((d) => d.id).toSet() ?? <String>{};
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .limit(200)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(
                      color: c.primary, strokeWidth: 2));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final q = searchQuery.toLowerCase();
            final docs = (snapshot.data?.docs ?? []).where((doc) {
              if (doc.id == currentUid) return false;
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final username =
                  (data['username'] ?? '').toString().toLowerCase();
              return name.contains(q) || username.contains(q);
            }).toList();
            if (docs.isEmpty) {
              return _GlassEmptyPlaceholder(
                  icon: Icons.person_search_rounded,
                  label: 'No users found');
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final docId = docs[i].id;
                final data = docs[i].data() as Map<String, dynamic>;
                final String name = data['name'] ?? 'User';
                final String username = data['username'] ?? 'user';
                final String avatarUrl = data['avatarUrl'] ?? '';
                final bool isFollowing = followingIds.contains(docId);
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                        userId: docId,
                        userName: name,
                        userAvatar: avatarUrl),
                  )),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(
                                alpha: isDark ? 0.14 : 0.55),
                            width: 0.5,
                          ),
                        ),
                        child: Row(children: [
                          CustomAvatar(
                              name: name,
                              imageUrl:
                                  avatarUrl.isNotEmpty ? avatarUrl : null,
                              userId: docId,
                              radius: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: TextStyle(
                                          color: c.textHi,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(height: 1),
                                  Text(
                                      username.startsWith('@')
                                          ? username
                                          : '@$username',
                                      style: TextStyle(
                                          color: c.textMuted, fontSize: 11)),
                                ]),
                          ),
                          GestureDetector(
                            onTap: () =>
                                _toggleFollow(context, docId, isFollowing),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: isFollowing
                                    ? Colors.transparent
                                    : c.primary,
                                borderRadius: BorderRadius.circular(20),
                                border: isFollowing
                                    ? Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.4))
                                    : null,
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: isFollowing
                                      ? c.textMuted
                                      : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
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

// ── Tab 2 & 3: Posts & Videos ──────────────────────────────────────────────────

class _PostResultsList extends StatelessWidget {
  final String searchQuery;
  final bool searchVideos;
  const _PostResultsList(
      {required this.searchQuery, required this.searchVideos});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (searchQuery.isEmpty) {
      return _GlassEmptyPlaceholder(
        icon: searchVideos
            ? Icons.videocam_outlined
            : Icons.article_outlined,
        label: searchVideos
            ? 'Search for video posts'
            : 'Search questions and posts',
      );
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: c.primary, strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final q = searchQuery.toLowerCase();
        final List<Post> posts = [];
        for (final doc in snapshot.data?.docs ?? []) {
          try {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final type = data['type'] ?? 'text';
            if (searchVideos && type != 'video') continue;
            if (!searchVideos && type == 'video') continue;
            final title = (data['title'] ?? '').toString().toLowerCase();
            final body = (data['body'] ?? '').toString().toLowerCase();
            final content =
                (data['content'] ?? '').toString().toLowerCase();
            final authorName =
                (data['authorName'] ?? '').toString().toLowerCase();
            if (!title.contains(q) &&
                !body.contains(q) &&
                !content.contains(q) &&
                !authorName.contains(q)) continue;
            posts.add(Post.fromFirestore(doc, currentUid));
          } catch (e) {
            debugPrint('Skipped post [${doc.id}]: $e');
          }
        }
        if (posts.isEmpty) {
          return _GlassEmptyPlaceholder(
            icon: searchVideos
                ? Icons.videocam_off_outlined
                : Icons.search_off_rounded,
            label:
                searchVideos ? 'No video posts found' : 'No posts found',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final post = posts[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PostCard(
                post: post,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: post))),
                onLike: () {
                  NotificationService.toggleLike(
                    postId: post.id,
                    postAuthorId: post.authorId,
                    postTitle: post.title,
                    currentUid: currentUid,
                    likedBy: post.isLiked ? [currentUid] : [],
                  );
                },
                onComment: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => PostDetailScreen(post: post))),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab 4: Communities ─────────────────────────────────────────────────────────

class _CommunityResultsList extends StatelessWidget {
  final String searchQuery;
  const _CommunityResultsList({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (searchQuery.isEmpty) {
      return const _GlassEmptyPlaceholder(
          icon: Icons.groups_outlined, label: 'Discover communities');
    }
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('communities')
          .limit(200)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: c.primary, strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final q = searchQuery.toLowerCase();
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final desc =
              (data['description'] ?? '').toString().toLowerCase();
          return name.contains(q) || desc.contains(q);
        }).toList();
        if (docs.isEmpty) {
          return const _GlassEmptyPlaceholder(
              icon: Icons.group_off_outlined,
              label: 'No communities found');
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final String title = data['name'] ?? 'Community';
            final String desc = data['description'] ?? '';
            final String avatarUrl = data['avatarUrl'] ?? '';
            final int count =
                (data['memberCount'] as num?)?.toInt() ?? 1;
            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(
                    communityId: doc.id,
                    communityName: title,
                    communityDescription: desc),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: isDark ? 0.14 : 0.55),
                        width: 0.5,
                      ),
                    ),
                    child: Row(children: [
                       CustomAvatar(
                         name: title,
                         imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                         radius: 18,
                       ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: TextStyle(
                                      color: c.textHi,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(desc,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: c.textMuted, fontSize: 11)),
                              ],
                            ]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$count',
                            style: TextStyle(
                                color: c.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Glass empty state ──────────────────────────────────────────────────────────

class _GlassEmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassEmptyPlaceholder(
      {required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white
                      .withValues(alpha: isDark ? 0.18 : 0.6),
                  width: 0.8,
                ),
              ),
              child: Icon(icon, color: c.primary, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.textMuted, fontSize: 12, height: 1.5)),
      ]),
    );
  }
}
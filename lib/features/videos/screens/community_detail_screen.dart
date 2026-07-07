import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../create/screens/create_post_screen.dart';
import '../../../shared/widgets/shimmer.dart';
import 'edit_community_screen.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/routes/app_routes.dart';
import 'community_search_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String communityDescription;

  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.communityDescription,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .snapshots(),
      builder: (context, communitySnapshot) {
        final communityData =
            communitySnapshot.data?.data() as Map<String, dynamic>? ?? {};

        final String name        = communityData['name'] ?? widget.communityName;
        final String description = communityData['description'] ?? widget.communityDescription;
        final String bannerUrl   = communityData['bannerUrl'] ?? '';
        final String avatarUrl   = communityData['avatarUrl'] ?? '';
        final List admins        = communityData['admins'] ?? [];
        final bool isAdmin       =
            admins.contains(currentUid) || communityData['creatorId'] == currentUid;

        return Scaffold(
          backgroundColor: context.appColors.bg,
          appBar: AppBar(
            backgroundColor: context.appColors.surface,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.appColors.field,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: context.appColors.primary),
              ),
            ),
            title: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: context.appColors.textPrimary,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.search_rounded, size: 20, color: context.appColors.primary),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CommunitySearchScreen(
                    communityId: widget.communityId,
                    communityName: name,
                  ),
                )),
              ),
              if (isAdmin)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.appColors.field,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.edit_rounded, size: 17, color: context.appColors.primary),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EditCommunityScreen(
                        communityId: widget.communityId,
                        currentData: communityData,
                      ),
                    )),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // ── Community header ─────────────────────────────────────────
              _CommunityHeader(
                name: name,
                description: description,
                bannerUrl: bannerUrl,
                avatarUrl: avatarUrl,
                isAdmin: isAdmin,
                communityId: widget.communityId,
              ),

              // ── Posts feed ───────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('communityId', isEqualTo: widget.communityId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Error: ${snapshot.error}',
                              style: const TextStyle(fontSize: 12)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, __) => const PostCardShimmer(),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final allPosts = docs.map((d) => Post.fromFirestore(d, currentUid)).toList();

                    if (allPosts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 44, color: context.appColors.chipBorder),
                            const SizedBox(height: 12),
                            Text(
                              'No posts here yet.\nBe the first to share!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: context.appColors.textDim,
                                  fontSize: 13,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(12, 4, 12, 90),
                      itemCount: allPosts.length,
                      itemBuilder: (context, index) {
                        final postItem = allPosts[index];
                        final doc = docs.firstWhere((d) => d.id == postItem.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PostCard(
                            post: postItem,
                            heroTag: 'community_post_${postItem.id}',
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.postDetail,
                              arguments: {
                                'post': postItem,
                                'heroTag': 'community_post_${postItem.id}',
                              },
                            ),
                            onLike: () {
                              final dataMap = doc.data() as Map<String, dynamic>?;
                              final List likedBy = dataMap?['likedBy'] ?? [];
                              NotificationService.toggleLike(
                                postId: doc.id,
                                postAuthorId: postItem.authorId,
                                postTitle: postItem.title,
                                currentUid: currentUid,
                                likedBy: likedBy,
                              );
                            },
                            onComment: () => Navigator.of(context).pushNamed(
                              AppRoutes.postDetail,
                              arguments: {
                                'post': postItem,
                                'heroTag': 'community_post_${postItem.id}',
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // ── FAB ────────────────────────────────────────────────────────────
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: context.appColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Post here',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CreatePostScreen(communityId: widget.communityId),
            )),
          ),
        );
      },
    );
  }
}

// ─── Community Header ─────────────────────────────────────────────────────────

class _CommunityHeader extends StatelessWidget {
  final String name;
  final String description;
  final String bannerUrl;
  final String avatarUrl;
  final bool isAdmin;
  final String communityId;

  const _CommunityHeader({
    required this.name,
    required this.description,
    required this.bannerUrl,
    required this.avatarUrl,
    required this.isAdmin,
    required this.communityId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (bannerUrl.isNotEmpty)
                Image.network(
                  bannerUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _FallbackBanner(name: name),
                )
              else
                _FallbackBanner(name: name),
            ],
          ),

          // Body row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar elevated above banner
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.appColors.field,
                      border: Border.all(color: context.appColors.surface, width: 3),
                      image: avatarUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarUrl.isEmpty
                        ? Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'C',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: context.appColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: context.appColors.textPrimary)),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                                fontSize: 13,
                                color: context.appColors.textSecondary,
                                height: 1.4),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Stats row
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('communities')
                              .doc(communityId)
                              .snapshots(),
                          builder: (context, snap) {
                            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                            final int members = data['memberCount'] ?? 0;
                            return Row(
                              children: [
                                _StatPill(
                                    icon: Icons.people_outline_rounded,
                                    label: '$members members'),
                              ],
                            );
                          },
                        ),

                        if (isAdmin) ...[
                          const SizedBox(height: 8),
                          _AdminBadge(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 0.5, color: context.appColors.divider),
        ],
      ),
    );
  }
}

// ─── Fallback banner ──────────────────────────────────────────────────────────

class _FallbackBanner extends StatelessWidget {
  final String name;
  const _FallbackBanner({required this.name});

  Color _color(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? const [
            Color(0xFF1E1B3A), Color(0xFF143029), Color(0xFF332610),
            Color(0xFF33151A), Color(0xFF132530),
          ]
        : const [
            Color(0xFFEEF0FB), Color(0xFFE1FBF4), Color(0xFFFFF8EC),
            Color(0xFFFFECF0), Color(0xFFE6F4FB),
          ];
    final code = name.isNotEmpty ? name.codeUnitAt(0) : 65;
    return colors[code % colors.length];
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 100,
        width: double.infinity,
        color: _color(context),
        child: Center(
          child: Icon(Icons.groups_rounded, size: 36, color: context.appColors.chipBorder),
        ),
      );
}

// ─── Stat pill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.appColors.textMuted),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textMuted)),
        ],
      );
}

// ─── Admin badge ──────────────────────────────────────────────────────────────

class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: context.appColors.field,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 11, color: context.appColors.primary),
            const SizedBox(width: 4),
            Text(
              'You\'re an admin',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.primary),
            ),
          ],
        ),
      );
}
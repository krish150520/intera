import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../create/screens/create_post_screen.dart';
import 'edit_community_screen.dart';

class CommunityDetailScreen extends StatelessWidget {
  final String communityId;
  final String communityName;
  final String communityDescription;

  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.communityDescription,
  });

  // ─── Theme ────────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF6C63D5);
  static const Color _pageBg     = Color(0xFFEEF0FB);
  static const Color _fieldBg    = Color(0xFFF0EEFF);
  static const Color _chipBorder = Color(0xFFD8D5F8);
  static const Color _textDark   = Color(0xFF2D2A6E);
  static const Color _textMuted  = Color(0xFF8884BB);
  static const Color _cardBorder = Color(0xFFE4E2F8);

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .snapshots(),
      builder: (context, communitySnapshot) {
        final communityData =
            communitySnapshot.data?.data() as Map<String, dynamic>? ?? {};

        final String name        = communityData['name'] ?? communityName;
        final String description = communityData['description'] ?? communityDescription;
        final String bannerUrl   = communityData['bannerUrl'] ?? '';
        final String avatarUrl   = communityData['avatarUrl'] ?? '';
        final List admins        = communityData['admins'] ?? [];
        final bool isAdmin       =
            admins.contains(currentUid) || communityData['creatorId'] == currentUid;

        return Scaffold(
          backgroundColor: _pageBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F4FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: _primary),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _textDark,
              ),
            ),
            centerTitle: true,
            actions: [
              if (isAdmin)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F4FF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_rounded, size: 17, color: _primary),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EditCommunityScreen(
                        communityId: communityId,
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
                communityId: communityId,
              ),

              // ── Posts feed ───────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('communityId', isEqualTo: communityId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Error: ${snapshot.error}',
                              style: const TextStyle(fontSize: 12)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: _primary));
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.forum_outlined,
                                size: 44, color: Color(0xFFD8D5F8)),
                            const SizedBox(height: 12),
                            const Text(
                              'No posts here yet.\nBe the first to share!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF9E9BD0),
                                  fontSize: 13,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc      = docs[index];
                        final postItem = Post.fromFirestore(doc, currentUid);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PostCard(
                            post: postItem,
                            onTap: () {},
                            onLike: () {
                              final ref = FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(doc.id);
                              if (postItem.isLiked) {
                                ref.update({
                                  'likeCount': FieldValue.increment(-1),
                                  'likedBy': FieldValue.arrayRemove([currentUid]),
                                });
                              } else {
                                ref.update({
                                  'likeCount': FieldValue.increment(1),
                                  'likedBy': FieldValue.arrayUnion([currentUid]),
                                });
                              }
                            },
                            onComment: () {},
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
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Post here',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CreatePostScreen(communityId: communityId),
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

  static const Color _primary    = Color(0xFF6C63D5);
  static const Color _fieldBg    = Color(0xFFF0EEFF);
  static const Color _chipBorder = Color(0xFFD8D5F8);
  static const Color _textDark   = Color(0xFF2D2A6E);
  static const Color _textMuted  = Color(0xFF8884BB);
  static const Color _cardBorder = Color(0xFFE4E2F8);

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
      color: Colors.white,
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
                      color: _fieldBg,
                      border: Border.all(color: Colors.white, width: 3),
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
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: _primary,
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
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _textDark)),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5A587A),
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

          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE4E2F8)),
        ],
      ),
    );
  }
}

// ─── Fallback banner ──────────────────────────────────────────────────────────

class _FallbackBanner extends StatelessWidget {
  final String name;
  const _FallbackBanner({required this.name});

  Color get _color {
    const colors = [
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
        color: _color,
        child: Center(
          child: Icon(Icons.groups_rounded, size: 36, color: const Color(0xFFD8D5F8)),
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
          Icon(icon, size: 14, color: const Color(0xFF8884BB)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8884BB))),
        ],
      );
}

// ─── Admin badge ──────────────────────────────────────────────────────────────

class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EEFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8D5F8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.shield_outlined, size: 11, color: Color(0xFF6C63D5)),
            SizedBox(width: 4),
            Text(
              'You\'re an admin',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C63D5)),
            ),
          ],
        ),
      );
}
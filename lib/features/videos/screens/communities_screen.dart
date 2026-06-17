import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import 'create_community_screen.dart';
import 'community_detail_screen.dart';

class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key});

  // ─── Theme ────────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF6C63D5);
  static const Color _pageBg     = Color(0xFFEEF0FB);
  static const Color _fieldBg    = Color(0xFFF0EEFF);
  static const Color _chipBorder = Color(0xFFD8D5F8);
  static const Color _textDark   = Color(0xFF2D2A6E);
  static const Color _textMuted  = Color(0xFF9E9BD0);
  static const Color _cardBorder = Color(0xFFE4E2F8);

  // ─── Join / Leave ─────────────────────────────────────────────────────────
  void _toggleJoinCommunity(BuildContext context, String communityId, bool isMember) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final ref = FirebaseFirestore.instance.collection('communities').doc(communityId);
    try {
      if (isMember) {
        await ref.update({
          'members': FieldValue.arrayRemove([uid]),
          'memberCount': FieldValue.increment(-1),
        });
      } else {
        await ref.update({
          'members': FieldValue.arrayUnion([uid]),
          'memberCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Communities',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: _textDark),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Color(0xFFF5F4FF), shape: BoxShape.circle),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.search_rounded, size: 18, color: _primary),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('communities').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primary));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined, size: 48, color: _chipBorder),
                  const SizedBox(height: 12),
                  const Text(
                    'No communities yet.\nBe the first to create one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc  = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String name        = data['name'] ?? 'Unnamed';
              final String description = data['description'] ?? '';
              final String avatarUrl   = data['avatarUrl'] ?? '';
              final String bannerUrl   = data['bannerUrl'] ?? '';
              final int memberCount    = data['memberCount'] ?? 1;
              final List membersList   = data['members'] ?? [];
              final bool isMember      = membersList.contains(uid);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CommunityCard(
                  name: name,
                  description: description,
                  avatarUrl: avatarUrl,
                  bannerUrl: bannerUrl,
                  memberCount: memberCount,
                  isMember: isMember,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CommunityDetailScreen(
                      communityId: doc.id,
                      communityName: name,
                      communityDescription: description,
                    ),
                  )),
                  onJoinToggle: () => _toggleJoinCommunity(context, doc.id, isMember),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ─── Community Card ───────────────────────────────────────────────────────────

class _CommunityCard extends StatelessWidget {
  final String name;
  final String description;
  final String avatarUrl;
  final String bannerUrl;
  final int memberCount;
  final bool isMember;
  final VoidCallback onTap;
  final VoidCallback onJoinToggle;

  static const Color _primary    = Color(0xFF6C63D5);
  static const Color _fieldBg    = Color(0xFFF0EEFF);
  static const Color _chipBorder = Color(0xFFD8D5F8);
  static const Color _textDark   = Color(0xFF2D2A6E);
  static const Color _textMuted  = Color(0xFF9E9BD0);
  static const Color _cardBorder = Color(0xFFE4E2F8);

  const _CommunityCard({
    required this.name,
    required this.description,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.memberCount,
    required this.isMember,
    required this.onTap,
    required this.onJoinToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner ───────────────────────────────────────────────────
              if (bannerUrl.isNotEmpty)
                Image.network(
                  bannerUrl,
                  height: 72,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _BannerAccent(name: name),
                )
              else
                _BannerAccent(name: name),

              // ── Body ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _fieldBg,
                        border: Border.all(color: _chipBorder, width: 1.5),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Text info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _textDark,
                              )),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 13, color: _textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '$memberCount members',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5A587A),
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (isMember) ...[
                            const SizedBox(height: 7),
                            _JoinedBadge(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Join / Leave button
                    _JoinButton(isMember: isMember, onPressed: onJoinToggle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Banner fallback with subtle gradient accent ────────────────────────────────

class _BannerAccent extends StatelessWidget {
  final String name;
  const _BannerAccent({required this.name});

  static const Color _primary = Color(0xFF6C63D5);

  // Pick a soft accent based on first letter
  Color get _accentColor {
    final code = name.isNotEmpty ? name.codeUnitAt(0) : 65;
    const colors = [
      Color(0xFFF0EEFF), Color(0xFFE1FBF4), Color(0xFFFFF8EC),
      Color(0xFFFFECF0), Color(0xFFE6F4FB),
    ];
    return colors[code % colors.length];
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 6,
        color: _accentColor,
      );
}

// ── Joined badge ──────────────────────────────────────────────────────────────

class _JoinedBadge extends StatelessWidget {
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
            Icon(Icons.check_circle_outline_rounded, size: 11, color: Color(0xFF6C63D5)),
            SizedBox(width: 4),
            Text(
              'Joined',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6C63D5),
              ),
            ),
          ],
        ),
      );
}

// ── Join / Leave button ───────────────────────────────────────────────────────

class _JoinButton extends StatelessWidget {
  final bool isMember;
  final VoidCallback onPressed;
  const _JoinButton({required this.isMember, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: isMember ? Colors.white : const Color(0xFF6C63D5),
              foregroundColor: isMember ? const Color(0xFF6C63D5) : Colors.white,
              side: BorderSide(
                color: isMember ? const Color(0xFFD8D5F8) : const Color(0xFF6C63D5),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isMember ? 'Joined' : 'Join',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
}
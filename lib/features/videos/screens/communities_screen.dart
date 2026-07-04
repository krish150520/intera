import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import 'create_community_screen.dart';
import 'community_detail_screen.dart';
import '../../search/screens/search_screen.dart';

class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key});

  void _toggleJoinCommunity(BuildContext context, String communityId, bool isMember) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection('communities').doc(communityId);
    try {
      if (isMember) {
        await ref.update({'members': FieldValue.arrayRemove([uid]), 'memberCount': FieldValue.increment(-1)});
      } else {
        await ref.update({'members': FieldValue.arrayUnion([uid]), 'memberCount': FieldValue.increment(1)});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: context.appColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: Text('Communities',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: c.textHi)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            width: 36, height: 36,
            decoration: BoxDecoration(color: c.field, shape: BoxShape.circle),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.search_rounded, size: 18, color: c.primary),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('communities').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.group_outlined, size: 48, color: c.chipBorder),
                const SizedBox(height: 12),
                Text('No communities yet.\nBe the first to create one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5)),
              ]),
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
                  name: name, description: description,
                  avatarUrl: avatarUrl, bannerUrl: bannerUrl,
                  memberCount: memberCount, isMember: isMember,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CommunityDetailScreen(communityId: doc.id, communityName: name, communityDescription: description),
                  )),
                  onJoinToggle: () => _toggleJoinCommunity(context, doc.id, isMember),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateCommunityScreen())),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ── Community card ────────────────────────────────────────────────────────────

class _CommunityCard extends StatelessWidget {
  final String name, description, avatarUrl, bannerUrl;
  final int memberCount;
  final bool isMember;
  final VoidCallback onTap, onJoinToggle;

  const _CommunityCard({
    required this.name, required this.description,
    required this.avatarUrl, required this.bannerUrl,
    required this.memberCount, required this.isMember,
    required this.onTap, required this.onJoinToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              if (bannerUrl.isNotEmpty)
                Image.network(bannerUrl, height: 72, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _BannerAccent(name: name))
              else
                _BannerAccent(name: name),

              // Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Avatar
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.field,
                      border: Border.all(color: c.chipBorder, width: 1.5),
                      image: avatarUrl.isNotEmpty
                          ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: avatarUrl.isEmpty
                        ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.primary)))
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.textHi)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.people_outline_rounded, size: 13, color: c.textMuted),
                        const SizedBox(width: 4),
                        Text('$memberCount members',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted)),
                      ]),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4)),
                      ],
                      if (isMember) ...[
                        const SizedBox(height: 7),
                        _JoinedBadge(),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 10),
                  _JoinButton(isMember: isMember, onPressed: onJoinToggle),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Banner accent ─────────────────────────────────────────────────────────────

class _BannerAccent extends StatelessWidget {
  final String name;
  const _BannerAccent({required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // Cycle through a few tints from the palette based on first letter
    final tints = [c.field, c.bg, c.surface];
    final tint  = tints[(name.isNotEmpty ? name.codeUnitAt(0) : 0) % tints.length];
    return Container(height: 6, color: tint);
  }
}

// ── Joined badge ──────────────────────────────────────────────────────────────

class _JoinedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.chipBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded, size: 11, color: c.primary),
        const SizedBox(width: 4),
        Text('Joined', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.primary)),
      ]),
    );
  }
}

// ── Join button ───────────────────────────────────────────────────────────────

class _JoinButton extends StatelessWidget {
  final bool isMember;
  final VoidCallback onPressed;
  const _JoinButton({required this.isMember, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isMember ? Colors.transparent : c.primary,
          foregroundColor: isMember ? c.primary : Colors.white,
          side: BorderSide(color: isMember ? c.chipBorder : c.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(isMember ? 'Joined' : 'Join',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
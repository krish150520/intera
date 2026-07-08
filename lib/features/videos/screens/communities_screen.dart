import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import 'create_community_screen.dart';
import 'community_detail_screen.dart';
import 'search_communities_screen.dart';
import '../../../shared/widgets/shimmer.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Technology',
    'Gaming',
    'College',
    'Design',
    'Study'
  ];

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
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Communities',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: c.textHi),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.search_rounded, size: 20, color: c.textHi),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchCommunitiesScreen()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5E7FF), Color(0xFFF8F9FF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Category Chips Row
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [c.primary, Colors.purpleAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isSelected ? null : Colors.white.withValues(alpha: 0.4),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : c.border.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: c.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : c.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Communities List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('communities')
                    .orderBy('memberCount', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, __) => const CommunityCardShimmer(),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];

                  // Apply client-side local search category filtering based on description keywords
                  final category = _selectedCategory.toLowerCase();
                  final filteredDocs = docs.where((doc) {
                    if (category == 'all') return true;
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final desc = (data['description'] ?? '').toString().toLowerCase();

                    if (category == 'technology') {
                      return name.contains('tech') || name.contains('code') || name.contains('dev') || desc.contains('tech') || desc.contains('code') || desc.contains('dev');
                    }
                    if (category == 'gaming') {
                      return name.contains('game') || name.contains('gaming') || name.contains('play') || desc.contains('game') || desc.contains('gaming') || desc.contains('play');
                    }
                    if (category == 'college') {
                      return name.contains('college') || name.contains('uni') || name.contains('student') || desc.contains('college') || desc.contains('uni') || desc.contains('student');
                    }
                    if (category == 'design') {
                      return name.contains('design') || name.contains('art') || name.contains('creative') || desc.contains('design') || desc.contains('art') || desc.contains('creative');
                    }
                    if (category == 'study') {
                      return name.contains('study') || name.contains('learn') || name.contains('book') || desc.contains('study') || desc.contains('learn') || desc.contains('book');
                    }
                    return false;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined, size: 48, color: c.chipBorder),
                          const SizedBox(height: 12),
                          Text(
                            'No spaces found yet.\nBe the first to create one!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [c.primary, Colors.purpleAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Text(
                                'Create Community',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc  = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String name        = data['name'] ?? 'Unnamed';
                      final String description = data['description'] ?? '';
                      final String avatarUrl   = data['avatarUrl'] ?? '';
                      final String bannerUrl   = data['bannerUrl'] ?? '';
                      final int memberCount    = data['memberCount'] ?? 1;
                      final List membersList   = data['members'] ?? [];
                      final bool isMember      = membersList.contains(uid);

                      return _StaggeredFadeSlide(
                        index: index,
                        child: _CommunityCard(
                          id: doc.id,
                          name: name,
                          description: description,
                          avatarUrl: avatarUrl,
                          bannerUrl: bannerUrl,
                          memberCount: memberCount,
                          isMember: isMember,
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
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: _AnimatedCreateFAB(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
          ),
        ),
      ),
    );
  }
}

// ── Overlapping Cover Community Card ──

class _CommunityCard extends StatelessWidget {
  final String id, name, description, avatarUrl, bannerUrl;
  final int memberCount;
  final bool isMember;
  final VoidCallback onTap, onJoinToggle;

  const _CommunityCard({
    required this.id,
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
    final c = context.appColors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Cover
            Stack(
              children: [
                Hero(
                  tag: 'community_banner_$id',
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: bannerUrl.isNotEmpty
                        ? Image.network(
                            bannerUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _PlaceholderBanner(name: name),
                          )
                        : _PlaceholderBanner(name: name),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.25), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Overlapping Logo Section
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Circular Logo Hero
                    Hero(
                      tag: 'community_logo_$id',
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.surface,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: avatarUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: avatarUrl.isEmpty
                            ? Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: c.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Member count pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '👥 $memberCount members',
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Details info text
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.textHi,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Join Button Alignment Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _CommunityJoinButton(
                        isMember: isMember,
                        onPressed: onJoinToggle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gradient placeholder banner for cover ──

class _PlaceholderBanner extends StatelessWidget {
  final String name;
  const _PlaceholderBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final tints = [
      LinearGradient(colors: [c.primary.withValues(alpha: 0.2), Colors.purpleAccent.withValues(alpha: 0.2)]),
      LinearGradient(colors: [Colors.blueAccent.withValues(alpha: 0.2), Colors.tealAccent.withValues(alpha: 0.2)]),
      LinearGradient(colors: [Colors.orangeAccent.withValues(alpha: 0.2), Colors.redAccent.withValues(alpha: 0.2)]),
    ];
    final gradient = tints[(name.isNotEmpty ? name.codeUnitAt(0) : 0) % tints.length];
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Center(
        child: Opacity(
          opacity: 0.2,
          child: Icon(Icons.groups_rounded, size: 48, color: c.primary),
        ),
      ),
    );
  }
}

// ── Custom animated Join Button ──

class _CommunityJoinButton extends StatefulWidget {
  final bool isMember;
  final VoidCallback onPressed;

  const _CommunityJoinButton({
    required this.isMember,
    required this.onPressed,
  });

  @override
  State<_CommunityJoinButton> createState() => _CommunityJoinButtonState();
}

class _CommunityJoinButtonState extends State<_CommunityJoinButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: widget.isMember
                ? null
                : LinearGradient(
                    colors: [c.primary, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: widget.isMember ? Colors.white.withValues(alpha: 0.6) : null,
            border: widget.isMember
                ? Border.all(color: c.border, width: 1.2)
                : null,
            boxShadow: [
              if (!widget.isMember)
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isMember) ...[
                Icon(Icons.check_rounded, size: 14, color: c.textHi),
                const SizedBox(width: 4),
              ],
              Text(
                widget.isMember ? 'Joined' : 'Join',
                style: TextStyle(
                  color: widget.isMember ? c.textHi : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating Action Button with Rotate Animation ──

class _AnimatedCreateFAB extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedCreateFAB({required this.onTap});

  @override
  State<_AnimatedCreateFAB> createState() => _AnimatedCreateFABState();
}

class _AnimatedCreateFABState extends State<_AnimatedCreateFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [c.primary, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: c.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: RotationTransition(
          turns: _rotationAnimation,
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// ── Staggered list fade-slide entry transition ──

class _StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredFadeSlide({required this.index, required this.child});

  @override
  State<_StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<_StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    final delay = Duration(milliseconds: 50 * widget.index);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
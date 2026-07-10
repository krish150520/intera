import 'dart:ui';
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
import 'community_chat_screen.dart';
import 'create_poll_screen.dart';
import 'create_question_screen.dart';



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
  late ScrollController _scrollController;
  bool _showCollapsedTitle = false;

  // Layout constants shared between the sliver app bar and the avatar overlay.
  static const double _bannerHeight = 180.0;
  static const double _avatarSize = 80.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final isCollapsed = _scrollController.offset > 110;
      if (isCollapsed != _showCollapsedTitle) {
        setState(() {
          _showCollapsedTitle = isCollapsed;
        });
      }
    }
  }

  void _toggleJoinCommunity(BuildContext context, bool isMember) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId);

    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.appColors.error;

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
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showCreatePostOptionSheet(BuildContext context) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Create Post',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textHi),
              ),
            ),
            Divider(height: 1, color: c.divider),
            _PostTypeListTile(
              icon: Icons.article_outlined,
              label: 'Text Post',
              communityId: widget.communityId,
              communityName: widget.communityName,
              postType: 'text',
              sheetCtx: sheetCtx,
            ),
            _PostTypeListTile(
              icon: Icons.image_outlined,
              label: 'Photo Post',
              communityId: widget.communityId,
              communityName: widget.communityName,
              postType: 'photo',
              sheetCtx: sheetCtx,
            ),
            _PostTypeListTile(
              icon: Icons.help_outline_rounded,
              label: 'Question Post',
              communityId: widget.communityId,
              communityName: widget.communityName,
              postType: 'question',
              sheetCtx: sheetCtx,
            ),
            _PostTypeListTile(
              icon: Icons.poll_outlined,
              label: 'Poll Post',
              communityId: widget.communityId,
              communityName: widget.communityName,
              postType: 'poll',
              sheetCtx: sheetCtx,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final c = context.appColors;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .snapshots(),
      builder: (context, communitySnapshot) {
        final communityData =
            communitySnapshot.data?.data() as Map<String, dynamic>? ?? {};

        final String name =
            communityData['name'] ?? widget.communityName;
        final String description =
            communityData['description'] ?? widget.communityDescription;
        final String bannerUrl = communityData['bannerUrl'] ?? '';
        final String avatarUrl = communityData['avatarUrl'] ?? '';
        final List admins = communityData['admins'] ?? [];
        final List membersList = communityData['members'] ?? [];
        final int membersCount = communityData['memberCount'] ?? 1;
        final bool isMember = membersList.contains(currentUid);
        final bool isAdmin = admins.contains(currentUid) ||
            communityData['creatorId'] == currentUid;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: context.isDarkMode
                        ? [
                            const Color(0xFF2A2F55),
                            const Color(0xFF171A30),
                            const Color(0xFF171A30),
                          ]
                        : const [
                            Color(0xFFE5E7FF),
                            Color(0xFFF8F9FF),
                            Colors.white,
                          ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Collapsing SliverAppBar ──
                    SliverAppBar(
                      expandedHeight: _bannerHeight,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leadingWidth: 56,
                      leading: Padding(
                        padding: const EdgeInsets.only(
                            left: 16.0, top: 12.0, bottom: 8.0),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.25),
                                    width: 1),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: c.textHi,
                                    size: 16),
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                width: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withValues(alpha: 0.15),
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.25),
                                      width: 1),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.search_rounded,
                                      color: c.textHi, size: 18),
                                  onPressed: () =>
                                      Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CommunitySearchScreen(
                                        communityId: widget.communityId,
                                        communityName: name,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAdmin) ...[
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8.0),
                            child: ClipOval(
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  width: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white
                                        .withValues(alpha: 0.15),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        width: 1),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.edit_rounded,
                                        color: c.textHi, size: 16),
                                    onPressed: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EditCommunityScreen(
                                          communityId: widget.communityId,
                                          currentData: communityData,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.symmetric(
                            horizontal: 56, vertical: 14),
                        title: AnimatedOpacity(
                          opacity: _showCollapsedTitle ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: c.textHi,
                            ),
                          ),
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'community_banner_${widget.communityId}',
                              child: bannerUrl.isNotEmpty
                                  ? Image.network(bannerUrl,
                                      fit: BoxFit.cover)
                                  : _FallbackBanner(name: name),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Details and Metadata section ──
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row reserving space for the avatar (rendered as an
                          // overlay above the whole Stack — see below) plus
                          // the action buttons, which stay in normal flow.
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 0, 24, 0),
                            child: SizedBox(
                              height: 48, // matches old row's visible height below the -32 translate
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const SizedBox(width: _avatarSize),
                                  const Spacer(),
                                  if (isMember) ...[
                                    _ActionPillButton(
                                      onPressed: () => _toggleJoinCommunity(
                                          context, isMember),
                                      isOutline: true,
                                      label: 'Joined ✓',
                                    ),
                                    const SizedBox(width: 8),
                                    _ActionPillButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => CommunityChatScreen(
                                              communityId: widget.communityId,
                                              communityName: name,
                                              communityAvatar: avatarUrl,
                                            ),
                                          ),
                                        );
                                      },
                                      isOutline: false,
                                      label: 'Chat 💬',
                                    ),
                                  ] else ...[
                                    _ActionPillButton(
                                      onPressed: () => _toggleJoinCommunity(
                                          context, isMember),
                                      isOutline: false,
                                      label: 'Join Space',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Info section
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: c.textHi,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: c.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                if (isAdmin) ...[
                                  _AdminBadge(),
                                  const SizedBox(height: 16),
                                ],

                                // Stats row
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('posts')
                                      .where('communityId',
                                          isEqualTo: widget.communityId)
                                      .snapshots(),
                                  builder: (context, postsSnap) {
                                    final int posts =
                                        postsSnap.data?.docs.length ?? 0;
                                    return SizedBox(
                                      width: double.infinity,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildDetailStatColumn(
                                              c, 'Posts', posts),
                                          _VerticalDivider(color: c.border),
                                          _buildDetailStatColumn(
                                              c, 'Members', membersCount),
                                          _VerticalDivider(color: c.border),
                                          _buildDetailStatColumn(
                                              c,
                                              'Online',
                                              membersCount > 0
                                                  ? (membersCount / 2).ceil()
                                                  : 1),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Divider(
                              height: 1,
                              color: c.border.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // ── Posts Feed ──
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .where('communityId',
                              isEqualTo: widget.communityId)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  'Error loading posts. Please try again.',
                                  style: TextStyle(
                                      fontSize: 12, color: c.textMuted),
                                ),
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return SliverPadding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: PostCardShimmer(),
                                ),
                                childCount: 3,
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        final allPosts = docs
                            .map((d) => Post.fromFirestore(d, currentUid))
                            .toList();

                        if (allPosts.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 60, horizontal: 24),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.forum_outlined,
                                        size: 44, color: c.chipBorder),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No posts here yet.\nBe the first to share!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: c.textMuted,
                                          fontSize: 13,
                                          height: 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.only(bottom: 90),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final postItem = allPosts[index];
                                final doc = docs
                                    .firstWhere((d) => d.id == postItem.id);

                                return _StaggeredFadeSlide(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    child: PostCard(
                                      post: postItem,
                                      heroTag:
                                          'community_post_${postItem.id}',
                                      onTap: () =>
                                          Navigator.of(context).pushNamed(
                                        AppRoutes.postDetail,
                                        arguments: {
                                          'post': postItem,
                                          'heroTag':
                                              'community_post_${postItem.id}',
                                        },
                                      ),
                                      onLike: () {
                                        final dataMap = doc.data()
                                            as Map<String, dynamic>?;
                                        final List likedBy =
                                            dataMap?['likedBy'] ?? [];
                                        NotificationService.toggleLike(
                                          postId: doc.id,
                                          postAuthorId: postItem.authorId,
                                          postTitle: postItem.title,
                                          currentUid: currentUid,
                                          likedBy: likedBy,
                                        );
                                      },
                                      onComment: () =>
                                          Navigator.of(context).pushNamed(
                                        AppRoutes.postDetail,
                                        arguments: {
                                          'post': postItem,
                                          'heroTag':
                                              'community_post_${postItem.id}',
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: allPosts.length,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Avatar overlay ──
              // Painted above the pinned SliverAppBar (which otherwise always
              // paints above earlier slivers regardless of tree order), so the
              // avatar never gets clipped under the banner.
              AnimatedBuilder(
                animation: _scrollController,
                builder: (context, _) {
                  final offset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  final topPadding = MediaQuery.of(context).padding.top;
                  // Resting position: bottom of banner, half-overlapping it.
                  final restTop = topPadding + _bannerHeight - (_avatarSize / 2);
                  // Collapsed position: tucked near the pinned toolbar.
                  final minTop = topPadding + kToolbarHeight - (_avatarSize / 2) - 4;
                  double top = restTop - offset;
                  if (top < minTop) top = minTop;
                  final range = restTop - minTop;
                  final opacity = range <= 0
                      ? 1.0
                      : ((top - minTop) / range).clamp(0.0, 1.0);

                  return Positioned(
                    top: top,
                    left: 24,
                    child: IgnorePointer(
                      ignoring: opacity < 0.5,
                      child: Opacity(
                        opacity: opacity,
                        child: Hero(
                          tag: 'community_logo_${widget.communityId}',
                          child: Container(
                            width: _avatarSize,
                            height: _avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.surface,
                              border: Border.all(
                                color: context.isDarkMode
                                    ? c.surface
                                    : Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              image: avatarUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover)
                                  : null,
                            ),
                            child: avatarUrl.isEmpty
                                ? Center(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'C',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: c.primary,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.edit_rounded),
            onPressed: () => _showCreatePostOptionSheet(context),
          ),
        );
      },
    );
  }

  Widget _buildDetailStatColumn(
      AppColorsExtension c, String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: c.textHi,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: c.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Post type list tile (DRY helper) ──

class _PostTypeListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String communityId;
  final String? communityName;
  final String postType;
  final BuildContext sheetCtx;

  const _PostTypeListTile({
    required this.icon,
    required this.label,
    required this.communityId,
    this.communityName,
    required this.postType,
    required this.sheetCtx,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ListTile(
      leading: Icon(icon, color: c.primary),
      title: Text(label,
          style:
              TextStyle(color: c.textHi, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(sheetCtx);
        if (postType == 'poll') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CreatePollScreen(
              communityId: communityId,
              communityName: communityName,
            ),
          ));
        } else if (postType == 'question') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CreateQuestionScreen(
              communityId: communityId,
              communityName: communityName,
            ),
          ));
        } else {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CreatePostScreen(
              communityId: communityId,
              postType: postType,
            ),
          ));
        }
      },
    );
  }
}

// ── Thin vertical divider for stats row ──

class _VerticalDivider extends StatelessWidget {
  final Color color;
  const _VerticalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: VerticalDivider(color: color.withValues(alpha: 0.4), width: 1),
    );
  }
}

// ── Action pill button ──

class _ActionPillButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isOutline;
  final String label;

  const _ActionPillButton({
    required this.onPressed,
    required this.isOutline,
    required this.label,
  });

  @override
  State<_ActionPillButton> createState() => _ActionPillButtonState();
}

class _ActionPillButtonState extends State<_ActionPillButton>
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
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 0.94).animate(
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
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: widget.isOutline
                ? null
                : LinearGradient(
                    colors: [c.primary, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: widget.isOutline
                ? (context.isDarkMode
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.5))
                : null,
            border: widget.isOutline
                ? Border.all(color: c.border, width: 1)
                : null,
            boxShadow: [
              if (!widget.isOutline)
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isOutline ? c.textHi : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fallback banner placeholder ──

class _FallbackBanner extends StatelessWidget {
  final String name;
  const _FallbackBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final tints = [
      LinearGradient(colors: [
        c.primary.withValues(alpha: 0.2),
        Colors.purpleAccent.withValues(alpha: 0.2)
      ]),
      LinearGradient(colors: [
        Colors.blueAccent.withValues(alpha: 0.2),
        Colors.tealAccent.withValues(alpha: 0.2)
      ]),
      LinearGradient(colors: [
        Colors.orangeAccent.withValues(alpha: 0.2),
        Colors.redAccent.withValues(alpha: 0.2)
      ]),
    ];
    final gradient =
        tints[(name.isNotEmpty ? name.codeUnitAt(0) : 0) % tints.length];
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Center(
        child: Opacity(
          opacity: 0.2,
          child:
              Icon(Icons.groups_rounded, size: 48, color: c.primary),
        ),
      ),
    );
  }
}

// ── Admin badge ──

class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: c.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 12, color: c.primary),
          const SizedBox(width: 4),
          Text(
            "You're an admin",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: c.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Staggered fade-slide entry transition ──

class _StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredFadeSlide(
      {required this.index, required this.child});

  @override
  State<_StaggeredFadeSlide> createState() =>
      _StaggeredFadeSlideState();
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
    _opacity =
        Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Stagger delay capped at 300 ms so long lists don't feel sluggish
    final delay =
        Duration(milliseconds: (50 * widget.index).clamp(0, 300));
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
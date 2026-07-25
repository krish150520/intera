import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../core/services/follow_service.dart';
import '../../../core/services/reaction_service.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../messaging/services/messaging_service.dart';
import '../../messaging/screens/chat_screen.dart';
import 'connections_list_screen.dart';
import '../../../core/routes/app_routes.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userAvatar;
  final String? heroTag;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.heroTag,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _messagingService = MessagingService();
  bool _isOpeningChat = false;

  Future<void> _onMessageTap(String currentUid) async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);

    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final myData = myDoc.data() ?? {};
      final myName = myData['name'] ?? 'User';
      final myAvatar = myData['avatarUrl'] ?? '';

      final result = await _messagingService.getOrCreateConversation(
        otherUid: widget.userId,
        myName: myName,
        myAvatar: myAvatar,
        otherName: widget.userName,
        otherAvatar: widget.userAvatar,
      );

      if (!mounted) return;

      if (result.access == ConversationAccess.pending) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send message request?'),
            content: Text(
              '${widget.userName} doesn\'t follow you yet, so this will '
              'be sent as a message request. They\'ll see it once they '
              'accept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Send Request'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isOpeningChat = false);
          return;
        }
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: result.conversationId,
            otherUid: widget.userId,
            otherName: widget.userName,
            otherAvatar: widget.userAvatar,
            initialAccess: result.access,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
      }
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = currentUid == widget.userId;
    final c = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.userName,
          style: TextStyle(
            color: c.textHi,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: c.textHi,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
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
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textHi, size: 16),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, animVal, child) {
          return Opacity(
            opacity: animVal,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - animVal)),
              child: child,
            ),
          );
        },
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return Center(
                child: Text('Error loading profile: ${userSnapshot.error}'),
              );
            }
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: c.primary),
              );
            }

            final userData =
                userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
            final followersCount = userData['followersCount'] ?? 0;
            final followingCount = userData['followingCount'] ?? 0;
            final bio =
                userData['bio'] ??
                'Hey there! I am excited to join the INTERA community. 🚀';

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: context.isDarkMode
                      ? [const Color(0xFF2A2F55), const Color(0xFF171A30), const Color(0xFF171A30)]
                      : const [Color(0xFFE5E7FF), Color(0xFFF8F9FF), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // ── Animated Profile Avatar with Rings ──
                  Center(
                    child: _AnimatedProfileAvatar(
                      userName: widget.userName,
                      imageUrl: widget.userAvatar.isNotEmpty ? widget.userAvatar : null,
                      userId: widget.userId,
                      heroTag: widget.heroTag,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── User Info Section ──
                  Text(
                    widget.userName,
                    style: TextStyle(
                      color: c.textHi,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userData['username'] != null
                        ? (userData['username'] as String).startsWith('@')
                            ? userData['username'] as String
                            : '@${userData['username']}'
                        : '@${widget.userName.toLowerCase().replaceAll(' ', '_')}',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Point / Karma badge
                  Builder(
                    builder: (context) {
                      final String dispType = userData['displayedPointType'] as String? ?? 'karma';
                      final String label;
                      final int val;
                      final IconData icon;
                      final Color valColor;

                      switch (dispType) {
                        case 'beauty':
                          label = 'Radiance';
                          val = (userData['beautyPoints'] as num?)?.toInt() ?? 0;
                          icon = Icons.favorite_rounded;
                          valColor = Colors.pinkAccent;
                          break;
                        case 'art':
                          label = 'Art';
                          val = (userData['artPoints'] as num?)?.toInt() ?? 0;
                          icon = Icons.palette_rounded;
                          valColor = Colors.orangeAccent;
                          break;
                        case 'funny':
                          label = 'Funny';
                          val = (userData['funnyPoints'] as num?)?.toInt() ?? 0;
                          icon = Icons.emoji_emotions_rounded;
                          valColor = Colors.amber;
                          break;
                        case 'karma':
                        default:
                          label = 'Karma';
                          val = (userData['karmaBalance'] as num?)?.toInt() ?? (userData['karmaPoints'] as num?)?.toInt() ?? 0;
                          icon = Icons.bolt_rounded;
                          valColor = AppColors.warningKarma;
                          break;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: valColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: valColor.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: valColor),
                            const SizedBox(width: 4),
                            Text(
                              '$val $label',
                              style: TextStyle(
                                color: valColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Bio
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Action Buttons Row ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: !isMe
                        ? StreamBuilder<bool>(
                            stream: FollowService().isFollowingStream(
                              currentUserId: currentUid,
                              targetUserId: widget.userId,
                            ),
                            builder: (context, followSnapshot) {
                              final isFollowing = followSnapshot.data ?? false;
                              return Row(
                                children: [
                                  Expanded(
                                    child: _ScalePressButton(
                                      onTap: () async {
                                        try {
                                          await FollowService().toggleFollowUser(
                                            currentUserId: currentUid,
                                            targetUserId: widget.userId,
                                            isCurrentlyFollowing: isFollowing,
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Action failed: $e')),
                                          );
                                        }
                                      },
                                      gradientColors: isFollowing ? null : [c.primary, c.primary.withValues(alpha: 0.85)],
                                      isOutline: isFollowing,
                                      child: Center(
                                        child: Text(
                                          isFollowing ? 'Following ✓' : 'Follow',
                                          style: TextStyle(
                                            color: isFollowing ? c.textHi : Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ScalePressButton(
                                      onTap: _isOpeningChat
                                          ? null
                                          : () => _onMessageTap(currentUid),
                                      isOutline: true,
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.chat_bubble_outline_rounded, size: 16, color: c.textHi),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Message',
                                              style: TextStyle(
                                                color: c.textHi,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: _ScalePressButton(
                              onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
                              isOutline: true,
                              child: Center(
                                child: Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    color: c.textHi,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),

                  // ── Stats Section ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn(
                          context,
                          'Posts',
                          FirebaseFirestore.instance
                              .collection('posts')
                              .where('authorId', isEqualTo: widget.userId)
                              .snapshots()
                              .map((s) => s.docs.length),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ConnectionsListScreen(
                                userId: widget.userId,
                                isFollowersMode: true,
                                profileOwnerName: widget.userName,
                              ),
                            ),
                          ),
                          child: _buildStaticStatColumn(
                            context,
                            'Followers',
                            followersCount,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ConnectionsListScreen(
                                userId: widget.userId,
                                isFollowersMode: false,
                                profileOwnerName: widget.userName,
                              ),
                            ),
                          ),
                          child: _buildStaticStatColumn(
                            context,
                            'Following',
                            followingCount,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Accent indicator line under stats
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),

                  // ── Post Feed Section ──
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('authorId', isEqualTo: widget.userId)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, postSnapshot) {
                      if (postSnapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text('Error loading posts: ${postSnapshot.error}'),
                          ),
                        );
                      }
                      if (postSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(color: c.primary),
                          ),
                        );
                      }

                      final postsDocs = postSnapshot.data?.docs ?? [];
                      final filteredDocs = postsDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        String rawType = (data['type'] ?? 'text').toString();
                        if (rawType.contains('.')) rawType = rawType.split('.').last;
                        return rawType != 'question' && rawType != 'achievement';
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 40,
                                  color: c.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No posts shared yet.',
                                  style: TextStyle(color: c.textMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final postItem = Post.fromFirestore(doc, currentUid);

                          return _StaggeredFadeSlide(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: PostCard(
                                post: postItem,
                                heroTag: 'user_profile_post_${postItem.id}',
                                onTap: () => Navigator.of(context).pushNamed(
                                  AppRoutes.postDetail,
                                  arguments: {
                                    'post': postItem,
                                    'heroTag': 'user_profile_post_${postItem.id}',
                                  },
                                ),
                                onReact: (type) {
                                  ReactionService.toggleReaction(
                                    postId: doc.id,
                                    postAuthorId: postItem.authorId,
                                    postTitle: postItem.title,
                                    currentUid: currentUid,
                                    reactionType: type,
                                  );
                                },
                                onComment: () => Navigator.of(context).pushNamed(
                                  AppRoutes.postDetail,
                                  arguments: {
                                    'post': postItem,
                                    'heroTag': 'user_profile_post_${postItem.id}',
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),);
          },
        ),
      ),
    );
  }

  Widget _buildStaticStatColumn(BuildContext context, String label, int value) {
    final c = context.appColors;
    String formattedVal = value.toString();
    if (value >= 1000) {
      formattedVal = '${(value / 1000).toStringAsFixed(1)}K';
      if (formattedVal.endsWith('.0K')) {
        formattedVal = '${(value ~/ 1000)}K';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formattedVal,
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
              fontSize: 12,
              color: c.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    Stream<int> countStream,
  ) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return _buildStaticStatColumn(context, label, count);
      },
    );
  }
}

// ── Animated Profile Avatar with concentric pulsing rings ──

class _AnimatedProfileAvatar extends StatefulWidget {
  final String userName;
  final String? imageUrl;
  final String userId;
  final String? heroTag;

  const _AnimatedProfileAvatar({
    required this.userName,
    this.imageUrl,
    required this.userId,
    this.heroTag,
  });

  @override
  State<_AnimatedProfileAvatar> createState() => _AnimatedProfileAvatarState();
}

class _AnimatedProfileAvatarState extends State<_AnimatedProfileAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulseValue = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ring 3
            Container(
              width: 170 + (pulseValue * 15),
              height: 170 + (pulseValue * 15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: 0.02),
                border: Border.all(
                  color: c.primary.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
            ),
            // Outer Ring 2
            Container(
              width: 145 + (pulseValue * 10),
              height: 145 + (pulseValue * 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: 0.04),
                border: Border.all(
                  color: c.primary.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            // Outer Ring 1
            Container(
              width: 120 + (pulseValue * 5),
              height: 120 + (pulseValue * 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: 0.06),
                border: Border.all(
                  color: c.primary.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
            ),
            // Avatar wrapper with glow shadow
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: c.border,
                child: CustomAvatar(
                  name: widget.userName,
                  imageUrl: widget.imageUrl,
                  userId: widget.userId,
                  radius: 44,
                  heroTag: widget.heroTag,
                  clickable: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Custom Animated Press Scale Button ──

class _ScalePressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isOutline;
  final List<Color>? gradientColors;

  const _ScalePressButton({
    required this.child,
    this.onTap,
    this.isOutline = false,
    this.gradientColors,
  });

  @override
  State<_ScalePressButton> createState() => _ScalePressButtonState();
}

class _ScalePressButtonState extends State<_ScalePressButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
      onTapDown: widget.onTap == null ? null : (_) => _controller.forward(),
      onTapUp: widget.onTap == null ? null : (_) => _controller.reverse(),
      onTapCancel: widget.onTap == null ? null : () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: !widget.isOutline && widget.gradientColors != null
                ? LinearGradient(
                    colors: widget.gradientColors!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isOutline ? c.surface : (widget.gradientColors == null ? c.primary : null),
            border: widget.isOutline
                ? Border.all(color: c.border, width: 1.2)
                : Border.all(color: Colors.transparent, width: 0),
            boxShadow: [
              if (!widget.isOutline && widget.onTap != null)
                BoxShadow(
                  color: (widget.gradientColors?.first ?? c.primary).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: widget.child,
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

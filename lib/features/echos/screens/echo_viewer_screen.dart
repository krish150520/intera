import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../core/services/reaction_service.dart';
import '../../../core/services/notification_service.dart';

class EchoViewerScreen extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;

  const EchoViewerScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<EchoViewerScreen> createState() => _EchoViewerScreenState();
}

class _EchoViewerScreenState extends State<EchoViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No Echos found.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          final isActive = index == _currentIndex;
          return _EchoPlayerItem(
            post: post,
            isActive: isActive,
            onBack: () => Navigator.of(context).pop(),
          );
        },
      ),
    );
  }
}

class _EchoPlayerItem extends StatefulWidget {
  final Post post;
  final bool isActive;
  final VoidCallback onBack;

  const _EchoPlayerItem({
    required this.post,
    required this.isActive,
    required this.onBack,
  });

  @override
  State<_EchoPlayerItem> createState() => _EchoPlayerItemState();
}

class _EchoPlayerItemState extends State<_EchoPlayerItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showHeartAnimation = false;

  // Single tap play/pause overlay animation
  bool _showPlayOverlay = false;
  IconData _overlayIcon = Icons.play_arrow_rounded;

  // Real-time reactions
  int _likeCount = 0;
  bool _isLiked = false;

  late final AnimationController _heartAnimController;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _isLiked = widget.post.isLiked || widget.post.reactions.containsKey(myUid);

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heartScale = CurvedAnimation(
      parent: _heartAnimController,
      curve: Curves.elasticOut,
    );

    if (widget.isActive) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(covariant _EchoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initVideo();
    } else if (!widget.isActive && oldWidget.isActive) {
      _pauseVideo();
    }
  }

  Future<void> _initVideo() async {
    if (_controller != null) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
      return;
    }

    if (widget.post.imageUrl == null || widget.post.imageUrl!.isEmpty) return;

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.post.imageUrl!),
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isPlaying = true;
      });
      _controller!.setLooping(true);
      _controller!.play();
    } catch (e) {
      print('[EchoPlayer] Error initializing video: $e');
    }
  }

  void _pauseVideo() {
    _controller?.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _heartAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;
    HapticFeedback.lightImpact();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
        _overlayIcon = Icons.pause_rounded;
        _showPlayOverlay = true;
      });
    } else {
      _controller!.play();
      setState(() {
        _isPlaying = true;
        _overlayIcon = Icons.play_arrow_rounded;
        _showPlayOverlay = true;
      });
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showPlayOverlay = false;
        });
      }
    });
  }

  void _handleDoubleTap() async {
    if (_showHeartAnimation) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _showHeartAnimation = true;
    });
    _heartAnimController.forward(from: 0.0);

    // If not liked already, toggle like
    if (!_isLiked) {
      _toggleLike();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
      }
    });
  }

  void _toggleLike() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
      }
    });

    try {
      await ReactionService.toggleReaction(
        postId: widget.post.id,
        postAuthorId: widget.post.authorId,
        postTitle: widget.post.title,
        currentUid: myUid,
        reactionType: 'like',
      );
    } catch (e) {
      // Revert if error
      if (mounted) {
        setState(() {
          if (_isLiked) {
            _isLiked = false;
            _likeCount--;
          } else {
            _isLiked = true;
            _likeCount++;
          }
        });
      }
    }
  }

  void _openCommentsSheet() {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EchoCommentsSheet(postId: widget.post.id),
    );
  }

  void _sharePost() {
    Clipboard.setData(
      ClipboardData(
        text: 'Watch this Echo by ${widget.post.authorUsername} on INTERA:\n\n"${widget.post.title}"\n${widget.post.body}',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Echo link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final c = context.appColors;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Video Layer ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTap: _handleDoubleTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: _isInitialized && _controller != null
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
          ),
        ),

        // ── Vignette Gradients ───────────────────────────────────────────────
        // Top shadow
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom shadow
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 220,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),

        // ── Navigation Header (Top Left) ─────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: widget.onBack,
              ),
              const Text(
                'Echos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        // ── Overlay Controls (Bottom Left Information) ───────────────────────
        Positioned(
          left: 14,
          bottom: 24,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info row
              Row(
                children: [
                  CustomAvatar(
                    name: widget.post.authorName,
                    imageUrl: widget.post.authorAvatarUrl,
                    userId: widget.post.authorId,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.post.authorUsername,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Caption details
              if (widget.post.title.isNotEmpty)
                Text(
                  widget.post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (widget.post.body.isNotEmpty && widget.post.body.trim() != widget.post.title.trim()) ...[
                const SizedBox(height: 4),
                Text(
                  widget.post.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Action Buttons Sidebar (Right Side) ──────────────────────────────
        Positioned(
          right: 14,
          bottom: 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Karma / Like button
              _SidebarAction(
                icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: _isLiked ? const Color(0xFFEF4444) : Colors.white,
                label: '$_likeCount',
                onTap: _toggleLike,
              ),
              const SizedBox(height: 20),

              // Comments button
              _SidebarAction(
                icon: Icons.mode_comment_outlined,
                iconColor: Colors.white,
                label: '${widget.post.commentCount}',
                onTap: _openCommentsSheet,
              ),
              const SizedBox(height: 20),

              // Share button
              _SidebarAction(
                icon: Icons.share_rounded,
                iconColor: Colors.white,
                label: 'Share',
                onTap: _sharePost,
              ),
              const SizedBox(height: 30),

              // Spinning record disc simulation
              _SpinningDisc(avatarUrl: widget.post.authorAvatarUrl),
            ],
          ),
        ),

        // ── Single Tap Play/Pause Feedback ──────────────────────────────────
        if (_showPlayOverlay)
          Center(
            child: AnimatedOpacity(
              opacity: _showPlayOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(_overlayIcon, color: Colors.white, size: 36),
              ),
            ),
          ),

        // ── Double Tap Like Heart Animation ──────────────────────────────────
        if (_showHeartAnimation)
          Center(
            child: ScaleTransition(
              scale: _heartScale,
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFEF4444),
                size: 110,
                shadows: [
                  Shadow(
                    blurRadius: 16,
                    color: Colors.black45,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SidebarAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SidebarAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinningDisc extends StatefulWidget {
  final String? avatarUrl;
  const _SpinningDisc({this.avatarUrl});

  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _anim,
      child: Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [Colors.black, Colors.grey, Colors.black],
          ),
        ),
        child: ClipOval(
          child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
              ? Image.network(
                  widget.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.music_note_rounded, color: Colors.white, size: 14),
                )
              : const Icon(Icons.music_note_rounded, color: Colors.white, size: 14),
        ),
      ),
    );
  }
}

class _EchoCommentsSheet extends StatefulWidget {
  final String postId;
  const _EchoCommentsSheet({required this.postId});

  @override
  State<_EchoCommentsSheet> createState() => _EchoCommentsSheetState();
}

class _EchoCommentsSheetState extends State<_EchoCommentsSheet> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null) return;

    setState(() => _isSending = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final ud = userDoc.data() ?? {};

      final username = ud['username'] != null
          ? (ud['username'] as String).startsWith('@')
              ? ud['username'] as String
              : '@${ud['username']}'
          : '@${user.email?.split('@')[0] ?? 'user'}';
      final displayName = ud['name'] ?? user.displayName ?? 'Anonymous';

      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final commentRef = postRef.collection('comments').doc();

      final batch = FirebaseFirestore.instance.batch();
      batch.set(commentRef, {
        'authorId': user.uid,
        'authorName': displayName,
        'authorUsername': username,
        'authorAvatar': user.photoURL ?? '',
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(postRef, {'commentCount': FieldValue.increment(1)});
      await batch.commit();

      // Trigger comment notification
      try {
        final postSnap = await postRef.get();
        final postData = postSnap.data() ?? {};
        final recipientId = postData['authorId'] as String?;
        if (recipientId != null) {
          await NotificationService.sendNotification(
            recipientId: recipientId,
            type: 'comment',
            title: '$displayName commented on your Echo',
            subtitle: text,
            relatedId: widget.postId,
          );
        }
      } catch (_) {}

      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final paddingBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: paddingBottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            // Header handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: c.textHi,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // List of comments
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Error: ${snap.error}', style: const TextStyle(fontSize: 12)),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 36, color: c.border),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to share your thoughts!',
                            style: TextStyle(color: c.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final authorName = data['authorName'] ?? 'Anonymous';
                      final authorUsername = data['authorUsername'] ?? '@user';
                      final content = data['content'] ?? '';
                      final avatar = data['authorAvatar'] as String?;
                      final authorId = data['authorId'] as String?;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomAvatar(
                            name: authorName,
                            imageUrl: avatar,
                            userId: authorId,
                            radius: 15,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      authorName,
                                      style: TextStyle(
                                        color: c.textHi,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      authorUsername,
                                      style: TextStyle(
                                        color: c.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  content,
                                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Comment textfield at bottom
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: c.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.field,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.border, width: 0.8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _commentController,
                        style: TextStyle(color: c.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Share your feedback...',
                          hintStyle: TextStyle(color: c.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _submitComment,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                    ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../widgets/post_card.dart';
import '../../../core/karma/karma_service.dart';
import '../../../core/karma/karma_badge.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/reaction_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post? post;
  const PostDetailScreen({super.key, this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isHelpPost   => widget.post?.type == PostType.helpRequest;
  bool get _isPostAuthor => widget.post?.authorId == _myUid;

  bool get _hasMedia =>
      (widget.post?.imageUrl != null && widget.post!.imageUrl!.isNotEmpty) ||
      widget.post?.type == PostType.video;

  bool get _isVideo => widget.post?.type == PostType.video;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Submit comment ─────────────────────────────────────────────────────────

  void _submitComment() async {
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final post = widget.post;
    if (text.isEmpty || post == null || user == null) return;

    setState(() => _isSending = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final ud = userDoc.data() ?? {};

      final username = ud['username'] != null
          ? (ud['username'] as String).startsWith('@')
              ? ud['username'] as String
              : '@${ud['username']}'
          : '@${user.email?.split('@')[0] ?? 'user'}';
      final displayName = ud['name'] ?? user.displayName ?? 'Anonymous';

      final postRef    = FirebaseFirestore.instance.collection('posts').doc(post.id);
      final commentRef = postRef.collection('comments').doc();
      final batch      = FirebaseFirestore.instance.batch();

      batch.set(commentRef, {
        'authorId':       user.uid,
        'authorName':     displayName,
        'authorUsername': username,
        'authorAvatar':   user.photoURL ?? '',
        'content':        text,
        'createdAt':      FieldValue.serverTimestamp(),
      });
      batch.update(postRef, {'commentCount': FieldValue.increment(1)});
      await batch.commit();

      // Trigger comment notification
      try {
        await NotificationService.sendNotification(
          recipientId: post.authorId,
          type: 'comment',
          title: '$displayName commented on your post',
          subtitle: text,
          relatedId: post.id,
        );
      } catch (e) {
        print('Error sending comment notification: $e');
      }

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not publish comment: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Award best answer ──────────────────────────────────────────────────────

  Future<void> _awardBestAnswer({
    required String commentId,
    required String answererUid,
    required String answererName,
    required int reward,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Best Answer?'),
        content: Text(
          'This will award $reward ⚡ karma to $answererName and close the help request.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.appColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Award karma',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await KarmaService.awardBestAnswer(
        postId:       widget.post!.id,
        winnerUid:    answererUid,
        commentId:    commentId,
        rewardAmount: reward,
      );
      
      // Trigger best answer notification
      try {
        String senderName = 'Someone';
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_myUid)
            .get();
        if (userDoc.exists) {
          senderName = userDoc.data()?['name'] ?? 'Someone';
        }
        await NotificationService.sendNotification(
          recipientId: answererUid,
          type: 'karma',
          title: 'Best answer awarded! ⚡',
          subtitle: 'You received $reward karma from $senderName',
          relatedId: widget.post!.id,
        );
      } catch (e) {
        print('Error sending best answer notification: $e');
      }

      if (!mounted) return;
      _showSnack('🎉 $reward karma awarded to $answererName!');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _handleReaction(String type) async {
    final post = widget.post;
    if (post == null || _myUid.isEmpty) return;
    await ReactionService.toggleReaction(
      postId: post.id,
      postAuthorId: post.authorId,
      postTitle: post.title,
      currentUid: _myUid,
      reactionType: type,
    );
  }

  // ── Tip dialog ─────────────────────────────────────────────────────────────

  Future<void> _showTipDialog({
    required String toUid,
    required String toName,
    required String postId,
    String? commentId,
  }) async {
    final ctrl       = TextEditingController();
    final myBalance  = await KarmaService.getBalance(_myUid);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TipSheet(
        toName:    toName,
        myBalance: myBalance,
        onSend: (amount) async {
          Navigator.of(context).pop();
          try {
            await KarmaService.tipUser(
              toUid:     toUid,
              toName:    toName,
              amount:    amount,
              postId:    postId,
              commentId: commentId,
            );
            
            // Trigger tip notification
            try {
              String senderName = 'Someone';
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_myUid)
                  .get();
              if (userDoc.exists) {
                senderName = userDoc.data()?['name'] ?? 'Someone';
              }
              await NotificationService.sendNotification(
                recipientId: toUid,
                type: 'karma',
                title: 'Received a tip! ⚡',
                subtitle: 'You received $amount karma from $senderName',
                relatedId: postId,
              );
            } catch (e) {
              print('Error sending tip notification: $e');
            }

            if (!mounted) return;
            _showSnack('⚡ $amount karma tipped to $toName!');
          } catch (e) {
            if (!mounted) return;
            _showSnack('$e', isError: true);
          }
        },
      ),
    );
    ctrl.dispose();
  }

  // ── Open fullscreen viewer ─────────────────────────────────────────────────

  void _openFullscreen() {
    final post = widget.post;
    if (post == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenMediaViewer(
          mediaUrl:    post.imageUrl ?? '',
          isVideo:     _isVideo,
          authorName:  post.authorName,
          authorUsername: post.authorUsername,
          avatarUrl:   post.authorAvatarUrl,
          caption:     post.body,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      extendBodyBehindAppBar: _hasMedia,
      appBar: _hasMedia
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
              systemOverlayStyle: SystemUiOverlayStyle.light,
            )
          : AppBar(
              title: Text('Discussion',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c.textHi)),
              backgroundColor: c.surface,
              foregroundColor: c.textHi,
              elevation: 0.5,
              leading: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: c.field, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: c.primary),
                ),
              ),
            ),
      body: post == null
          ? const Center(child: Text('Post context missing.'))
          : Column(children: [
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(post.id)
                      .snapshots(),
                  builder: (context, postSnap) {
                    final postData =
                        postSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final isCompleted = postData['isCompleted'] == true;
                    final bestCmtId   = postData['bestAnswerCommentId'] as String?;
                    final reward      = (postData['rewardKarma'] as num?)?.toInt() ?? 0;

                    final realTimePost = postSnap.hasData && postSnap.data!.exists
                        ? Post.fromFirestore(postSnap.data!, _myUid)
                        : post;

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(post.id)
                          .collection('comments')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snap) {
                        final commentDocs = snap.data?.docs ?? [];

                        return CustomScrollView(slivers: [
                          // ── Full-width media hero ────────────────────────
                          if (_hasMedia)
                            SliverToBoxAdapter(
                              child: _MediaHero(
                                mediaUrl: realTimePost.imageUrl ?? '',
                                isVideo:  _isVideo,
                                onExpand: _openFullscreen,
                              ),
                            ),

                          // ── Post card (no media shown inside it now) ─────
                          SliverToBoxAdapter(
                            child: _hasMedia
                                ? _PostBodyCard(post: realTimePost)
                                : PostCard(
                                    post: realTimePost,
                                    onReact: _handleReaction,
                                  ),
                          ),

                          // ── Help banner ──────────────────────────────────
                          if (_isHelpPost)
                            SliverToBoxAdapter(
                              child: _HelpBanner(
                                isCompleted: isCompleted,
                                reward: reward,
                              ),
                            ),

                          // ── Comments header ──────────────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                              child: Text(
                                'Comments (${commentDocs.length})',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: c.textHi),
                              ),
                            ),
                          ),

                          // ── Loading / empty ──────────────────────────────
                          if (snap.connectionState == ConnectionState.waiting)
                            SliverToBoxAdapter(
                              child: Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: CircularProgressIndicator(color: c.primary))),
                            )
                          else if (commentDocs.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 48, horizontal: 16),
                                  child: Center(
                                    child: Text(
                                      'No responses yet. Start the conversation!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: c.textMuted,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                              )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final data =
                                      commentDocs[i].data() as Map<String, dynamic>;
                                  final cmtId = commentDocs[i].id;
                                  final isBest = cmtId == bestCmtId;

                                  return Column(children: [
                                    _CommentTile(
                                      commentId:    cmtId,
                                      data:         data,
                                      isBestAnswer: isBest,
                                      showAwardBtn: _isHelpPost &&
                                          !isCompleted &&
                                          _isPostAuthor &&
                                          data['authorId'] != _myUid,
                                      showTipBtn: data['authorId'] != _myUid &&
                                          _myUid.isNotEmpty,
                                      onAward: () => _awardBestAnswer(
                                        commentId:    cmtId,
                                        answererUid:  data['authorId'] ?? '',
                                        answererName: data['authorName'] ?? 'User',
                                        reward:       reward,
                                      ),
                                      onTip: () => _showTipDialog(
                                        toUid:     data['authorId'] ?? '',
                                        toName:    data['authorName'] ?? 'User',
                                        postId:    post.id,
                                        commentId: cmtId,
                                      ),
                                    ),
                                    if (i < commentDocs.length - 1)
                                      Divider(
                                          color: c.border,
                                          height: 1,
                                          indent: 16,
                                          endIndent: 16),
                                  ]);
                                },
                                childCount: commentDocs.length,
                              ),
                            ),

                          // bottom padding
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 16)),
                        ]);
                      },
                    );
                  },
                ),
              ),

              // ── Comment input ──────────────────────────────────────────────
              _CommentInput(
                controller:    _commentController,
                isSending:     _isSending,
                userAvatarUrl: FirebaseAuth.instance.currentUser?.photoURL,
                onSend:        _submitComment,
              ),
            ]),
    );
  }
}

// ── Full-width media hero ─────────────────────────────────────────────────────

class _MediaHero extends StatelessWidget {
  final String mediaUrl;
  final bool isVideo;
  final VoidCallback onExpand;

  const _MediaHero({
    required this.mediaUrl,
    required this.isVideo,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Stack(
      children: [
        // Media surface
        SizedBox(
          width: double.infinity,
          height: 280,
          child: isVideo
              ? _VideoThumbnail(videoUrl: mediaUrl)
              : (mediaUrl.isNotEmpty
                  ? Image.network(
                      mediaUrl,
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderMedia(),
                    )
                  : _PlaceholderMedia()),
        ),

        // Gradient overlay (bottom fade into white for text blending)
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, c.bg],
              ),
            ),
          ),
        ),

        // Type badge (top-right)
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                isVideo ? 'Video' : 'Image',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ),

        // Expand button (bottom-right)
        Positioned(
          bottom: 16,
          right: 12,
          child: GestureDetector(
            onTap: onExpand,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderMedia extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,
      color: context.appColors.primary,
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white30, size: 48),
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  const _VideoThumbnail({required this.videoUrl});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          if (mounted) setState(() => _initialized = true);
        });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized && _ctrl != null) {
      return AspectRatio(
        aspectRatio: _ctrl!.value.aspectRatio,
        child: VideoPlayer(_ctrl!),
      );
    }
    return Container(
      width: double.infinity,
      height: 280,
      color: context.appColors.bg,
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded,
            color: Colors.white54, size: 56),
      ),
    );
  }
}

// ── Post body card (used when media hero is shown above PostCard) ─────────────

class _PostBodyCard extends StatelessWidget {
  final Post post;
  const _PostBodyCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Author row
        Row(children: [
          CustomAvatar(
            name: post.authorName,
            radius: 17,
            imageUrl: post.authorAvatarUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.authorName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: c.textHi)),
                Text(post.authorUsername,
                    style: TextStyle(
                        fontSize: 11, color: c.textMuted)),
              ],
            ),
          ),
          KarmaBadge(uid: post.authorId, size: KarmaBadgeSize.small),
        ]),
        const SizedBox(height: 12),
        if (post.title.isNotEmpty) ...[
          Text(post.title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: c.textHi)),
          const SizedBox(height: 6),
        ],
        if (post.body.isNotEmpty)
          Text(post.body,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: c.textSecondary)),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── Fullscreen media viewer ───────────────────────────────────────────────────

class _FullscreenMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;
  final String authorName;
  final String authorUsername;
  final String? avatarUrl;
  final String caption;

  const _FullscreenMediaViewer({
    required this.mediaUrl,
    required this.isVideo,
    required this.authorName,
    required this.authorUsername,
    this.avatarUrl,
    required this.caption,
  });

  @override
  State<_FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<_FullscreenMediaViewer> {
  VideoPlayerController? _videoCtrl;
  bool _videoInitialized = false;
  bool _playing = false;
  bool _uiVisible = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.isVideo && widget.mediaUrl.isNotEmpty) {
      _videoCtrl =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
            ..initialize().then((_) {
              if (mounted) {
                setState(() {
                  _videoInitialized = true;
                  _playing = true;
                });
                _videoCtrl!.play();
              }
            });
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_videoCtrl == null) return;
    setState(() {
      _playing = !_playing;
      _playing ? _videoCtrl!.play() : _videoCtrl!.pause();
    });
  }

  void _toggleUI() => setState(() => _uiVisible = !_uiVisible);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Media content ──────────────────────────────────────────────
            Center(
              child: widget.isVideo
                  ? (_videoInitialized && _videoCtrl != null
                      ? AspectRatio(
                          aspectRatio: _videoCtrl!.value.aspectRatio,
                          child: VideoPlayer(_videoCtrl!),
                        )
                      : const CircularProgressIndicator(
                          color: Colors.white))
                  : (widget.mediaUrl.isNotEmpty
                      ? InteractiveViewer(
                          child: Image.network(
                            widget.mediaUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white38,
                                size: 64),
                          ),
                        )
                      : const Icon(Icons.image_outlined,
                          color: Colors.white38, size: 64)),
            ),

            // ── Video play/pause overlay ───────────────────────────────────
            if (widget.isVideo && _videoInitialized)
              AnimatedOpacity(
                opacity: _uiVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Top bar (close + more) ─────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: AnimatedOpacity(
                opacity: _uiVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      12, MediaQuery.of(context).padding.top + 8, 12, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: Row(children: [
                    _GlassButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    _GlassButton(
                      icon: Icons.download_rounded,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.mediaUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Media link saved to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _GlassButton(
                      icon: Icons.share_rounded,
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                            text: 'Check out this media on INTERA: ${widget.mediaUrl}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Media share link copied!'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ),

            // ── Bottom caption + author ────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: AnimatedOpacity(
                opacity: _uiVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 32, 16,
                      MediaQuery.of(context).padding.bottom + 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xDD000000), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Author
                      Row(children: [
                        CustomAvatar(
                          name: widget.authorName,
                          radius: 16,
                          imageUrl: widget.avatarUrl,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.authorName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            Text(widget.authorUsername,
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11)),
                          ],
                        ),
                      ]),
                      if (widget.caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.caption,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}

// ── Help banner ───────────────────────────────────────────────────────────────

class _HelpBanner extends StatelessWidget {
  final bool isCompleted;
  final int reward;
  const _HelpBanner({required this.isCompleted, required this.reward});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCompleted
            ? c.successBg
            : c.warningKarmaBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? c.successBorder
              : c.warningKarmaBorder,
        ),
      ),
      child: Row(children: [
        Icon(
          isCompleted
              ? Icons.check_circle_rounded
              : Icons.handshake_outlined,
          color: isCompleted
              ? c.success
              : c.warningKarma,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isCompleted
                ? 'Resolved — karma has been awarded ✓'
                : 'Open help request · $reward ⚡ karma reward',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isCompleted
                  ? c.success
                  : c.warningKarma,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Comment tile ──────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final String commentId;
  final Map<String, dynamic> data;
  final bool isBestAnswer;
  final bool showAwardBtn;
  final bool showTipBtn;
  final VoidCallback onAward;
  final VoidCallback onTip;

  const _CommentTile({
    required this.commentId,
    required this.data,
    required this.isBestAnswer,
    required this.showAwardBtn,
    required this.showTipBtn,
    required this.onAward,
    required this.onTip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final name     = data['authorName']     as String? ?? 'Anonymous';
    final username = data['authorUsername'] as String? ?? '@user';
    final content  = data['content']        as String? ?? '';
    final avatar   = data['authorAvatar']   as String? ?? '';
    final authorId = data['authorId']       as String? ?? '';

    return Container(
      color: isBestAnswer
          ? c.successBg
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CustomAvatar(
              name: name,
              radius: 16,
              imageUrl: avatar.isNotEmpty ? avatar : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: c.textHi)),
                  const SizedBox(width: 6),
                  Text(username,
                      style: TextStyle(
                          fontSize: 11, color: c.textMuted)),
                  if (isBestAnswer) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Best answer',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(content,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: c.textPrimary)),
                const SizedBox(height: 8),
                Row(children: [
                  if (showAwardBtn)
                    _ActionChip(
                      icon:  Icons.emoji_events_rounded,
                      label: 'Best answer',
                      color: c.success,
                      bg:    c.successBg,
                      onTap: onAward,
                    ),
                  if (showAwardBtn) const SizedBox(width: 8),
                  if (showTipBtn)
                    _ActionChip(
                      icon:  Icons.bolt_rounded,
                      label: 'Tip',
                      color: c.warningKarma,
                      bg:    c.warningKarmaBg,
                      onTap: onTip,
                    ),
                  const Spacer(),
                  if (authorId.isNotEmpty)
                    KarmaBadge(uid: authorId, size: KarmaBadgeSize.small),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );
  }
}

// ── Tip bottom sheet ──────────────────────────────────────────────────────────

class _TipSheet extends StatefulWidget {
  final String toName;
  final int myBalance;
  final void Function(int amount) onSend;

  const _TipSheet({
    required this.toName,
    required this.myBalance,
    required this.onSend,
  });

  @override
  State<_TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<_TipSheet> {
  final _ctrl = TextEditingController();
  int _amount = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _amount > 0 && _amount <= widget.myBalance;
    final c = context.appColors;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        Text('Tip ${widget.toName}',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textHi)),
        const SizedBox(height: 4),
        Text('Your balance: ${widget.myBalance} ⚡',
            style: TextStyle(
                fontSize: 12, color: c.textMuted)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final amt in [5, 10, 25, 50])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _amount = amt);
                  _ctrl.text = '$amt';
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _amount == amt
                        ? c.primary
                        : c.field,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _amount == amt
                          ? c.primary
                          : c.chipBorder,
                    ),
                  ),
                  child: Text('$amt ⚡',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _amount == amt
                              ? Colors.white
                              : c.primary)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          onChanged: (v) => setState(() => _amount = int.tryParse(v) ?? 0),
          style: TextStyle(color: c.textHi),
          decoration: InputDecoration(
            hintText: 'Or enter custom amount',
            hintStyle: TextStyle(color: c.textMuted),
            filled: true,
            fillColor: c.field,
            prefixIcon: Icon(Icons.bolt_rounded,
                color: c.warningKarma, size: 18),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: c.border, width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: c.border, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: c.primary, width: 1.5)),
          ),
        ),
        if (_amount > widget.myBalance && _amount > 0) ...[
          const SizedBox(height: 8),
          const Text('Not enough karma',
              style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isValid ? () => widget.onSend(_amount) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              disabledBackgroundColor: c.border,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.bolt_rounded,
                color: Colors.white, size: 18),
            label: Text(
              isValid
                  ? 'Send $_amount karma to ${widget.toName}'
                  : 'Enter an amount',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Comment input ─────────────────────────────────────────────────────────────

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final String? userAvatarUrl;
  final VoidCallback onSend;

  const _CommentInput({
    required this.controller,
    required this.isSending,
    this.userAvatarUrl,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, -3),
              blurRadius: 4),
        ],
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(children: [
        CustomAvatar(name: 'You', radius: 16, imageUrl: userAvatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.field,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: c.textHi),
              decoration: InputDecoration(
                hintText: 'Add to the discussion...',
                hintStyle: TextStyle(fontSize: 13, color: c.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        isSending
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)),
              )
            : IconButton(
                icon: Icon(Icons.send_rounded,
                    color: c.primary),
                onPressed: onSend,
              ),
      ]),
    );
  }
}
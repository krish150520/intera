import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../shared/widgets/live_username.dart';
import '../widgets/post_card.dart';
import '../../../core/karma/karma_service.dart';
import '../../../core/karma/karma_badge.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/reaction_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post? post;
  final String? heroTag;
  const PostDetailScreen({super.key, this.post, this.heroTag});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _isSending = false;

  String? _replyingToCommentId;
  String? _replyingToUsername;

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
    _commentFocusNode.dispose();
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

      final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);

      if (_replyingToCommentId != null) {
        final commentRef = postRef.collection('comments').doc(_replyingToCommentId);
        final batch = FirebaseFirestore.instance.batch();

        final replyData = {
          'id': FirebaseFirestore.instance.collection('posts').doc().id,
          'authorId': user.uid,
          'authorName': displayName,
          'authorUsername': username,
          'authorAvatar': user.photoURL ?? '',
          'content': text,
          'createdAt': DateTime.now().toIso8601String(),
        };

        batch.update(commentRef, {
          'replies': FieldValue.arrayUnion([replyData]),
        });
        batch.update(postRef, {'commentCount': FieldValue.increment(1)});
        await batch.commit();

        try {
          await NotificationService.sendNotification(
            recipientId: post.authorId,
            type: 'comment',
            title: '$displayName replied to a comment on your post',
            subtitle: text,
            relatedId: post.id,
          );
        } catch (e) {
          debugPrint('Error sending reply notification: $e');
        }

        setState(() {
          _replyingToCommentId = null;
          _replyingToUsername = null;
        });
      } else {
        final commentRef = postRef.collection('comments').doc();
        final batch      = FirebaseFirestore.instance.batch();

        batch.set(commentRef, {
          'authorId':       user.uid,
          'authorName':     displayName,
          'authorUsername': username,
          'authorAvatar':   user.photoURL ?? '',
          'content':        text,
          'createdAt':      FieldValue.serverTimestamp(),
          'likeCount':      0,
          'likedBy':        [],
          'replies':        [],
        });
        batch.update(postRef, {'commentCount': FieldValue.increment(1)});
        await batch.commit();

        try {
          await NotificationService.sendNotification(
            recipientId: post.authorId,
            type: 'comment',
            title: '$displayName commented on your post',
            subtitle: text,
            relatedId: post.id,
          );
        } catch (e) {
          debugPrint('Error sending comment notification: $e');
        }
      }

      _commentController.clear();
      _commentFocusNode.unfocus();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not publish comment: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _toggleLikeComment(String commentId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final post = widget.post;
    if (post == null) return;

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(post.id)
        .collection('comments')
        .doc(commentId);

    final List likedBy = data['likedBy'] ?? [];
    final isLiked = likedBy.contains(user.uid);

    try {
      if (isLiked) {
        await commentRef.update({
          'likedBy': FieldValue.arrayRemove([user.uid]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await commentRef.update({
          'likedBy': FieldValue.arrayUnion([user.uid]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
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
        debugPrint('Error sending best answer notification: $e');
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
              debugPrint('Error sending tip notification: $e');
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

  void _deletePost() async {
    final post = widget.post;
    if (post == null) return;
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? c.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Post?', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? c.textHi : const Color(0xFF1E293B), fontSize: 16)),
        content: const Text('Are you sure you want to permanently delete this post? This cannot be undone.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: isDark ? c.textMuted : const Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingCtx) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                // Force refresh ID token to ensure it is fresh and sent with the callable request
                await FirebaseAuth.instance.currentUser?.getIdToken(true);

                await FirebaseFunctions.instanceFor(region: 'us-central1')
                    .httpsCallable('deletePost')
                    .call({'postId': post.id});

                if (mounted) {
                  Navigator.pop(context); // Dismiss loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post deleted successfully.'), behavior: SnackBarBehavior.floating),
                  );
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Dismiss loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _deleteComment(String commentId) async {
    final post = widget.post;
    if (post == null) return;
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? c.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Comment?', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? c.textHi : const Color(0xFF1E293B), fontSize: 16)),
        content: const Text('Are you sure you want to delete this comment?', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: isDark ? c.textMuted : const Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
                final batch = FirebaseFirestore.instance.batch();
                batch.delete(postRef.collection('comments').doc(commentId));
                batch.update(postRef, {'commentCount': FieldValue.increment(-1)});
                await batch.commit();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment deleted.'), behavior: SnackBarBehavior.floating),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete comment: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _deleteReply(String commentId, Map<String, dynamic> replyMap) async {
    final post = widget.post;
    if (post == null) return;
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? c.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Reply?', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? c.textHi : const Color(0xFF1E293B), fontSize: 16)),
        content: const Text('Are you sure you want to delete this reply?', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: isDark ? c.textMuted : const Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
                final batch = FirebaseFirestore.instance.batch();
                batch.update(postRef.collection('comments').doc(commentId), {
                  'replies': FieldValue.arrayRemove([replyMap]),
                });
                batch.update(postRef, {'commentCount': FieldValue.increment(-1)});
                await batch.commit();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply deleted.'), behavior: SnackBarBehavior.floating),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete reply: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Open fullscreen viewer ─────────────────────────────────────────────────

  void _openFullscreen(Post post) {
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
          authorId:    post.authorId,
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
              actions: [
                if (_isPostAuthor || widget.post?.realAuthorId == _myUid)
                  GestureDetector(
                    onTap: _deletePost,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.redAccent),
                    ),
                  ),
              ],
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
              actions: [
                if (_isPostAuthor || widget.post?.realAuthorId == _myUid)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: _deletePost,
                  ),
              ],
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
                                postId: realTimePost.id,
                                mediaUrl: realTimePost.imageUrl ?? '',
                                videoThumbnailUrl: realTimePost.videoThumbnailUrl,
                                isVideo:  _isVideo,
                                isPostAuthor: _isPostAuthor,
                                onExpand: () => _openFullscreen(realTimePost),
                                heroTag: widget.heroTag,
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
                                      canDelete: data['authorId'] == _myUid || _isPostAuthor || realTimePost.realAuthorId == _myUid,
                                      onDelete: () => _deleteComment(cmtId),
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
                                      onLike: () => _toggleLikeComment(cmtId, data),
                                      onReply: () {
                                        setState(() {
                                          _replyingToCommentId = cmtId;
                                          _replyingToUsername = data['authorName'] ?? 'Anonymous';
                                        });
                                        _commentFocusNode.requestFocus();
                                      },
                                      onDeleteReply: (replyMap) => _deleteReply(cmtId, replyMap),
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

              // ── Comment input (reactive to allowComments field) ────────────
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.id)
                    .snapshots(),
                builder: (context, postSnap) {
                  final postData = postSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final allowComments = postData['allowComments'] ?? true;

                  if (!allowComments) {
                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                      ),
                      color: c.surface,
                      child: Center(
                        child: Text(
                          'Comments are disabled for this post.',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingToCommentId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.06),
                            border: Border(top: BorderSide(color: c.border)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.reply_rounded, size: 16, color: c.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Replying to @$_replyingToUsername',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c.textHi,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _replyingToCommentId = null;
                                    _replyingToUsername = null;
                                  });
                                },
                                child: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                      _CommentInput(
                        controller:    _commentController,
                        focusNode:     _commentFocusNode,
                        isSending:     _isSending,
                        userAvatarUrl: FirebaseAuth.instance.currentUser?.photoURL,
                        onSend:        _submitComment,
                      ),
                    ],
                  );
                },
              ),
            ]),
    );
  }
}

// ── Full-width media hero ─────────────────────────────────────────────────────

class _MediaHero extends StatelessWidget {
  final String postId;
  final String mediaUrl;
  final String? videoThumbnailUrl;
  final bool isVideo;
  final bool isPostAuthor;
  final VoidCallback onExpand;
  final String? heroTag;

  const _MediaHero({
    required this.postId,
    required this.mediaUrl,
    this.videoThumbnailUrl,
    required this.isVideo,
    required this.isPostAuthor,
    required this.onExpand,
    this.heroTag,
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
              ? (videoThumbnailUrl != null && videoThumbnailUrl!.isNotEmpty
                  ? Image.network(
                      videoThumbnailUrl!,
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _VideoThumbnail(videoUrl: mediaUrl),
                    )
                  : _VideoThumbnail(videoUrl: mediaUrl))
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

        // Type/Edit badges row
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Edit cover button (only visible to author of video post)
              if (isVideo && isPostAuthor)
                _EditCoverButton(postId: postId)
              else
                const SizedBox(),

              // Type badge
              Container(
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
            ],
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

class _EditCoverButton extends StatefulWidget {
  final String postId;
  const _EditCoverButton({required this.postId});

  @override
  State<_EditCoverButton> createState() => _EditCoverButtonState();
}

class _EditCoverButtonState extends State<_EditCoverButton> {
  bool _isLoading = false;

  void _showCoverMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final c = context.appColors;
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Manage Echo Cover',
                    style: TextStyle(
                      color: c.textHi,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.photo_library_rounded, color: c.primary),
                  title: Text('Change Cover Thumbnail', style: TextStyle(color: c.textHi)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadCover();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Remove Custom Cover', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeCover();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadCover() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isLoading = true);

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref('posts/thumbnails/edit_${widget.postId}_$ts.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'videoThumbnailUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Cover updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update cover: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeCover() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'videoThumbnailUrl': FieldValue.delete()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Custom cover removed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove cover: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _showCoverMenu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isLoading
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              _isLoading ? 'Updating...' : 'Edit Cover',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
            userId: post.authorId,
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
                LiveUsername(
                  userId: post.authorId,
                  fallback: post.authorUsername,
                  style: TextStyle(
                      fontSize: 11, color: c.textMuted),
                ),
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
        if (post.body.isNotEmpty && post.body.trim() != post.title.trim())
          Text(post.body,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: c.textSecondary)),
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: post.tags.map((tag) {
              final displayTag = tag.startsWith('#') ? tag : '#$tag';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayTag,
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
  final String? authorId;
  final String caption;

  const _FullscreenMediaViewer({
    required this.mediaUrl,
    required this.isVideo,
    required this.authorName,
    required this.authorUsername,
    this.avatarUrl,
    this.authorId,
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
                          userId: widget.authorId,
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
                            LiveUsername(
                              userId: widget.authorId,
                              fallback: widget.authorUsername,
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11),
                            ),
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

  final bool canDelete;
  final VoidCallback onDelete;

  final VoidCallback onLike;
  final VoidCallback onReply;
  final Function(Map<String, dynamic>) onDeleteReply;

  const _CommentTile({
    required this.commentId,
    required this.data,
    required this.isBestAnswer,
    required this.showAwardBtn,
    required this.showTipBtn,
    required this.canDelete,
    required this.onDelete,
    required this.onAward,
    required this.onTip,
    required this.onLike,
    required this.onReply,
    required this.onDeleteReply,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final name     = data['authorName']     as String? ?? 'Anonymous';
    final username = data['authorUsername'] as String? ?? '@user';
    final content  = data['content']        as String? ?? '';
    final avatar   = data['authorAvatar']   as String? ?? '';
    final authorId = data['authorId']       as String? ?? '';

    final likedBy = data['likedBy'] as List? ?? [];
    final likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
    final replies = data['replies'] as List? ?? [];
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLiked = likedBy.contains(myUid);

    return Container(
      color: isBestAnswer
          ? c.successBg
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomAvatar(
              name: name,
              radius: 16,
              imageUrl: avatar.isNotEmpty ? avatar : null,
              userId: authorId,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: c.textHi,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          '·',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      LiveUsername(
                        userId: authorId,
                        fallback: username,
                        style: TextStyle(fontSize: 11, color: c.textMuted),
                      ),
                      if (isBestAnswer) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.success,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Best answer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (canDelete)
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.transparent,
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (showAwardBtn)
                        _ActionChip(
                          icon: Icons.emoji_events_rounded,
                          label: 'Best answer',
                          color: c.success,
                          bg: c.successBg,
                          onTap: onAward,
                        ),
                      if (showAwardBtn) const SizedBox(width: 8),
                      if (showTipBtn)
                        _ActionChip(
                          icon: Icons.bolt_rounded,
                          label: 'Tip',
                          color: c.warningKarma,
                          bg: c.warningKarmaBg,
                          onTap: onTip,
                        ),
                      if (showTipBtn) const SizedBox(width: 8),

                      // Comment Like
                      _ActionChip(
                        icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        label: likeCount > 0 ? '$likeCount' : 'Like',
                        color: isLiked ? Colors.redAccent : c.textMuted,
                        bg: isLiked ? Colors.redAccent.withValues(alpha: 0.08) : c.field,
                        onTap: onLike,
                      ),
                      const SizedBox(width: 8),

                      // Comment Reply
                      _ActionChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Reply',
                        color: c.primary,
                        bg: c.primary.withValues(alpha: 0.08),
                        onTap: onReply,
                      ),

                      const Spacer(),
                      if (authorId.isNotEmpty)
                        KarmaBadge(uid: authorId, size: KarmaBadgeSize.small),
                    ],
                  ),

                  // ── Indented Nested replies thread ──
                  if (replies.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: c.border.withValues(alpha: 0.5), width: 1.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: replies.map<Widget>((replyMap) {
                          final reply = replyMap as Map<String, dynamic>;
                          final rAuthorName = reply['authorName'] ?? 'Anonymous';
                          final rAuthorUsername = reply['authorUsername'] ?? '@user';
                          final rContent = reply['content'] ?? '';
                          final rAvatar = reply['authorAvatar'] ?? '';
                          final rAuthorId = reply['authorId'] ?? '';

                          final canDeleteReply = rAuthorId == myUid || authorId == myUid || canDelete;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomAvatar(
                                  name: rAuthorName,
                                  radius: 10,
                                  imageUrl: rAvatar.isNotEmpty ? rAvatar : null,
                                  userId: rAuthorId,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rAuthorName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: c.textHi,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 1),
                                            child: Text('·', style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 4),
                                          LiveUsername(
                                            userId: rAuthorId,
                                            fallback: rAuthorUsername,
                                            style: TextStyle(fontSize: 9, color: c.textMuted),
                                          ),
                                          const Spacer(),
                                          if (canDeleteReply)
                                            GestureDetector(
                                              onTap: () => onDeleteReply(reply),
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 13,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        rContent,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.3,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
  final FocusNode? focusNode;
  final bool isSending;
  final String? userAvatarUrl;
  final VoidCallback onSend;

  const _CommentInput({
    required this.controller,
    this.focusNode,
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
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, -3),
              blurRadius: 4),
        ],
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(children: [
        CustomAvatar(
          name: 'You',
          radius: 16,
          imageUrl: userAvatarUrl,
          userId: FirebaseAuth.instance.currentUser?.uid,
        ),
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
              focusNode: focusNode,
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

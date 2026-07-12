import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/models/post_model.dart';
import '../models/message_model.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool animate;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.animate = true,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isMe ? 0.12 : -0.12, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(12);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
            child: Column(
              crossAxisAlignment:
                  widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (widget.message.type == MessageType.image && widget.message.imageUrl != null)
                  ClipRRect(
                    borderRadius: radius,
                    child: Image.network(
                      widget.message.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 200,
                          height: 200,
                          color: c.field,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: c.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        width: 200,
                        height: 200,
                        color: c.field,
                        child: Icon(Icons.broken_image_outlined,
                            color: c.textDim),
                      ),
                    ),
                  )
                else if (widget.message.type == MessageType.sharedPost)
                  GestureDetector(
                    onTap: () async {
                      try {
                        final doc = await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.message.sharedPostId)
                            .get();
                        if (!doc.exists) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Post was deleted.')),
                          );
                          return;
                        }
                        final post = Post.fromFirestore(doc, FirebaseAuth.instance.currentUser?.uid ?? '');
                        if (!mounted) return;
                        if (widget.message.sharedPostType == 'video') {
                          Navigator.of(context).pushNamed(
                            AppRoutes.echoViewer,
                            arguments: {
                              'posts': [post],
                              'initialIndex': 0,
                            },
                          );
                        } else {
                          Navigator.of(context).pushNamed(
                            AppRoutes.postDetail,
                            arguments: {
                              'post': post,
                              'heroTag': 'shared_post_${post.id}',
                            },
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error loading post: $e')),
                        );
                      }
                    },
                    child: Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: widget.isMe
                            ? c.primary.withValues(alpha: 0.9)
                            : c.surface,
                        borderRadius: radius,
                        border: Border.all(
                          color: widget.isMe
                              ? Colors.white.withValues(alpha: 0.15)
                              : c.border,
                          width: 0.8,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.message.sharedPostType == 'video' &&
                              widget.message.sharedPostVideoThumbnail != null)
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.network(
                                  widget.message.sharedPostVideoThumbnail!,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            )
                          else if (widget.message.sharedPostImageUrl != null &&
                              widget.message.sharedPostImageUrl!.isNotEmpty)
                            Image.network(
                              widget.message.sharedPostImageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${widget.message.sharedPostAuthorUsername ?? 'user'}',
                                  style: TextStyle(
                                    color: widget.isMe
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : c.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.message.sharedPostTitle ?? 'Shared Post',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.isMe ? Colors.white : c.textHi,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    height: 1.25,
                                  ),
                                ),
                                if (widget.message.sharedPostBody != null &&
                                    widget.message.sharedPostBody!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.message.sharedPostBody!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: widget.isMe
                                          ? Colors.white.withValues(alpha: 0.72)
                                          : c.textMuted,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.isMe ? c.primary : c.field,
                      borderRadius: radius,
                      border: widget.isMe
                          ? null
                          : Border.all(color: c.border, width: 0.8),
                    ),
                    child: Text(
                      widget.message.text ?? '',
                      style: TextStyle(
                        color: widget.isMe ? Colors.white : c.textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _formatTime(widget.message.createdAt),
                    style: TextStyle(fontSize: 10, color: c.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

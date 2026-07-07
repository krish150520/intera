import 'package:flutter/material.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../shared/widgets/live_username.dart';
import '../screens/post_detail_screen.dart';

class PinterestPostCard extends StatelessWidget {
  final Post post;

  const PinterestPostCard({
    super.key,
    required this.post,
  });

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = post.type == PostType.video;
    final displayUrl = (isVideo && post.videoThumbnailUrl != null && post.videoThumbnailUrl!.isNotEmpty)
        ? post.videoThumbnailUrl!
        : post.imageUrl;
    final hasDisplayImage = displayUrl != null && displayUrl.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Media Header
              if (hasDisplayImage)
                Stack(
                  children: [
                    AspectRatio(
                      // Slight variance keeps the masonry feel; swap for
                      // real image aspect ratio if it's known ahead of time.
                      aspectRatio: post.hashCode.isEven ? 0.85 : 1.15,
                      child: Image.network(
                        displayUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: c.surface,
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, size: 24),
                          ),
                        ),
                      ),
                    ),
                    if (isVideo)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.15),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Type badge — top-left, matches reference layout
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.image_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              post.type.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // Card Text Content & Metadata
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    if (post.title.isNotEmpty)
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: c.textHi,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Author Info Row
                    Row(
                      children: [
                        CustomAvatar(
                          name: post.authorName,
                          imageUrl: post.authorAvatarUrl,
                          userId: post.authorId,
                          radius: 10,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LiveUsername(
                            userId: post.authorId,
                            fallback: post.authorUsername,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : c.textMuted,
                            ),
                            suffix: ' · ${_formatTime(post.createdAt)}',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                    const SizedBox(height: 6),

                    // Interactions Footer
                    Row(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : c.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${post.likeCount}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : c.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chat_bubble_rounded,
                          size: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : c.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${post.commentCount}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : c.textMuted,
                          ),
                        ),
                      ],
                    ),
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
import 'package:flutter/material.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/theme/app_theme.dart';
import '../screens/post_detail_screen.dart';

class PinterestPostCard extends StatefulWidget {
  final Post post;

  const PinterestPostCard({
    super.key,
    required this.post,
  });

  @override
  State<PinterestPostCard> createState() => _PinterestPostCardState();
}

class _PinterestPostCardState extends State<PinterestPostCard> {
  bool _hovering = false;

  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          post: widget.post,
          heroTag: 'discover_post_${widget.post.id}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final c = context.appColors;
    final isVideo = post.type == PostType.video;
    final displayUrl = (isVideo &&
            post.videoThumbnailUrl != null &&
            post.videoThumbnailUrl!.isNotEmpty)
        ? post.videoThumbnailUrl!
        : post.imageUrl;
    final hasDisplayImage = displayUrl != null && displayUrl.isNotEmpty;

    // Pinterest varies aspect ratio per-pin to create the masonry rhythm.
    final aspectRatio = post.hashCode.isEven ? 0.72 : 1.05;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: _openDetail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The pin itself — this is basically the whole card.
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: hasDisplayImage
                        ? Image.network(
                            displayUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: c.surface,
                              child: const Center(
                                child: Icon(Icons.broken_image_rounded,
                                    size: 24),
                              ),
                            ),
                          )
                        : Container(
                            color: c.surface,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              post.title,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.textHi,
                              ),
                            ),
                          ),
                  ),

                  if (isVideo)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.18),
                              ],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Hover/press scrim — mimics Pinterest's darken-on-hover.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hovering ? 1 : 0,
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),

                  // Overflow menu — top-right, only the "..." like Pinterest.
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _PinDotsMenu(post: post),
                  ),

                  // Karma/reward chip — bottom-left, replaces Pinterest's
                  // "Save" pill with something meaningful to Intera.
                  if ((post.rewardKarma ?? 0) > 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${post.rewardKarma}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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

/// Tiny circular "..." button, the way Pinterest shows it on each pin.
class _PinDotsMenu extends StatelessWidget {
  final Post post;
  const _PinDotsMenu({required this.post});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Hook up to your existing post-options bottom sheet.
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.more_horiz_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../profile/screens/user_profile_screen.dart'; 

/// Renders a single feed item with dynamic media preview boxes 
/// and standard social media user action slots.
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
  });

  String _typeLabel() {
    switch (post.type) {
      case PostType.question: return 'Question';
      case PostType.helpRequest: return 'Help Request';
      case PostType.achievement: return 'Achievement';
      case PostType.image: return 'Image Post';
      case PostType.video: return 'Video Post';
      case PostType.text: return '';
    }
  }

  Color _typeColor() {
    switch (post.type) {
      case PostType.question: return Colors.blue;
      case PostType.helpRequest: return AppColors.warning;
      case PostType.achievement: return AppColors.success;
      case PostType.image: return AppColors.primary;
      case PostType.video: return AppColors.primary;
      case PostType.text: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String labelText = _typeLabel();
    final hasMedia = post.imageUrl != null && post.imageUrl!.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interactive Profile Header Row Configuration
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        userId: post.authorId,
                        userName: post.authorName,
                        userAvatar: post.authorAvatarUrl ?? '',
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CustomAvatar(
                      name: post.authorName,
                      imageUrl: post.authorAvatarUrl, 
                      radius: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            // FIXED: Dynamic structural check evaluates and reformats invalid fallback states automatically
                            (post.authorUsername != null && post.authorUsername.isNotEmpty && post.authorUsername != '@user')
                                ? (post.authorUsername.startsWith('@') ? post.authorUsername : '@${post.authorUsername}')
                                : '@${post.authorName.toLowerCase().replaceAll(' ', '')}', // ◄── Smart Fallback handle path
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    if (labelText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _typeColor().withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          labelText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _typeColor()),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Text Content Statement block
              if (post.content.isNotEmpty) ...[
                Text(
                  post.content, 
                  style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                ),
                const SizedBox(height: 12),
              ],

              // DYNAMIC MEDIA SECTION: Conditional media template render paths
              if (hasMedia) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: post.type == PostType.video
                      ? _FeedVideoPlayer(videoUrl: post.imageUrl!)
                      : Image.network(
                          post.imageUrl!,
                          width: double.infinity,
                          height: 280,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 280,
                              color: Colors.grey.shade100,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 120,
                            color: Colors.grey.shade100,
                            child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
              ],

              // Task Rewards block structure
              if (post.type == PostType.helpRequest && post.rewardKarma != null && post.rewardKarma! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Assistance Bounty: ${post.rewardKarma} Karma',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Interaction Row Bar Action buttons
              Row(
                children: [
                  _ActionButton(
                    icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: '${post.likeCount}', 
                    color: post.isLiked ? Colors.red : Colors.grey.shade600,
                    onTap: onLike,
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    icon: Icons.mode_comment_outlined,
                    label: '${post.commentCount}', 
                    color: Colors.grey.shade600,
                    onTap: onComment,
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: Colors.grey.shade600,
                    onTap: onShare,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 20,
                      color: post.isSaved ? AppColors.primary : Colors.grey.shade600,
                    ),
                    onPressed: onSave,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SELF-CONTAINED MEMORY-SAFE FEED VIDEO CONTAINER ---

class _FeedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FeedVideoPlayer({required this.videoUrl});

  @override
  State<_FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<_FeedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _controller.setVolume(0); 
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: 200,
        color: Colors.black87,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.black.withOpacity(0.5),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
                });
              },
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black.withOpacity(0.6),
                child: Icon(
                  _controller.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- ICON ACTION BUTTON WIDGET COMPONENT ---

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
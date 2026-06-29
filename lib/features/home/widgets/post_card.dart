import 'package:flutter/material.dart';
import '../../../shared/models/post_model.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
  });

  bool get _hasMedia =>
      post.imageUrl != null && post.imageUrl!.isNotEmpty;

  bool get _isMediaType =>
      post.type == PostType.image || post.type == PostType.video;

  @override
  Widget build(BuildContext context) {
    // Image / video posts → full-bleed card (existing style, kept as-is)
    if (_hasMedia || _isMediaType) {
      return _MediaPostCard(
        post: post,
        onTap: onTap,
        onLike: onLike,
        onSave: onSave,
        onComment: onComment,
      );
    }

    // All other post types → Option C tinted card
    return _TextPostCard(
      post: post,
      onTap: onTap,
      onLike: onLike,
      onSave: onSave,
      onComment: onComment,
    );
  }
}

// ── Option C: tinted background card (text / question / help / achievement) ──

class _TextPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;

  const _TextPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
  });

  // Per-type colour config
  _TypeStyle get _style => switch (post.type) {
        PostType.question    => const _TypeStyle(
            bg:         Color(0xFFF0FFF4),
            border:     Color(0xFFC8E6C9),
            pillBg:     Color(0xFF388E3C),
            pillText:   Colors.white,
            label:      'Question',
            emoji:      '❓',
          ),
        PostType.helpRequest => const _TypeStyle(
            bg:         Color(0xFFFFFBF0),
            border:     Color(0xFFF5DCAA),
            pillBg:     Color(0xFFC9830A),
            pillText:   Colors.white,
            label:      'Help',
            emoji:      '🤝',
          ),
        PostType.achievement => const _TypeStyle(
            bg:         Color(0xFFFFF8F0),
            border:     Color(0xFFFFCC80),
            pillBg:     Color(0xFFE65100),
            pillText:   Colors.white,
            label:      'Achievement',
            emoji:      '🏆',
          ),
        _ => const _TypeStyle(
            // text, question fallback
            bg:         Color(0xFFF5F4FF),
            border:     Color(0xFFE4E2F8),
            pillBg:     Color(0xFF6C63D5),
            pillText:   Colors.white,
            label:      'Text',
            emoji:      '💬',
          ),
      };

  String _pillLabel() {
    if (post.type == PostType.helpRequest &&
        (post.rewardKarma ?? 0) > 0) {
      return 'Help · ${post.rewardKarma} ⚡';
    }
    return _style.label;
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 160),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: s.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Large faded emoji watermark (top-right)
            Positioned(
              top: -4,
              right: -2,
              child: Text(
                s.emoji,
                style: const TextStyle(fontSize: 52),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Type pill ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.pillBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _pillLabel(),
                    style: TextStyle(
                      color: s.pillText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Title ────────────────────────────────────────────────
                if (post.title.isNotEmpty)
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2A6E),
                      height: 1.25,
                      letterSpacing: -0.2,
                    ),
                  ),

                // ── Body ─────────────────────────────────────────────────
                if (post.body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    post.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF555555),
                      height: 1.45,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Footer ────────────────────────────────────────────────
                Row(children: [
                  // Avatar
                  _MiniAvatar(
                    name: post.authorName,
                    imageUrl: post.authorAvatarUrl,
                  ),
                  const SizedBox(width: 7),

                  // Author + time
                  Expanded(
                    child: Text(
                      '${post.authorUsername} · ${_formatTime(post.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9BD0),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Stats
                  _FooterStat(
                    icon: post.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor: post.isLiked
                        ? const Color(0xFFFF6B8A)
                        : const Color(0xFFB0ADDE),
                    label: _compact(post.likeCount),
                    onTap: onLike,
                  ),
                  const SizedBox(width: 10),
                  _FooterStat(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: const Color(0xFFB0ADDE),
                    label: _compact(post.commentCount),
                    onTap: onComment,
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onSave,
                    child: Icon(
                      post.isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                      color: post.isSaved
                          ? const Color(0xFF6C63D5)
                          : const Color(0xFFB0ADDE),
                    ),
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-bleed media card (image / video posts) ───────────────────────────────

class _MediaPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;

  const _MediaPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        post.imageUrl != null && post.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 360,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image / fallback
              hasImage
                  ? Image.network(
                      post.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _FallbackBg(),
                    )
                  : const _FallbackBg(),

              // Gradient overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.30, 1.0],
                    colors: [
                      Color(0x00000000),
                      Color(0x44000000),
                      Color(0xE0000000),
                    ],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthorRow(post: post),
                    const Spacer(),
                    if (post.title.isNotEmpty)
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                    if (post.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _MediaStatsRow(
                      post: post,
                      onLike: onLike,
                      onComment: onComment,
                      onSave: onSave,
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

// ── Shared helpers ────────────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _compact(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TypeStyle {
  final Color bg;
  final Color border;
  final Color pillBg;
  final Color pillText;
  final String label;
  final String emoji;

  const _TypeStyle({
    required this.bg,
    required this.border,
    required this.pillBg,
    required this.pillText,
    required this.label,
    required this.emoji,
  });
}

class _MiniAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _MiniAvatar({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return CircleAvatar(
      radius: 11,
      backgroundColor: const Color(0xFF6C63D5),
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: !hasImage
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700),
            )
          : null,
    );
  }
}

class _FooterStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _FooterStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9E9BD0))),
      ]),
    );
  }
}

// Media card author row
class _AuthorRow extends StatelessWidget {
  final Post post;
  const _AuthorRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty;

    return Row(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF6C63D5),
        backgroundImage:
            hasAvatar ? NetworkImage(post.authorAvatarUrl!) : null,
        child: !hasAvatar
            ? Text(
                post.authorName.isNotEmpty
                    ? post.authorName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              )
            : null,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(post.authorName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(
              _formatTime(post.createdAt),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 10),
            ),
          ],
        ),
      ),
    ]);
  }
}

// Media card stats row
class _MediaStatsRow extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onSave;

  const _MediaStatsRow({
    required this.post,
    this.onLike,
    this.onComment,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _MediaStatBtn(
        icon: post.isLiked
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        iconColor:
            post.isLiked ? const Color(0xFFFF6B8A) : Colors.white,
        label: _compact(post.likeCount),
        onTap: onLike,
      ),
      const SizedBox(width: 16),
      _MediaStatBtn(
        icon: Icons.chat_bubble_outline_rounded,
        iconColor: Colors.white,
        label: _compact(post.commentCount),
        onTap: onComment,
      ),
      const Spacer(),
      GestureDetector(
        onTap: onSave,
        child: Icon(
          post.isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color:
              post.isSaved ? const Color(0xFF6C63D5) : Colors.white,
          size: 22,
        ),
      ),
    ]);
  }
}

class _MediaStatBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _MediaStatBtn({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// Fallback gradient background for media cards
class _FallbackBg extends StatelessWidget {
  const _FallbackBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF6C63D5)],
        ),
      ),
    );
  }
}
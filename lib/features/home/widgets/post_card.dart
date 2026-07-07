import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final void Function(String type)? onReact;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
    this.onReact,
  });

  bool get _hasMedia => post.imageUrl != null && post.imageUrl!.isNotEmpty;

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
        onReact: onReact,
      );
    }

    // All other post types → Option C tinted card
    return _TextPostCard(
      post: post,
      onTap: onTap,
      onLike: onLike,
      onSave: onSave,
      onComment: onComment,
      onReact: onReact,
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
  final void Function(String type)? onReact;

  const _TextPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onReact,
  });

  // Per-type colour config (dynamic based on active theme brightness)
  _TypeStyle _getStyle(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (post.type) {
      PostType.question => isDark
          ? const _TypeStyle(
              bg: Color(0xFF0F261C),
              border: Color(0xFF1E533C),
              pillBg: Color(0xFF2E7D32),
              pillText: Colors.white,
              titleColor: Color(0xFFE8F5E9),
              bodyColor: Color(0xFFC8E6C9),
              label: 'Question',
              emoji: '❓',
            )
          : const _TypeStyle(
              bg: Color(0xFFF0FFF4),
              border: Color(0xFFC8E6C9),
              pillBg: Color(0xFF388E3C),
              pillText: Colors.white,
              titleColor: Color(0xFF2D2A6E),
              bodyColor: Color(0xFF555555),
              label: 'Question',
              emoji: '❓',
            ),
      PostType.helpRequest => isDark
          ? const _TypeStyle(
              bg: Color(0xFF2C210F),
              border: Color(0xFF5A441B),
              pillBg: Color(0xFFD84315),
              pillText: Colors.white,
              titleColor: Color(0xFFFDF6E2),
              bodyColor: Color(0xFFF5DCAA),
              label: 'Help',
              emoji: '🤝',
            )
          : const _TypeStyle(
              bg: Color(0xFFFFFBF0),
              border: Color(0xFFF5DCAA),
              pillBg: Color(0xFFC9830A),
              pillText: Colors.white,
              titleColor: Color(0xFF2D2A6E),
              bodyColor: Color(0xFF555555),
              label: 'Help',
              emoji: '🤝',
            ),
      PostType.achievement => isDark
          ? const _TypeStyle(
              bg: Color(0xFF2C190F),
              border: Color(0xFF5A311B),
              pillBg: Color(0xFFEF6C00),
              pillText: Colors.white,
              titleColor: Color(0xFFFDF2E9),
              bodyColor: Color(0xFFFFCC80),
              label: 'Achievement',
              emoji: '🏆',
            )
          : const _TypeStyle(
              bg: Color(0xFFFFF8F0),
              border: Color(0xFFFFCC80),
              pillBg: Color(0xFFE65100),
              pillText: Colors.white,
              titleColor: Color(0xFF2D2A6E),
              bodyColor: Color(0xFF555555),
              label: 'Achievement',
              emoji: '🏆',
            ),
      _ => isDark
          ? const _TypeStyle(
              bg: Color(0xFF1D1A32), // Fits dark background surface
              border: Color(0xFF383361),
              pillBg: Color(0xFF7E69FF),
              pillText: Colors.white,
              titleColor: Color(0xFFECEBFF),
              bodyColor: Color(0xFFC5C2E6),
              label: 'Text',
              emoji: '💬',
            )
          : const _TypeStyle(
              bg: Color(0xFFF5F4FF),
              border: Color(0xFFE4E2F8),
              pillBg: Color(0xFF6C63D5),
              pillText: Colors.white,
              titleColor: Color(0xFF2D2A6E),
              bodyColor: Color(0xFF555555),
              label: 'Text',
              emoji: '💬',
            ),
    };
  }

  String _pillLabel(_TypeStyle style) {
    if (post.type == PostType.helpRequest && (post.rewardKarma ?? 0) > 0) {
      return 'Help · ${post.rewardKarma} ⚡';
    }
    return style.label;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _getStyle(context);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final myReaction = post.reactions[myUid];
    final bool hasReacted = myReaction != null;

    final IconData reactionIcon = switch (myReaction) {
      'beauty' => Icons.favorite_rounded,
      'art' => Icons.palette_rounded,
      'funny' => Icons.emoji_emotions_rounded,
      'like' => Icons.favorite_rounded,
      _ => Icons.favorite_border_rounded,
    };
    final Color reactionColor = switch (myReaction) {
      'beauty' => Colors.pinkAccent,
      'art' => Colors.orangeAccent,
      'funny' => Colors.amber,
      'like' => const Color(0xFFEF4444),
      _ => isDark ? const Color(0xFF8B86B7) : const Color(0xFFB0ADDE),
    };

    final Color footerTextColor =
        isDark ? const Color(0xFF8B86B7) : const Color(0xFF9E9BD0);
    final Color iconDefaultColor =
        isDark ? const Color(0xFF8B86B7) : const Color(0xFFB0ADDE);

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
              child: Opacity(
                opacity: 0.15,
                child: Text(
                  s.emoji,
                  style: const TextStyle(fontSize: 52),
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Type pill ───────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.pillBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _pillLabel(s),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: s.titleColor,
                      height: 1.25,
                      letterSpacing: -0.2,
                    ),
                  ),

                // ── Body ─────────────────────────────────────────────────
                if (post.body.isNotEmpty &&
                    post.body.trim() != post.title.trim()) ...[
                  const SizedBox(height: 5),
                  Text(
                    post.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: s.bodyColor,
                      height: 1.45,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Footer ────────────────────────────────────────────────
                Row(children: [
                  // Avatar
                  CustomAvatar(
                    name: post.authorName,
                    imageUrl: post.authorAvatarUrl,
                    userId: post.authorId,
                    radius: 11,
                  ),
                  const SizedBox(width: 7),

                  // Author + time
                  Expanded(
                    child: Text(
                      '${post.authorUsername} · ${_formatTime(post.createdAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: footerTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Stats
                  _FooterStat(
                    icon: reactionIcon,
                    iconColor: hasReacted ? reactionColor : iconDefaultColor,
                    label: _compact(post.likeCount),
                    labelColor: footerTextColor,
                    onTap: onReact != null ? () => onReact!('like') : onLike,
                    onLongPress: onReact != null
                        ? () => _showReactionSheet(context, onReact!)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  _FooterStat(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: iconDefaultColor,
                    label: _compact(post.commentCount),
                    labelColor: footerTextColor,
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
                          ? (isDark
                              ? const Color(0xFFA597EC)
                              : const Color(0xFF6C63D5))
                          : iconDefaultColor,
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
  final void Function(String type)? onReact;

  const _MediaPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final myReaction = post.reactions[myUid];
    final bool hasReacted = myReaction != null;

    final IconData reactionIcon = switch (myReaction) {
      'beauty' => Icons.favorite_rounded,
      'art' => Icons.palette_rounded,
      'funny' => Icons.emoji_emotions_rounded,
      'like' => Icons.favorite_rounded,
      _ => Icons.favorite_border_rounded,
    };
    final Color reactionColor = switch (myReaction) {
      'beauty' => Colors.pinkAccent,
      'art' => Colors.orangeAccent,
      'funny' => Colors.amber,
      'like' => const Color(0xFFEF4444),
      _ => Colors.white,
    };

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
                      errorBuilder: (_, __, ___) => const _FallbackBg(),
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
                    if (post.body.isNotEmpty &&
                        post.body.trim() != post.title.trim()) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _MediaStatsRow(
                      post: post,
                      reactionIcon: reactionIcon,
                      reactionColor: hasReacted ? reactionColor : Colors.white,
                      onLike: onLike,
                      onComment: onComment,
                      onSave: onSave,
                      onReact: onReact,
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
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TypeStyle {
  final Color bg;
  final Color border;
  final Color pillBg;
  final Color pillText;
  final Color titleColor;
  final Color bodyColor;
  final String label;
  final String emoji;

  const _TypeStyle({
    required this.bg,
    required this.border,
    required this.pillBg,
    required this.pillText,
    required this.titleColor,
    required this.bodyColor,
    required this.label,
    required this.emoji,
  });
}



class _FooterStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _FooterStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: labelColor)),
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
    return Row(children: [
      CustomAvatar(
        name: post.authorName,
        imageUrl: post.authorAvatarUrl,
        userId: post.authorId,
        radius: 16,
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
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
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
  final IconData reactionIcon;
  final Color reactionColor;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onSave;
  final void Function(String type)? onReact;

  const _MediaStatsRow({
    required this.post,
    required this.reactionIcon,
    required this.reactionColor,
    this.onLike,
    this.onComment,
    this.onSave,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _MediaStatBtn(
        icon: reactionIcon,
        iconColor: reactionColor,
        label: _compact(post.likeCount),
        onTap: onReact != null ? () => onReact!('like') : onLike,
        onLongPress: onReact != null
            ? () => _showReactionSheet(context, onReact!)
            : null,
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
          post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: post.isSaved ? const Color(0xFF6C63D5) : Colors.white,
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
  final VoidCallback? onLongPress;

  const _MediaStatBtn({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
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

// ── Reaction Selector Bottom Sheet ───────────────────────────────────────────

void _showReactionSheet(BuildContext context, void Function(String) onSelect) {
  final c = context.appColors;
  showModalBottomSheet(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'React',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _reactionItem(sheetCtx, 'like', '👍', 'Like', onSelect),
                  _reactionItem(sheetCtx, 'beauty', '💖', 'Beauty', onSelect),
                  _reactionItem(sheetCtx, 'art', '🎨', 'Art', onSelect),
                  _reactionItem(sheetCtx, 'funny', '😂', 'Funny', onSelect),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Widget _reactionItem(
  BuildContext context,
  String type,
  String emoji,
  String label,
  void Function(String) onSelect,
) {
  final c = context.appColors;
  return GestureDetector(
    onTap: () {
      Navigator.pop(context);
      onSelect(type);
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: c.field,
            shape: BoxShape.circle,
            border: Border.all(color: c.border, width: 0.8),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

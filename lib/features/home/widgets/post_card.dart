import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../shared/widgets/live_username.dart';
import 'poll_card_widget.dart';
import 'question_card_widget.dart';


class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final void Function(String type)? onReact;

  final String? heroTag;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
    this.onReact,
    this.heroTag,
  });

  bool get _hasMedia => post.imageUrl != null && post.imageUrl!.isNotEmpty;

  bool get _isMediaType =>
      post.type == PostType.image || post.type == PostType.video;

  @override
  Widget build(BuildContext context) {
    if (post.type == PostType.poll) {
      return PollCardWidget(post: post);
    }
    if (post.type == PostType.question) {
      return QuestionCardWidget(post: post);
    }

    if (_hasMedia || _isMediaType) {
      if (post.type == PostType.helpRequest) {
        return _DoubleTapLikeWrapper(
          onDoubleTapLike: onReact != null ? () => onReact!('like') : onLike,
          child: _MediaHelpPostCard(
            post: post,
            onTap: onTap,
            onLike: onLike,
            onSave: onSave,
            onComment: onComment,
            onShare: onShare,
            onReact: onReact,
            heroTag: heroTag,
          ),
        );
      }
      return _DoubleTapLikeWrapper(
        onDoubleTapLike: onReact != null ? () => onReact!('like') : onLike,
        child: _MediaPostCard(
          post: post,
          onTap: onTap,
          onLike: onLike,
          onSave: onSave,
          onComment: onComment,
          onShare: onShare,
          onReact: onReact,
          heroTag: heroTag,
        ),
      );
    } else {
      return _DoubleTapLikeWrapper(
        onDoubleTapLike: onReact != null ? () => onReact!('like') : onLike,
        child: _TextPostCard(
          post: post,
          onTap: onTap,
          onLike: onLike,
          onSave: onSave,
          onComment: onComment,
          onShare: onShare,
          onReact: onReact,
          heroTag: heroTag,
        ),
      );
    }
  }
}

// ── Option C: tinted background card (text / question / help / achievement) ──

class _TextPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final void Function(String type)? onReact;
  final String? heroTag;

  const _TextPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
    this.onReact,
    this.heroTag,
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
              bg: Color(0xFF1D1A32),
              border: Color(0xFF383361),
              pillBg: Color(0xFF7E69FF),
              pillText: Colors.white,
              titleColor: Color(0xFFECEBFF),
              bodyColor: Color(0xFFC5C2E6),
              label: 'Text',
              emoji: '💬',
              gradient: LinearGradient(
                colors: [Color(0xFF2A2F55), Color(0xFF171A30)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
              gradient: LinearGradient(
                colors: [Color(0xFFD8E2FF), Color(0xFFA7B7E7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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

    final cardWidget = GestureDetector(
      onTap: onTap,
      child: Container(
        height: 176, // fixed height keeps every text-type card visually balanced
        decoration: BoxDecoration(
          color: s.gradient == null ? s.bg : null,
          gradient: s.gradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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

            Positioned.fill(
              child: Column(
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
                      _pillLabel(s),
                      style: TextStyle(
                        color: s.pillText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Title + body ─────────────────────────────────────────
                  // Wrapped in Expanded so it fills whatever space is left
                  // above the footer, regardless of whether body text exists.
                  // This is what keeps every card the same size and the
                  // footer pinned to the bottom.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  ),

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
                      child: LiveUsername(
                        userId: post.authorId,
                        fallback: post.authorUsername,
                        style: TextStyle(
                          fontSize: 11,
                          color: footerTextColor,
                        ),
                        suffix: ' · ${_formatTime(post.createdAt)}',
                      ),
                    ),

                    // Stats
                    _FooterStat(
                      icon: reactionIcon,
                      iconColor: hasReacted ? reactionColor : iconDefaultColor,
                      label: _compact(post.likeCount),
                      labelColor: footerTextColor,
                      onTap:
                          onReact != null ? () => onReact!('like') : onLike,
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
                    if (onShare != null) ...[
                      GestureDetector(
                        onTap: onShare,
                        child: Icon(
                          Icons.share_outlined,
                          size: 18,
                          color: iconDefaultColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
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
            ),
          ],
        ),
      ),
    );

    return cardWidget;
  }
}

// ── Full-bleed media card (image / video posts) ───────────────────────────────

class _MediaPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final void Function(String type)? onReact;
  final String? heroTag;

  const _MediaPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
    this.onReact,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = post.type == PostType.video;
    final displayUrl = (isVideo && post.videoThumbnailUrl != null && post.videoThumbnailUrl!.isNotEmpty)
        ? post.videoThumbnailUrl!
        : post.imageUrl;
    final hasDisplayImage = displayUrl != null && displayUrl.isNotEmpty;

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
          height: isVideo ? 480 : 360,
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasDisplayImage
                  ? Image.network(
                      displayUrl,
                      fit: BoxFit.cover,
                      alignment: post.imageAlignment == 'top'
                          ? Alignment.topCenter
                          : (post.imageAlignment == 'bottom'
                              ? Alignment.bottomCenter
                              : Alignment.center),
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
                      onShare: onShare,
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
  final Gradient? gradient;

  const _TypeStyle({
    required this.bg,
    required this.border,
    required this.pillBg,
    required this.pillText,
    required this.titleColor,
    required this.bodyColor,
    required this.label,
    required this.emoji,
    this.gradient,
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
  final VoidCallback? onShare;
  final void Function(String type)? onReact;

  const _MediaStatsRow({
    required this.post,
    required this.reactionIcon,
    required this.reactionColor,
    this.onLike,
    this.onComment,
    this.onSave,
    this.onShare,
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
      if (onShare != null) ...[
        const SizedBox(width: 16),
        GestureDetector(
          onTap: onShare,
          child: const Icon(
            Icons.share_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
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
                  _reactionItem(sheetCtx, 'beauty', '💖', 'Radiance', onSelect),
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

// ═══════════════════════════════════════════════════════════════════════════════
//  DOUBLE-TAP LIKE ANIMATION WRAPPER
// ═══════════════════════════════════════════════════════════════════════════════

class _DoubleTapLikeWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDoubleTapLike;

  const _DoubleTapLikeWrapper({
    required this.child,
    this.onDoubleTapLike,
  });

  @override
  State<_DoubleTapLikeWrapper> createState() => _DoubleTapLikeWrapperState();
}

class _DoubleTapLikeWrapperState extends State<_DoubleTapLikeWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  bool _showHeart = false;
  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) setState(() => _showHeart = false);
        }
      });

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    HapticFeedback.mediumImpact();
    setState(() {
      _showHeart = true;
      _tapPosition = details.localPosition;
    });
    _controller.forward(from: 0.0);
    widget.onDoubleTapLike?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {},
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_showHeart)
            Positioned(
              left: _tapPosition.dx - 36,
              top: _tapPosition.dy - 36,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnim.value,
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: child,
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFEF4444),
                    size: 72,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaHelpPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final void Function(String type)? onReact;
  final String? heroTag;

  const _MediaHelpPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
    this.onReact,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? c.surface : Colors.white;
    final borderCol = isDark ? c.border.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04);

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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').doc(post.id).snapshots(),
      builder: (context, snapshot) {
        bool isCompleted = false;
        int reward = (post.rewardKarma ?? 0);
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          isCompleted = data['isCompleted'] == true;
          reward = (data['karmaReward'] ?? data['rewardKarma'] ?? reward) as int;
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderCol, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Avatar, Username, Timestamp, Chips, More Menu)
                Row(
                  children: [
                    // User Avatar
                    CustomAvatar(
                      name: post.authorName,
                      imageUrl: post.authorAvatarUrl,
                      userId: post.authorId,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    // Username & Timestamp
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? c.textHi : const Color(0xFF1E293B),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(post.createdAt),
                            style: TextStyle(
                              color: isDark ? c.textMuted : const Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chips Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reward Chip (⚡ X karma)
                        if (reward > 0) ...[
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF3B2F1D) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF685123) : const Color(0xFFFDE68A),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.electric_bolt_rounded,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$reward karma',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Status Chip (Open / Resolved)
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? (isDark ? const Color(0xFF2E2222) : const Color(0xFFFEE2E2))
                                : (isDark ? const Color(0xFF1B3B2B) : const Color(0xFFDCFCE7)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isCompleted
                                  ? (isDark ? const Color(0xFF5C3333) : const Color(0xFFFCA5A5))
                                  : (isDark ? const Color(0xFF26543C) : const Color(0xFF86EFAC)),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted
                                      ? (isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626))
                                      : (isDark ? const Color(0xFF10B981) : const Color(0xFF16A34A)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCompleted ? 'Resolved' : 'Open',
                                style: TextStyle(
                                  color: isCompleted
                                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                      : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // More Menu Button
                        IconButton(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: isDark ? c.textMuted : const Color(0xFF64748B),
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showOptionsSheet(
                            context,
                            myUid == post.authorId || myUid == post.realAuthorId,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Header → Title = 16dp

                // 2. Title
                Text(
                  post.title,
                  style: TextStyle(
                    color: isDark ? c.textHi : const Color(0xFF0F172A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8), // Title → Description = 8dp

                // 3. Description
                if (post.body.isNotEmpty && post.body.trim() != post.title.trim()) ...[
                  Text(
                    post.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? c.textMuted : const Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16), // Description → Image = 16dp
                ] else ...[
                  const SizedBox(height: 8),
                ],

                // 4. Media (Rounded image aligned to card padding)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? c.field : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: borderCol,
                        width: 0.8,
                      ),
                    ),
                    child: _buildMediaWidget(context),
                  ),
                ),
                const SizedBox(height: 12), // Image → Actions = 12dp

                // 5. Action Row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      // Like
                      _MediaStatBtn(
                        icon: reactionIcon,
                        iconColor: hasReacted ? reactionColor : (isDark ? c.textMuted : const Color(0xFF64748B)),
                        label: _compact(post.likeCount),
                        onTap: onReact != null ? () => onReact!('like') : onLike,
                        onLongPress: onReact != null
                            ? () => _showReactionSheet(context, onReact!)
                            : null,
                      ),
                      const SizedBox(width: 20),
                      // Comment
                      _MediaStatBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        iconColor: isDark ? c.textMuted : const Color(0xFF64748B),
                        label: _compact(post.commentCount),
                        onTap: onComment,
                      ),
                      const SizedBox(width: 20),
                      // Share
                      if (onShare != null) ...[
                        GestureDetector(
                          onTap: onShare,
                          child: Icon(
                            Icons.share_outlined,
                            color: isDark ? c.textMuted : const Color(0xFF64748B),
                            size: 20,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Bookmark
                      GestureDetector(
                        onTap: onSave,
                        child: Icon(
                          post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: post.isSaved
                              ? (isDark ? const Color(0xFFA597EC) : const Color(0xFF6C63D5))
                              : (isDark ? c.textMuted : const Color(0xFF64748B)),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16), // Actions → Offer Help Button = 16dp

                // 6. Offer Help Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onComment,
                    icon: const Icon(Icons.handshake_outlined, size: 20),
                    label: const Text(
                      'Offer Help',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16), // Button → Bottom = 16dp
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOptionsSheet(BuildContext context, bool isAuthor) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? c.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isAuthor) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Delete Help Request',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _showDeleteConfirmDialog(context);
                  },
                ),
              ],
              ListTile(
                leading: Icon(Icons.share_outlined, color: isDark ? c.textHi : const Color(0xFF1E293B)),
                title: Text(
                  'Share Request',
                  style: TextStyle(color: isDark ? c.textHi : const Color(0xFF1E293B)),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  onShare?.call();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? c.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Help Request?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? c.textHi : const Color(0xFF1E293B),
            fontSize: 16,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this help request? This action cannot be undone.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? c.textMuted : const Color(0xFF64748B)),
            ),
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

                if (context.mounted) {
                  Navigator.pop(context); // Dismiss loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Help request deleted successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Dismiss loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget(BuildContext context) {
    final isVideo = post.type == PostType.video;
    final displayUrl = (isVideo && post.videoThumbnailUrl != null && post.videoThumbnailUrl!.isNotEmpty)
        ? post.videoThumbnailUrl!
        : post.imageUrl;

    if (displayUrl == null || displayUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 1.6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            displayUrl,
            fit: BoxFit.cover,
            alignment: post.imageAlignment == 'top'
                ? Alignment.topCenter
                : (post.imageAlignment == 'bottom'
                    ? Alignment.bottomCenter
                    : Alignment.center),
            errorBuilder: (_, __, ___) => const _FallbackBg(),
          ),
          if (isVideo)
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                color: Colors.black12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

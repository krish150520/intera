import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/theme/app_theme.dart';

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
    if (_hasMedia || _isMediaType) {
      return _MediaPostCard(
        post: post,
        onTap: onTap,
        onLike: onLike,
        onSave: onSave,
        onComment: onComment,
        onShare: onShare,
        onReact: onReact,
      );
    }
    return _TextPostCard(
      post: post,
      onTap: onTap,
      onLike: onLike,
      onSave: onSave,
      onComment: onComment,
      onShare: onShare,
      onReact: onReact,
    );
  }
}

class _TextPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final void Function(String type)? onReact;

  const _TextPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final typeInfo = _typeInfo(post.type);

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
      _ => c.textMuted,
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  _Avatar(
                    name: post.authorName,
                    imageUrl: post.authorAvatarUrl,
                    radius: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: TextStyle(
                            color: c.textHi,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        Text(
                          '${post.authorUsername} · ${_formatTime(post.createdAt)}',
                          style: TextStyle(
                            color: c.textDim,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeInfo.badgeBg(c),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeInfo.label,
                      style: TextStyle(
                        color: typeInfo.badgeText(c),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.title.isNotEmpty)
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textHi,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                    ),
                  if (post.body.isNotEmpty) ...[
                    if (post.title.isNotEmpty) const SizedBox(height: 4),
                    Text(
                      post.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Divider ────────────────────────────────────────────────────
            Divider(height: 1, thickness: 0.8, color: c.border),

            // ── Actions ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  _ActionBtn(
                    icon: reactionIcon,
                    label: _compact(post.likeCount),
                    active: hasReacted,
                    activeColor: reactionColor,
                    inactiveColor: c.textMuted,
                    onTap: onReact != null ? () => onReact!('like') : onLike,
                    onLongPress: onReact != null ? () => _showReactionSheet(context, onReact!) : null,
                  ),
                  _ActionBtn(
                    icon: Icons.mode_comment_outlined,
                    label: _compact(post.commentCount),
                    active: false,
                    activeColor: c.primary,
                    inactiveColor: c.textMuted,
                    onTap: onComment,
                  ),
                  _ActionBtn(
                    icon: Icons.share_outlined,
                    label: '',
                    active: false,
                    activeColor: c.primary,
                    inactiveColor: c.textMuted,
                    onTap: onShare,
                  ),
                  const Spacer(),
                  _ActionBtn(
                    icon: post.isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: '',
                    active: post.isSaved,
                    activeColor: c.primary,
                    inactiveColor: c.textMuted,
                    onTap: onSave,
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

// ── Media Post Card ───────────────────────────────────────────────────────────

class _MediaPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final void Function(String type)? onReact;

  const _MediaPostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onShare,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
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
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  _Avatar(
                    name: post.authorName,
                    imageUrl: post.authorAvatarUrl,
                    radius: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: TextStyle(
                            color: c.textHi,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _formatTime(post.createdAt),
                          style: TextStyle(color: c.textDim, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Media ──────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: SizedBox(
                height: 280,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasImage
                        ? Image.network(
                            post.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _FallbackBg(c: c),
                          )
                        : _FallbackBg(c: c),
                    // Bottom gradient for text legibility
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.4, 1.0],
                          colors: [Colors.transparent, Color(0xCC000000)],
                        ),
                      ),
                    ),
                    // Caption overlay
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.title.isNotEmpty)
                            Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
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
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Action row overlay at bottom
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Row(
                        children: [
                          _ActionBtn(
                            icon: reactionIcon,
                            label: _compact(post.likeCount),
                            active: hasReacted,
                            activeColor: reactionColor,
                            inactiveColor: Colors.white70,
                            onTap: onReact != null ? () => onReact!('like') : onLike,
                            onLongPress: onReact != null ? () => _showReactionSheet(context, onReact!) : null,
                          ),
                          _ActionBtn(
                            icon: Icons.mode_comment_outlined,
                            label: _compact(post.commentCount),
                            active: false,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white70,
                            onTap: onComment,
                          ),
                          const Spacer(),
                          _ActionBtn(
                            icon: post.isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            label: '',
                            active: post.isSaved,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white70,
                            onTap: onSave,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const _Avatar({required this.name, this.imageUrl, this.radius = 17});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final hasImg = imageUrl != null && imageUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.primary,
      backgroundImage: hasImg ? NetworkImage(imageUrl!) : null,
      child: !hasImg
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Container(
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
              const SizedBox(height: 14),
              Text(
                'React with points',
                style: TextStyle(
                  color: c.textHi,
                  fontSize: 14,
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
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: c.field,
            shape: BoxShape.circle,
            border: Border.all(color: c.border, width: 0.8),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
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


class _FallbackBg extends StatelessWidget {
  final AppColorsExtension c;
  const _FallbackBg({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(color: c.field);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

// ── Post type info ────────────────────────────────────────────────────────────

class _TypeInfo {
  final String label;
  final Color Function(AppColorsExtension) badgeBg;
  final Color Function(AppColorsExtension) badgeText;
  const _TypeInfo({
    required this.label,
    required this.badgeBg,
    required this.badgeText,
  });
}

_TypeInfo _typeInfo(PostType type) {
  return switch (type) {
    PostType.question => _TypeInfo(
      label: 'Question',
      badgeBg: (c) => c.primary.withValues(alpha: 0.12),
      badgeText: (c) => c.primary,
    ),
    PostType.helpRequest => _TypeInfo(
      label: 'Help',
      badgeBg: (c) => const Color(0xFFF59E0B).withValues(alpha: 0.12),
      badgeText: (_) => const Color(0xFFB45309),
    ),
    PostType.achievement => _TypeInfo(
      label: 'Achievement',
      badgeBg: (c) => const Color(0xFF22C55E).withValues(alpha: 0.12),
      badgeText: (_) => const Color(0xFF16A34A),
    ),
    PostType.image => _TypeInfo(
      label: 'Photo',
      badgeBg: (c) => const Color(0xFF3B82F6).withValues(alpha: 0.12),
      badgeText: (_) => const Color(0xFF2563EB),
    ),
    PostType.video => _TypeInfo(
      label: 'Video',
      badgeBg: (c) => const Color(0xFFEF4444).withValues(alpha: 0.12),
      badgeText: (_) => const Color(0xFFDC2626),
    ),
    _ => _TypeInfo(
      label: 'Post',
      badgeBg: (c) => c.field,
      badgeText: (c) => c.textMuted,
    ),
  };
}

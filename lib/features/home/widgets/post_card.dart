import 'package:flutter/material.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_theme.dart';

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
      );
    }

    return _TextPostCard(
      post: post,
      onTap: onTap,
      onLike: onLike,
      onSave: onSave,
      onComment: onComment,
    );
  }
}

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

  String _pillLabel(BuildContext context) {
    final style = _ThemeResolver.typeStyle(context, post.type);
    if (post.type == PostType.helpRequest && (post.rewardKarma ?? 0) > 0) {
      return 'Help · ${post.rewardKarma} ⚡';
    }
    return style.label;
  }

  @override
  Widget build(BuildContext context) {
    final style = _ThemeResolver.typeStyle(context, post.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 160),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: style.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned(
              top: -4,
              right: -2,
              child: Text(style.emoji, style: const TextStyle(fontSize: 52)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: style.pillBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _pillLabel(context),
                    style: TextStyle(
                      color: style.pillText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (post.title.isNotEmpty)
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _ThemeResolver.textHi(context),
                      height: 1.25,
                      letterSpacing: -0.2,
                    ),
                  ),
                if (post.body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    post.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: _ThemeResolver.textBody(context),
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniAvatar(
                      name: post.authorName,
                      imageUrl: post.authorAvatarUrl,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${post.authorUsername} · ${_formatTime(post.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: _ThemeResolver.textDim(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _FooterStat(
                      icon: post.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: post.isLiked
                          ? _ThemeResolver.like(context)
                          : _ThemeResolver.iconMuted(context),
                      label: _compact(post.likeCount),
                      onTap: onLike,
                    ),
                    const SizedBox(width: 10),
                    _FooterStat(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: _ThemeResolver.iconMuted(context),
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
                            ? context.colors.primary
                            : _ThemeResolver.iconMuted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 360,
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasImage
                  ? Image.network(
                      post.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _FallbackBg(),
                    )
                  : const _FallbackBg(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.30, 1.0],
                    colors: [
                      Colors.transparent,
                      Color(0x44000000),
                      Color(0xE0000000),
                    ],
                  ),
                ),
              ),
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
      backgroundColor: context.colors.primary,
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: !hasImage
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ThemeResolver.textDim(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final Post post;

  const _AuthorRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: context.colors.primary,
          backgroundImage: hasAvatar
              ? NetworkImage(post.authorAvatarUrl!)
              : null,
          child: !hasAvatar
              ? Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                post.authorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatTime(post.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
    return Row(
      children: [
        _MediaStatBtn(
          icon: post.isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          iconColor: post.isLiked ? _ThemeResolver.like(context) : Colors.white,
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
            color: post.isSaved ? context.colors.primary : Colors.white,
            size: 22,
          ),
        ),
      ],
    );
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
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackBg extends StatelessWidget {
  const _FallbackBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
    );
  }
}

class _ThemeResolver {
  const _ThemeResolver._();

  static Color textHi(BuildContext context) => context.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;

  static Color textBody(BuildContext context) => context.isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  static Color textDim(BuildContext context) =>
      context.isDarkMode ? AppColors.darkTextDim : AppColors.lightTextDim;

  static Color iconMuted(BuildContext context) =>
      context.isDarkMode ? AppColors.darkTextMuted : AppColors.lightTextDim;

  static Color like(BuildContext context) => AppColors.error;

  static _TypeStyle typeStyle(BuildContext context, PostType type) {
    return switch (type) {
      PostType.question => _TypeStyle(
        bg: context.isDarkMode
            ? AppColors.success.withOpacity(0.16)
            : AppColors.successBg,
        border: context.isDarkMode
            ? AppColors.success.withOpacity(0.34)
            : AppColors.successBorder,
        pillBg: AppColors.success,
        pillText: Colors.white,
        label: 'Question',
        emoji: '?',
      ),
      PostType.helpRequest => _TypeStyle(
        bg: context.isDarkMode
            ? AppColors.warningKarma.withOpacity(0.14)
            : AppColors.warningKarmaBg,
        border: context.isDarkMode
            ? AppColors.warningKarma.withOpacity(0.34)
            : AppColors.warningKarmaBorder,
        pillBg: AppColors.warningKarma,
        pillText: Colors.white,
        label: 'Help',
        emoji: '🤝',
      ),
      PostType.achievement => _TypeStyle(
        bg: context.isDarkMode
            ? AppColors.accent.withOpacity(0.15)
            : AppColors.primaryLight.withOpacity(0.12),
        border: context.isDarkMode
            ? AppColors.accent.withOpacity(0.34)
            : AppColors.primaryLight.withOpacity(0.32),
        pillBg: AppColors.accent,
        pillText: Colors.white,
        label: 'Achievement',
        emoji: '🏆',
      ),
      _ => _TypeStyle(
        bg: context.colors.surfaceContainerHighest,
        border: context.colors.outline,
        pillBg: context.colors.primary,
        pillText: Colors.white,
        label: 'Text',
        emoji: '💬',
      ),
    };
  }
}

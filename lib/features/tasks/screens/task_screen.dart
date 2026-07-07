import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../home/screens/post_detail_screen.dart';
import '../../../core/karma/karma_badge.dart';
import '../../../core/karma/karma_ledger_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../core/services/notification_service.dart';

class HelpRequestScreen extends StatefulWidget {
  const HelpRequestScreen({super.key});

  @override
  State<HelpRequestScreen> createState() => _HelpRequestScreenState();
}

class _HelpRequestScreenState extends State<HelpRequestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Filter: null = all, true = open, false = closed
  bool? _filterOpen = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverHeader(context)],
        body: TabBarView(
          controller: _tab,
          children: [
            _RequestsTab(
              myUid: _myUid,
              filterOpen: _filterOpen,
              onFilterChanged: (v) => setState(() => _filterOpen = v),
            ),
            _LeaderboardTab(myUid: _myUid),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    final colors = context.colors;
    final tabBarTheme = Theme.of(context).tabBarTheme;

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 130,
      backgroundColor: colors.surface,
      elevation: 0,
      leading: const SizedBox.shrink(),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: BoxDecoration(gradient: context.appColors.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Help Requests',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ask the community · Earn karma',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_myUid.isNotEmpty)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const KarmaLedgerScreen(),
                        ),
                      ),
                      child: KarmaBadge(
                        uid: _myUid,
                        size: KarmaBadgeSize.medium,
                        showLabel: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: Container(
          color: colors.surface,
          child: TabBar(
            controller: _tab,
            labelColor: tabBarTheme.labelColor ?? colors.primary,
            unselectedLabelColor:
                tabBarTheme.unselectedLabelColor ??
                context.appColors.textDim,
            labelStyle:
                tabBarTheme.labelStyle ??
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                tabBarTheme.unselectedLabelStyle ??
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            indicatorColor: tabBarTheme.indicatorColor ?? colors.primary,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Requests'),
              Tab(text: 'Leaderboard'),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  final String myUid;
  final bool? filterOpen;
  final ValueChanged<bool?> onFilterChanged;

  const _RequestsTab({
    required this.myUid,
    required this.filterOpen,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'helpRequest')
        .orderBy('createdAt', descending: true);

    if (filterOpen != null) {
      query = query.where('isCompleted', isEqualTo: !filterOpen!);
    }

    return Column(
      children: [
        Container(
          color: context.colors.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: filterOpen == null,
                onTap: () => onFilterChanged(null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '🟢 Open',
                selected: filterOpen == true,
                onTap: () => onFilterChanged(true),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '✓ Resolved',
                selected: filterOpen == false,
                onTap: () => onFilterChanged(false),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: context.colors.primary,
                    strokeWidth: 2,
                  ),
                );
              }
              if (snap.hasError) {
                return _EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load requests',
                  subtitle: snap.error.toString(),
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _EmptyState(
                  icon: Icons.handshake_outlined,
                  title: filterOpen == false
                      ? 'No resolved requests yet'
                      : 'No open requests',
                  subtitle: filterOpen == false
                      ? 'Resolved help requests will appear here.'
                      : 'Be the first to ask for help!',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final post = Post.fromFirestore(docs[i], myUid);
                  final data = docs[i].data() as Map<String, dynamic>;
                  final isCompleted = data['isCompleted'] == true;
                  final reward = (data['rewardKarma'] as num?)?.toInt() ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HelpCard(
                      post: post,
                      isCompleted: isCompleted,
                      reward: reward,
                      myUid: myUid,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: post),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HelpCard extends StatelessWidget {
  final Post post;
  final bool isCompleted;
  final int reward;
  final String myUid;
  final VoidCallback onTap;

  const _HelpCard({
    required this.post,
    required this.isCompleted,
    required this.reward,
    required this.myUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PostCard(
          post: post,
          onTap: onTap,
          onLike: () {
            NotificationService.toggleLike(
              postId: post.id,
              postAuthorId: post.authorId,
              postTitle: post.title,
              currentUid: myUid,
              likedBy: post.isLiked ? [myUid] : [],
            );
          },
          onSave: () {
            final ref = FirebaseFirestore.instance.collection('posts').doc(post.id);
            if (post.isSaved) {
              ref.update({'savedBy': FieldValue.arrayRemove([myUid])});
            } else {
              ref.update({'savedBy': FieldValue.arrayUnion([myUid])});
            }
          },
          onComment: onTap,
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            children: [
              if (reward > 0) _RewardBadge(reward: reward),
              if (reward > 0) const SizedBox(width: 6),
              _StatusBadge(isCompleted: isCompleted),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final int reward;

  const _RewardBadge({required this.reward});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.appColors.warningKarmaBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appColors.warningKarmaBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            color: context.appColors.warningKarma,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            '$reward',
            style: TextStyle(
              color: context.appColors.warningKarma,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isCompleted;

  const _StatusBadge({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? context.appColors.successBg
            : context.appColors.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted
              ? context.appColors.successBorder
              : context.appColors.chipBorder,
        ),
      ),
      child: Text(
        isCompleted ? '✓ Resolved' : '● Open',
        style: TextStyle(
          color: isCompleted
              ? context.appColors.success
              : context.appColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LeaderboardTab extends StatefulWidget {
  final String myUid;
  const _LeaderboardTab({required this.myUid});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  String _selectedCategory = 'karma';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final String orderByField;
    final IconData icon;
    final Color pointColor;

    switch (_selectedCategory) {
      case 'beauty':
        orderByField = 'beautyPoints';
        icon = Icons.favorite_rounded;
        pointColor = Colors.pinkAccent;
        break;
      case 'art':
        orderByField = 'artPoints';
        icon = Icons.palette_rounded;
        pointColor = Colors.orangeAccent;
        break;
      case 'funny':
        orderByField = 'funnyPoints';
        icon = Icons.emoji_emotions_rounded;
        pointColor = Colors.amber;
        break;
      case 'karma':
      default:
        orderByField = 'karmaBalance';
        icon = Icons.bolt_rounded;
        pointColor = c.primary;
        break;
    }

    return Column(
      children: [
        Container(
          color: context.colors.surface,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Karma ⚡',
                  selected: _selectedCategory == 'karma',
                  onTap: () => setState(() => _selectedCategory = 'karma'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Beauty 💖',
                  selected: _selectedCategory == 'beauty',
                  onTap: () => setState(() => _selectedCategory = 'beauty'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Art 🎨',
                  selected: _selectedCategory == 'art',
                  onTap: () => setState(() => _selectedCategory = 'art'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Funny 😂',
                  selected: _selectedCategory == 'funny',
                  onTap: () => setState(() => _selectedCategory = 'funny'),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: context.appColors.border),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy(orderByField, descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: context.colors.primary,
                    strokeWidth: 2,
                  ),
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No rankings yet',
                  subtitle: 'Earn points to appear here!',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final rank = i + 1;
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final isMe = doc.id == widget.myUid;
                  final points = (data[orderByField] as num?)?.toInt() ?? 0;
                  final name = data['name'] as String? ?? 'User';
                  final avatar =
                      data['profileImageUrl'] as String? ??
                      data['photoURL'] as String?;
                  final username = data['username'] as String? ?? '';

                  return _LeaderRow(
                    rank: rank,
                    name: name,
                    username: username,
                    avatar: avatar,
                    userId: doc.id,
                    karma: points,
                    isMe: isMe,
                    icon: icon,
                    pointColor: pointColor,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}



class _LeaderRow extends StatelessWidget {
  final int rank;
  final String name;
  final String username;
  final String? avatar;
  final String userId;
  final int karma;
  final bool isMe;
  final IconData icon;
  final Color pointColor;

  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.username,
    required this.avatar,
    required this.userId,
    required this.karma,
    required this.isMe,
    required this.icon,
    required this.pointColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? context.appColors.field
            : context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? context.colors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isMe
                    ? context.colors.primary
                    : context.appColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CustomAvatar(
            name: name,
            imageUrl: avatar,
            userId: userId,
            radius: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textHi,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (username.isNotEmpty)
                  Text(
                    username.startsWith('@') ? username : '@$username',
                    style: TextStyle(
                      color: context.appColors.textDim,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                icon,
                color: pointColor,
                size: 14,
              ),
              const SizedBox(width: 2),
              Text(
                _compact(karma),
                style: TextStyle(
                  color: pointColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary
              : context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? context.colors.primary
                : context.appColors.chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.colors.primary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.appColors.textDim, size: 44),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.appColors.textHi,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textDim,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

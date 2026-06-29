import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../home/screens/post_detail_screen.dart';
import '../../../core/karma/karma_service.dart';
import '../../../core/karma/karma_badge.dart';
import '../../../core/karma/karma_ledger_screen.dart';


class HelpRequestScreen extends StatefulWidget {
  const HelpRequestScreen({super.key});

  @override
  State<HelpRequestScreen> createState() => _HelpRequestScreenState();
}

class _HelpRequestScreenState extends State<HelpRequestScreen>
    with SingleTickerProviderStateMixin {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bg       = Color(0xFFEEF0FB);
  static const Color _primary  = Color(0xFF6C63D5);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _textHi   = Color(0xFF2D1B69);
  static const Color _textDim  = Color(0xFF9E9BD0);
  static const Color _amber    = Color(0xFFC9830A);
  static const Color _amberBg  = Color(0xFFFFF8EC);
  static const Color _green    = Color(0xFF388E3C);

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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverHeader()],
        body: TabBarView(
          controller: _tab,
          children: [
            _RequestsTab(
              myUid:      _myUid,
              filterOpen: _filterOpen,
              onFilterChanged: (v) => setState(() => _filterOpen = v),
            ),
            _LeaderboardTab(myUid: _myUid),
          ],
        ),
      ),
    );
  }

  // ── Sliver header ──────────────────────────────────────────────────────────
  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 130,
      backgroundColor: _surface,
      elevation: 0,
      leading: const SizedBox.shrink(),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C63D5), Color(0xFF9B8FEA)],
            ),
          ),
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
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // My karma badge — taps into ledger
                  if (_myUid.isNotEmpty)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const KarmaLedgerScreen())),
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
      // Tab bar pinned at bottom of app bar
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: Container(
          color: _surface,
          child: TabBar(
            controller: _tab,
            labelColor: _primary,
            unselectedLabelColor: _textDim,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            indicatorColor: _primary,
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

// ─── Tab 1: Requests ──────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final String myUid;
  final bool? filterOpen;
  final ValueChanged<bool?> onFilterChanged;

  const _RequestsTab({
    required this.myUid,
    required this.filterOpen,
    required this.onFilterChanged,
  });

  static const Color _primary = Color(0xFF6C63D5);
  static const Color _textDim = Color(0xFF9E9BD0);
  static const Color _textHi  = Color(0xFF2D1B69);

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
        // ── Filter chips ─────────────────────────────────────────────────
        Container(
          color: Colors.white,
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

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: _primary, strokeWidth: 2));
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
                      post:        post,
                      isCompleted: isCompleted,
                      reward:      reward,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: post)),
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

// ── Help card (wraps PostCard + status badge) ─────────────────────────────────

class _HelpCard extends StatelessWidget {
  final Post post;
  final bool isCompleted;
  final int reward;
  final VoidCallback onTap;

  const _HelpCard({
    required this.post,
    required this.isCompleted,
    required this.reward,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PostCard(
          post:      post,
          onTap:     onTap,
          onLike:    () {},
          onSave:    () {},
          onComment: onTap,
        ),
        // Status + reward badge top-right
        Positioned(
          top: 12, right: 12,
          child: Row(
            children: [
              if (reward > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF5DCAA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: Color(0xFFC9830A), size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '$reward',
                        style: const TextStyle(
                          color: Color(0xFF7A5010),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (reward > 0) const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFEDE7FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFFA5D6A7)
                        : const Color(0xFFB39DDB),
                  ),
                ),
                child: Text(
                  isCompleted ? '✓ Resolved' : '● Open',
                  style: TextStyle(
                    color: isCompleted
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF5E35B1),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Tab 2: Leaderboard ───────────────────────────────────────────────────────

class _LeaderboardTab extends StatelessWidget {
  final String myUid;

  const _LeaderboardTab({required this.myUid});

  static const Color _primary = Color(0xFF6C63D5);
  static const Color _textDim = Color(0xFF9E9BD0);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('karmaBalance', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: _primary, strokeWidth: 2));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'No rankings yet',
            subtitle: 'Answer help requests to appear here!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          itemCount: docs.length + 1, // +1 for podium header
          itemBuilder: (context, i) {
            if (i == 0) {
              // Podium for top 3
              if (docs.length >= 3) {
                return _Podium(docs: docs.take(3).toList(), myUid: myUid);
              }
              return const SizedBox.shrink();
            }

            final rank    = i; // 1-indexed (i == 1 → rank 1, etc.)
            final doc     = docs[i - 1];
            final data    = doc.data() as Map<String, dynamic>;
            final isMe    = doc.id == myUid;
            final karma   = (data['karmaBalance'] as num?)?.toInt() ?? 0;
            final name    = data['name'] as String? ?? 'User';
            final avatar  = data['profileImageUrl'] as String? ??
                data['photoURL'] as String?;
            final username = data['username'] as String? ?? '';

            // Skip top 3 — already shown in podium
            if (rank <= 3) return const SizedBox.shrink();

            return _LeaderRow(
              rank:     rank,
              name:     name,
              username: username,
              avatar:   avatar,
              karma:    karma,
              isMe:     isMe,
            );
          },
        );
      },
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String myUid;

  const _Podium({required this.docs, required this.myUid});

  @override
  Widget build(BuildContext context) {
    // Order: 2nd (left), 1st (centre, tallest), 3rd (right)
    final order = [1, 0, 2]; // indices into docs[]

    final heights = [88.0, 116.0, 72.0];
    final colors  = [
      const Color(0xFFC0C0C0), // silver
      const Color(0xFFFFD700), // gold
      const Color(0xFFCD7F32), // bronze
    ];
    final crowns = ['🥈', '🥇', '🥉'];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63D5).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '🏆  Top Karma Earners',
            style: TextStyle(
              color: Color(0xFF2D1B69),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (slot) {
              final docIdx = order[slot];
              final doc    = docs[docIdx];
              final data   = doc.data() as Map<String, dynamic>;
              final name   = (data['name'] as String? ?? 'User')
                  .split(' ')
                  .first;
              final avatar = data['profileImageUrl'] as String? ??
                  data['photoURL'] as String?;
              final karma  = (data['karmaBalance'] as num?)?.toInt() ?? 0;
              final rank   = docIdx + 1;
              final isMe   = doc.id == myUid;

              return Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: slot == 1 ? 12.0 : 6.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Crown emoji
                    Text(crowns[slot], style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    // Avatar
                    Container(
                      width: slot == 1 ? 60 : 48,
                      height: slot == 1 ? 60 : 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isMe
                              ? const Color(0xFF6C63D5)
                              : colors[slot],
                          width: slot == 1 ? 3 : 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: slot == 1 ? 28 : 22,
                        backgroundColor: const Color(0xFFF5F4FF),
                        backgroundImage: avatar != null && avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar == null || avatar.isEmpty
                            ? Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: const Color(0xFF6C63D5),
                                  fontSize: slot == 1 ? 20 : 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: TextStyle(
                        color: const Color(0xFF2D1B69),
                        fontSize: slot == 1 ? 13 : 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded,
                            color: colors[slot],
                            size: slot == 1 ? 14 : 12),
                        Text(
                          _compact(karma),
                          style: TextStyle(
                            color: colors[slot],
                            fontSize: slot == 1 ? 13 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Podium block
                    Container(
                      width: slot == 1 ? 80 : 64,
                      height: heights[slot],
                      decoration: BoxDecoration(
                        color: colors[slot].withOpacity(0.15),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                        border: Border.all(
                            color: colors[slot].withOpacity(0.4)),
                      ),
                      child: Center(
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: colors[slot],
                            fontSize: slot == 1 ? 18 : 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
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

// ── Leaderboard row (rank 4+) ─────────────────────────────────────────────────

class _LeaderRow extends StatelessWidget {
  final int rank;
  final String name;
  final String username;
  final String? avatar;
  final int karma;
  final bool isMe;

  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.username,
    required this.avatar,
    required this.karma,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFFF0EEFF)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? const Color(0xFF6C63D5).withOpacity(0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(children: [
        // Rank number
        SizedBox(
          width: 28,
          child: Text(
            '#$rank',
            style: TextStyle(
              color: isMe
                  ? const Color(0xFF6C63D5)
                  : const Color(0xFF9E9BD0),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // Avatar
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFF5F4FF),
          backgroundImage:
              avatar != null && avatar!.isNotEmpty
                  ? NetworkImage(avatar!)
                  : null,
          child: (avatar == null || avatar!.isEmpty)
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Color(0xFF6C63D5),
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                )
              : null,
        ),
        const SizedBox(width: 12),
        // Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF2D1B69),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63D5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('You',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              if (username.isNotEmpty)
                Text(
                  username.startsWith('@') ? username : '@$username',
                  style: const TextStyle(
                      color: Color(0xFF9E9BD0), fontSize: 11),
                ),
            ],
          ),
        ),
        // Karma
        Row(children: [
          const Icon(Icons.bolt_rounded,
              color: Color(0xFFC9830A), size: 14),
          const SizedBox(width: 2),
          Text(
            _compact(karma),
            style: const TextStyle(
              color: Color(0xFF7A5010),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ]),
    );
  }

  String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63D5)
              : const Color(0xFFF5F4FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63D5)
                : const Color(0xFFD8D5F8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6C63D5),
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF9E9BD0), size: 44),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF2D1B69),
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF9E9BD0), fontSize: 12)),
      ]),
    );
  }
}
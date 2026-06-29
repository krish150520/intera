import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../videos/screens/community_detail_screen.dart';
import 'user_profile_screen.dart';
import '../../../core/karma/karma_service.dart';
import '../../../core/karma/karma_badge.dart';
import '../../../core/karma/karma_ledger_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF6C63D5);
  static const Color _pageBg     = Color(0xFFEEF0FB);
  static const Color _fieldBg    = Color(0xFFF5F4FF);
  static const Color _textDark   = Color(0xFF2D2A6E);
  static const Color _textMuted  = Color(0xFF8884BB);
  static const Color _cardBorder = Color(0xFFE4E2F8);

  // Weekly bonus state
  bool _claimingBonus  = false;
  bool _bonusAvailable = false;
  DateTime? _nextClaimAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkWeeklyBonus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Weekly bonus logic ─────────────────────────────────────────────────────

  Future<void> _checkWeeklyBonus() async {
    if (_currentUid.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .get();
    final data = doc.data() ?? {};
    final lastClaim = data['lastWeeklyKarmaClaim'];

    if (lastClaim == null) {
      if (mounted) setState(() => _bonusAvailable = true);
      return;
    }

    final last = (lastClaim as Timestamp).toDate();
    final next = last.add(const Duration(days: 7));
    final now  = DateTime.now();

    if (mounted) {
      setState(() {
        _bonusAvailable = now.isAfter(next);
        _nextClaimAt    = _bonusAvailable ? null : next;
      });
    }
  }

  Future<void> _claimWeeklyBonus() async {
    if (!_bonusAvailable || _claimingBonus || _currentUid.isEmpty) return;
    setState(() => _claimingBonus = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUid);

      // Credit 100 karma
      batch.update(userRef, {
        'karmaBalance':       FieldValue.increment(100),
        'lastWeeklyKarmaClaim': FieldValue.serverTimestamp(),
      });

      // Ledger entry
      final txRef = FirebaseFirestore.instance.collection('karmaTransactions').doc();
      batch.set(txRef, {
        'fromUid':   null,
        'toUid':     _currentUid,
        'amount':    100,
        'type':      'weeklyBonus',
        'note':      'Weekly login bonus',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _bonusAvailable = false;
        _nextClaimAt    = DateTime.now().add(const Duration(days: 7));
      });

      _snack('🎉 +100 karma claimed! Come back next week.');
    } catch (e) {
      if (mounted) _snack('Failed to claim: $e');
    } finally {
      if (mounted) setState(() => _claimingBonus = false);
    }
  }

  String _daysUntilNextClaim() {
    if (_nextClaimAt == null) return '';
    final diff = _nextClaimAt!.difference(DateTime.now());
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d ${diff.inHours % 24}h';
  }

  // ── Communities sheet ──────────────────────────────────────────────────────

  void _showMyCommunitiesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _cardBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('My communities',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
            ),
            const Divider(height: 1, color: Color(0xFFEAE8FB)),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('communities')
                    .where('members', arrayContains: _currentUid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(color: _primary)));
                  }
                  final communities = snapshot.data?.docs ?? [];
                  if (communities.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'You haven\'t joined any communities yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textMuted, fontSize: 13),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: communities.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Color(0xFFEAE8FB)),
                    itemBuilder: (context, index) {
                      final doc  = communities[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String name     = data['name'] ?? 'Unnamed';
                      final String desc     = data['description'] ?? '';
                      final bool isCreator  = (data['creatorId'] ?? '') == _currentUid;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _fieldBg,
                          child: const Icon(Icons.groups_rounded,
                              color: _primary, size: 20),
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _textDark)),
                        subtitle: desc.isNotEmpty
                            ? Text(desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: _textMuted))
                            : null,
                        trailing: isCreator
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  Navigator.pop(sheetCtx);
                                  _confirmAndPurgeCommunity(
                                      context, doc.id, name);
                                },
                              )
                            : const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFFB0ADDE)),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CommunityDetailScreen(
                              communityId: doc.id,
                              communityName: name,
                              communityDescription: desc,
                            ),
                          ));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAndPurgeCommunity(
      BuildContext context, String communityId, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Disband $name?',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _textDark,
                fontSize: 16)),
        content: const Text(
            'This action is permanent. All data tied to this community will be removed.',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await FirebaseFirestore.instance
                    .collection('communities')
                    .doc(communityId)
                    .delete();
                if (context.mounted) _snack(context, 'Community removed.');
              } catch (e) {
                if (context.mounted)
                  _snack(context, 'Failed: $e');
              }
            },
            child: const Text('Disband',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snack(dynamic contextOrMsg, [String? msgArg, Color? color]) {
    // Supports both _snack(msg) and _snack(context, msg, color:...)
    final BuildContext ctx  = contextOrMsg is BuildContext ? contextOrMsg : context;
    final String msg        = contextOrMsg is String ? contextOrMsg : (msgArg ?? '');
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_currentUid.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Please sign in to view your profile.')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .snapshots(),
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return Scaffold(
              body: Center(child: Text('Error: ${userSnap.error}')));
        }
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: _primary)));
        }

        final ud = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final String displayName =
            ud['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'User';
        final String handle   = ud['username'] ?? 'anonymous';
        final String? avatarUrl =
            ud['avatarUrl'] ?? FirebaseAuth.instance.currentUser?.photoURL;
        final String bio      = ud['bio'] ?? 'No bio yet.';
        final int followers   = ud['followersCount'] ?? 0;
        final int following   = ud['followingCount'] ?? 0;
        final List<String> hobbies = List<String>.from(
            ud['hobbiesAndInterests'] ?? ud['skills'] ?? []);

        return Scaffold(
          backgroundColor: _pageBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              handle.startsWith('@') ? handle : '@$handle',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _textDark),
            ),
            actions: [
              // Karma badge → ledger
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const KarmaLedgerScreen())),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: KarmaBadge(
                        uid: _currentUid,
                        size: KarmaBadgeSize.small),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 10),
                width: 36, height: 36,
                decoration:
                    BoxDecoration(color: _fieldBg, shape: BoxShape.circle),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.settings_outlined,
                      size: 18, color: _primary),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Profile header ─────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _primary, width: 2),
                          ),
                          child: CustomAvatar(
                              name: displayName,
                              imageUrl: avatarUrl,
                              radius: 34),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Karma stat — live stream, taps ledger
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const KarmaLedgerScreen())),
                                child: StreamBuilder<int>(
                                  stream: KarmaService.balanceStream(_currentUid),
                                  builder: (context, snap) {
                                    final k = snap.data ?? 0;
                                    return _StatColumn(
                                      value: k >= 1000
                                          ? '${(k / 1000).toStringAsFixed(1)}k'
                                          : '$k',
                                      label: 'Karma',
                                      valueColor: const Color(0xFFC9830A),
                                      icon: Icons.bolt_rounded,
                                    );
                                  },
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => _ConnectionsListScreen(
                                          userId: _currentUid,
                                          isFollowersMode: true,
                                          profileOwnerName: displayName,
                                        ))),
                                child: _StatColumn(
                                    value: '$followers',
                                    label: AppStrings.followers),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => _ConnectionsListScreen(
                                          userId: _currentUid,
                                          isFollowersMode: false,
                                          profileOwnerName: displayName,
                                        ))),
                                child: _StatColumn(
                                    value: '$following',
                                    label: AppStrings.following),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Text(displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: _textDark)),
                    const SizedBox(height: 4),
                    Text(bio,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5A587A),
                            height: 1.4)),

                    if (hobbies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: hobbies.map((h) => _HobbyChip(label: h)).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Weekly bonus banner ──────────────────────────────
                    _WeeklyBonusBanner(
                      available:    _bonusAvailable,
                      claiming:     _claimingBonus,
                      nextClaimAt:  _nextClaimAt,
                      timeLabel:    _daysUntilNextClaim(),
                      onClaim:      _claimWeeklyBonus,
                    ),

                    const SizedBox(height: 12),

                    // ── Action buttons ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _OutlineButton(
                            label: AppStrings.editProfile,
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.editProfile),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _OutlineButton(
                            label: 'Communities',
                            onTap: () => _showMyCommunitiesSheet(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Tab bar ────────────────────────────────────────────────
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: _primary,
                  unselectedLabelColor: _textMuted,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  indicator: UnderlineTabIndicator(
                    borderSide: const BorderSide(color: _primary, width: 2.5),
                    insets: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  tabs: const [
                    Tab(text: AppStrings.posts),
                    Tab(text: AppStrings.videos),
                    Tab(text: AppStrings.answers),
                  ],
                ),
              ),

              // ── Tab content ────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ProfileContentList(authorId: _currentUid, targetType: 'posts'),
                    _ProfileContentList(authorId: _currentUid, targetType: 'video'),
                    _ProfileContentList(authorId: _currentUid, targetType: 'question'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Weekly bonus banner ──────────────────────────────────────────────────────

class _WeeklyBonusBanner extends StatelessWidget {
  final bool available;
  final bool claiming;
  final DateTime? nextClaimAt;
  final String timeLabel;
  final VoidCallback onClaim;

  const _WeeklyBonusBanner({
    required this.available,
    required this.claiming,
    required this.nextClaimAt,
    required this.timeLabel,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: available
            ? const LinearGradient(
                colors: [Color(0xFFFFF3CD), Color(0xFFFFE57F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: available ? null : const Color(0xFFF5F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: available
              ? const Color(0xFFFFCA28)
              : const Color(0xFFE4E2F8),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: available
                  ? const Color(0xFFC9830A).withOpacity(0.12)
                  : const Color(0xFF6C63D5).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              available ? Icons.card_giftcard_rounded : Icons.hourglass_bottom_rounded,
              color: available
                  ? const Color(0xFFC9830A)
                  : const Color(0xFF9E9BD0),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available ? 'Weekly bonus ready!' : 'Next bonus in $timeLabel',
                  style: TextStyle(
                    color: available
                        ? const Color(0xFF7A5010)
                        : const Color(0xFF2D2A6E),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'Claim your +100 ⚡ karma now'
                      : 'Come back to claim +100 ⚡ karma',
                  style: TextStyle(
                    color: available
                        ? const Color(0xFFA06820)
                        : const Color(0xFF9E9BD0),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Claim button
          if (available)
            GestureDetector(
              onTap: claiming ? null : onClaim,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: claiming
                      ? const Color(0xFFF5DCAA)
                      : const Color(0xFFC9830A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: claiming
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Claim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final IconData? icon;

  const _StatColumn({
    required this.value,
    required this.label,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: valueColor ?? const Color(0xFF2D2A6E), size: 14),
                const SizedBox(width: 2),
              ],
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: valueColor ?? const Color(0xFF2D2A6E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8884BB))),
        ],
      );
}

class _HobbyChip extends StatelessWidget {
  final String label;
  const _HobbyChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EEFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8D5F8)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6C63D5))),
      );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8D5F8), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C63D5))),
        ),
      );
}

// ─── Profile content list ─────────────────────────────────────────────────────

class _ProfileContentList extends StatelessWidget {
  final String authorId;
  final String targetType;
  const _ProfileContentList(
      {required this.authorId, required this.targetType});

  void _confirmAndPurgePost(
      BuildContext context, String docId, String? mediaUrl) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete post?',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2A6E),
                fontSize: 16)),
        content: const Text('This will permanently remove this post.',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8884BB))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                if (mediaUrl != null &&
                    mediaUrl.isNotEmpty &&
                    mediaUrl.contains('firebase')) {
                  try {
                    await FirebaseStorage.instance
                        .refFromURL(mediaUrl)
                        .delete();
                  } catch (_) {}
                }
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(docId)
                    .delete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Post removed.'),
                          behavior: SnackBarBehavior.floating));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: authorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(fontSize: 12)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF6C63D5), strokeWidth: 2));
        }

        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final String type = data['type'] ?? 'text';
          if (targetType == 'posts') {
            return ['text', 'image', 'achievement', 'helpRequest']
                .contains(type);
          }
          return type == targetType;
        }).toList()
          ..sort((a, b) {
            final aT = (a.data() as Map<String, dynamic>)['createdAt']
                as Timestamp?;
            final bT = (b.data() as Map<String, dynamic>)['createdAt']
                as Timestamp?;
            if (aT == null || bT == null) return 0;
            return bT.compareTo(aT);
          });

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  targetType == 'video'
                      ? Icons.videocam_off_outlined
                      : targetType == 'question'
                          ? Icons.help_outline_rounded
                          : Icons.article_outlined,
                  size: 40,
                  color: const Color(0xFFD8D5F8),
                ),
                const SizedBox(height: 10),
                Text('No $targetType yet',
                    style: const TextStyle(
                        color: Color(0xFF9E9BD0), fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc  = filtered[index];
            final data = doc.data() as Map<String, dynamic>;
            final post = Post.fromFirestore(doc, authorId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onLongPress: () =>
                    _confirmAndPurgePost(context, doc.id, data['mediaUrl']),
                child: PostCard(
                  post: post,
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppRoutes.postDetail, arguments: post),
                  onLike: () {
                    final ref = FirebaseFirestore.instance
                        .collection('posts')
                        .doc(doc.id);
                    if (post.isLiked) {
                      ref.update({
                        'likeCount': FieldValue.increment(-1),
                        'likedBy': FieldValue.arrayRemove([authorId])
                      });
                    } else {
                      ref.update({
                        'likeCount': FieldValue.increment(1),
                        'likedBy': FieldValue.arrayUnion([authorId])
                      });
                    }
                  },
                  onComment: () => Navigator.of(context)
                      .pushNamed(AppRoutes.postDetail, arguments: post),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Connections list screen ──────────────────────────────────────────────────

class _ConnectionsListScreen extends StatelessWidget {
  final String userId;
  final bool isFollowersMode;
  final String profileOwnerName;
  const _ConnectionsListScreen({
    required this.userId,
    required this.isFollowersMode,
    required this.profileOwnerName,
  });

  static const Color _primary   = Color(0xFF6C63D5);
  static const Color _textDark  = Color(0xFF2D2A6E);
  static const Color _textMuted = Color(0xFF8884BB);

  @override
  Widget build(BuildContext context) {
    final collectionRef = isFollowersMode
        ? FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('followers')
        : FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('following');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isFollowersMode ? 'Followers' : 'Following',
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, color: _textDark),
        ),
        foregroundColor: _textDark,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: collectionRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _primary));
          }
          final connectionDocs = snapshot.data?.docs ?? [];
          if (connectionDocs.isEmpty) {
            return Center(
              child: Text(
                isFollowersMode
                    ? 'No followers yet.'
                    : 'Not following anyone yet.',
                style: const TextStyle(color: _textMuted, fontSize: 13),
              ),
            );
          }
          return ListView.separated(
            itemCount: connectionDocs.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: Color(0xFFEAE8FB)),
            itemBuilder: (context, index) {
              final String targetUid = connectionDocs[index].id;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(targetUid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      leading: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _primary)),
                    );
                  }
                  if (!userSnapshot.hasData ||
                      !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final data     = userSnapshot.data!.data() as Map<String, dynamic>;
                  final String name     = data['name'] ?? 'User';
                  final String username = data['username'] ?? 'user';
                  final String avatar   = data['avatarUrl'] ?? '';
                  return ListTile(
                    leading: CustomAvatar(
                        name: name,
                        imageUrl: avatar.isNotEmpty ? avatar : null,
                        radius: 20),
                    title: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _textDark)),
                    subtitle: Text(
                      username.startsWith('@')
                          ? username
                          : '@$username',
                      style: const TextStyle(
                          fontSize: 12, color: _textMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFD8D5F8)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          userId: targetUid,
                          userName: name,
                          userAvatar: avatar,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
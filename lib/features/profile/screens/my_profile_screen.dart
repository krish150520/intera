import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../videos/screens/community_detail_screen.dart';
import 'user_profile_screen.dart';
import '../../../core/karma/karma_badge.dart';
import '../../../core/karma/karma_ledger_screen.dart';
import 'setting_screen.dart';
import '../../../core/karma/karma_service.dart';
import '../../../core/services/reaction_service.dart';

class MyProfileScreen extends StatefulWidget {
  final String? heroTag;
  const MyProfileScreen({super.key, this.heroTag});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _claimingBonus  = false;
  bool _bonusAvailable = false;
  DateTime? _nextClaimAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkWeeklyBonus();
    if (_currentUid.isNotEmpty) {
      ReactionService.syncUserPoints(_currentUid);
      KarmaService.syncKarmaBalance(_currentUid);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkWeeklyBonus() async {
    if (_currentUid.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
    final data = doc.data() ?? {};
    final lastClaim = data['lastWeeklyKarmaClaim'];
    if (lastClaim == null) { if (mounted) setState(() => _bonusAvailable = true); return; }
    final last = (lastClaim as Timestamp).toDate();
    final next = last.add(const Duration(days: 7));
    if (mounted) setState(() { _bonusAvailable = DateTime.now().isAfter(next); _nextClaimAt = _bonusAvailable ? null : next; });
  }

  Future<void> _claimWeeklyBonus() async {
    if (!_bonusAvailable || _claimingBonus || _currentUid.isEmpty) return;
    setState(() => _claimingBonus = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUid);
      batch.update(userRef, {'karmaBalance': FieldValue.increment(100), 'lastWeeklyKarmaClaim': FieldValue.serverTimestamp()});
      final txRef = FirebaseFirestore.instance.collection('karmaTransactions').doc();
      batch.set(txRef, {'fromUid': null, 'toUid': _currentUid, 'amount': 100, 'type': 'weeklyBonus', 'note': 'Weekly login bonus', 'createdAt': FieldValue.serverTimestamp()});
      await batch.commit();
      if (!mounted) return;
      setState(() { _bonusAvailable = false; _nextClaimAt = DateTime.now().add(const Duration(days: 7)); });
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

  void _showMyCommunitiesSheet(BuildContext context) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              width: 36, height: 4,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('My communities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textHi)),
            ),
            Divider(height: 1, color: c.divider),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('communities').where('members', arrayContains: _currentUid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: c.primary)));
                  }
                  final communities = snapshot.data?.docs ?? [];
                  if (communities.isEmpty) {
                    return Padding(padding: const EdgeInsets.all(32),
                      child: Center(child: Text('You haven\'t joined any communities yet.', textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 13))));
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: communities.length,
                    separatorBuilder: (_, __) => Divider(height: 1, indent: 20, endIndent: 20, color: c.divider),
                    itemBuilder: (context, index) {
                      final doc  = communities[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String name    = data['name'] ?? 'Unnamed';
                      final String desc    = data['description'] ?? '';
                      final bool isCreator = (data['creatorId'] ?? '') == _currentUid;
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: c.field, child: Icon(Icons.groups_rounded, color: c.primary, size: 20)),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: c.textHi)),
                        subtitle: desc.isNotEmpty ? Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textMuted)) : null,
                        trailing: isCreator
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () { Navigator.pop(sheetCtx); _confirmAndPurgeCommunity(context, doc.id, name); })
                            : Icon(Icons.chevron_right_rounded, color: c.textDim),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityDetailScreen(communityId: doc.id, communityName: name, communityDescription: desc)));
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

  void _confirmAndPurgeCommunity(BuildContext context, String communityId, String name) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Disband $name?', style: TextStyle(fontWeight: FontWeight.w700, color: c.textHi, fontSize: 16)),
        content: const Text('This action is permanent. All data tied to this community will be removed.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Cancel', style: TextStyle(color: c.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await FirebaseFirestore.instance.collection('communities').doc(communityId).delete();
                if (context.mounted) _snack(context, 'Community removed.');
              } catch (e) { if (context.mounted) _snack(context, 'Failed: $e'); }
            },
            child: const Text('Disband', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snack(dynamic contextOrMsg, [String? msgArg]) {
    final BuildContext ctx = contextOrMsg is BuildContext ? contextOrMsg : context;
    final String msg = contextOrMsg is String ? contextOrMsg : (msgArg ?? '');
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (_currentUid.isEmpty) return const Scaffold(body: Center(child: Text('Please sign in to view your profile.')));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentUid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.hasError) return Scaffold(body: Center(child: Text('Error: ${userSnap.error}')));
        if (userSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator(color: c.primary)));
        }
        final ud = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final String displayName = ud['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'User';
        final String handle      = ud['username'] ?? 'anonymous';
        final String? avatarUrl  = ud['avatarUrl'] ?? FirebaseAuth.instance.currentUser?.photoURL;
        final String bio         = ud['bio'] ?? 'No bio yet.';
        final int followers      = ud['followersCount'] ?? 0;
        final int following      = ud['followingCount'] ?? 0;
        final List<String> hobbies = List<String>.from(ud['hobbies'] ?? ud['hobbiesAndInterests'] ?? ud['skills'] ?? []);

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              handle.startsWith('@') ? handle : '@$handle',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: c.textHi),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textHi, size: 16),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KarmaLedgerScreen())),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: KarmaBadge(uid: _currentUid, size: KarmaBadgeSize.small),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.settings_outlined, size: 18, color: c.textHi),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.isDarkMode
                    ? [const Color(0xFF2A2F55), const Color(0xFF171A30), const Color(0xFF171A30)]
                    : const [Color(0xFFE5E7FF), Color(0xFFF8F9FF), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, animVal, child) {
                return Opacity(
                  opacity: animVal,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - animVal)),
                    child: child,
                  ),
                );
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // ── Animated Profile Avatar with Rings ──
                    Center(
                      child: _AnimatedProfileAvatar(
                        userName: displayName,
                        imageUrl: avatarUrl,
                        userId: _currentUid,
                        heroTag: widget.heroTag,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── User Info Section ──
                    Text(
                      displayName,
                      style: TextStyle(
                        color: c.textHi,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Bio
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (hobbies.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: hobbies.map((h) => _HobbyChip(label: h)).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Stats Row (3 Floating Glass Cards) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final String displayedType = ud['displayedPointType'] as String? ?? 'karma';
                                _showPointTypeSelector(context, displayedType);
                              },
                              child: _buildDisplayedStatCard(c, ud, ud['displayedPointType'] as String? ?? 'karma'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _ConnectionsListScreen(
                                    userId: _currentUid,
                                    isFollowersMode: true,
                                    profileOwnerName: displayName,
                                  ),
                                ),
                              ),
                              child: _StatCard(value: '$followers', label: 'Followers'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _ConnectionsListScreen(
                                    userId: _currentUid,
                                    isFollowersMode: false,
                                    profileOwnerName: displayName,
                                  ),
                                ),
                              ),
                              child: _StatCard(value: '$following', label: 'Following'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Bonus / Weekly Reward Card ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _WeeklyBonusCard(
                        available: _bonusAvailable,
                        claiming: _claimingBonus,
                        nextClaimAt: _nextClaimAt,
                        timeLabel: _daysUntilNextClaim(),
                        onClaim: _claimWeeklyBonus,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Action Buttons Row (Edit Profile / Communities) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ScalePressButton(
                              onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
                              isOutline: true,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_outlined, size: 16, color: c.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      color: c.textHi,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ScalePressButton(
                              onTap: () => _showMyCommunitiesSheet(context),
                              isOutline: true,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.groups_outlined, size: 16, color: c.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Communities',
                                    style: TextStyle(
                                      color: c.textHi,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Tab Bar selector section ──
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5), width: 1)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: c.primary,
                        unselectedLabelColor: c.textMuted,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        indicatorColor: c.primary,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicator: UnderlineTabIndicator(
                          borderSide: BorderSide(color: c.primary, width: 3),
                          insets: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        tabs: const [Tab(text: AppStrings.posts), Tab(text: AppStrings.videos)],
                      ),
                    ),

                    // ── Profile content list section ──
                    SizedBox(
                      height: 500, // scrolling bounds inside tabs
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _ProfileContentList(authorId: _currentUid, targetType: 'posts'),
                          _ProfileContentList(authorId: _currentUid, targetType: 'video'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPointTypeSelector(BuildContext context, String currentType) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Display Points Badge',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textHi,
                ),
              ),
            ),
            Divider(height: 1, color: c.divider),
            _pointTypeTile(sheetCtx, 'karma', 'Karma ⚡', currentType),
            _pointTypeTile(sheetCtx, 'beauty', 'Beauty 💖', currentType),
            _pointTypeTile(sheetCtx, 'art', 'Art 🎨', currentType),
            _pointTypeTile(sheetCtx, 'funny', 'Funny 😂', currentType),
          ],
        ),
      ),
    );
  }

  Widget _pointTypeTile(BuildContext context, String type, String label, String currentType) {
    final c = context.appColors;
    final isSelected = type == currentType;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? c.primary : c.textHi,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: c.primary) : null,
      onTap: () async {
        Navigator.pop(context);
        if (_currentUid.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUid)
              .update({'displayedPointType': type});
        }
      },
    );
  }

  Widget _buildDisplayedStatCard(AppColorsExtension c, Map<String, dynamic> ud, String displayedType) {
    final String label;
    final int val;
    final IconData icon;
    final Color valueColor;

    switch (displayedType) {
      case 'beauty':
        label = 'Beauty';
        val = (ud['beautyPoints'] as num?)?.toInt() ?? 0;
        icon = Icons.favorite_rounded;
        valueColor = Colors.pinkAccent;
        break;
      case 'art':
        label = 'Art';
        val = (ud['artPoints'] as num?)?.toInt() ?? 0;
        icon = Icons.palette_rounded;
        valueColor = Colors.orangeAccent;
        break;
      case 'funny':
        label = 'Funny';
        val = (ud['funnyPoints'] as num?)?.toInt() ?? 0;
        icon = Icons.emoji_emotions_rounded;
        valueColor = Colors.amber;
        break;
      case 'karma':
      default:
        label = 'Karma';
        val = (ud['karmaBalance'] as num?)?.toInt() ?? 0;
        icon = Icons.bolt_rounded;
        valueColor = c.primary;
        break;
    }

    final String displayVal = val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : '$val';

    return _StatCard(
      value: displayVal,
      label: label,
      valueColor: valueColor,
      icon: icon,
    );
  }
}

// ── Weekly bonus banner redesigned as glass achievement card ──

class _WeeklyBonusCard extends StatelessWidget {
  final bool available;
  final bool claiming;
  final DateTime? nextClaimAt;
  final String timeLabel;
  final VoidCallback onClaim;

  const _WeeklyBonusCard({
    required this.available,
    required this.claiming,
    required this.nextClaimAt,
    required this.timeLabel,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    double percent = 1.0;
    if (!available && nextClaimAt != null) {
      final diff = nextClaimAt!.difference(DateTime.now());
      percent = (1.0 - (diff.inSeconds / (7 * 24 * 3600))).clamp(0.0, 1.0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: context.isDarkMode ? 0.16 : 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.25 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    available ? 'Reward Ready!' : 'Next Reward',
                    style: TextStyle(
                      color: c.textHi,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (!available)
                Text(
                  '$timeLabel remaining',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: c.border.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(available ? c.primary : Colors.purpleAccent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                available ? 'Claim your +100 ⚡ karma now!' : '+100 Karma soon ⚡',
                style: TextStyle(
                  color: available ? c.primary : c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (available)
                _ScalePressButton(
                  onTap: claiming ? null : onClaim,
                  child: claiming
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Claim',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Floating Glass Stat Card widget ──

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final IconData? icon;

  const _StatCard({
    required this.value,
    required this.label,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: context.isDarkMode ? 0.16 : 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.25 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: valueColor ?? c.textHi, size: 14), const SizedBox(width: 2)],
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: valueColor ?? c.textHi,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: c.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated Profile Avatar with concentring pulsing rings ──

class _AnimatedProfileAvatar extends StatefulWidget {
  final String userName;
  final String? imageUrl;
  final String userId;
  final String? heroTag;

  const _AnimatedProfileAvatar({
    required this.userName,
    this.imageUrl,
    required this.userId,
    this.heroTag,
  });

  @override
  State<_AnimatedProfileAvatar> createState() => _AnimatedProfileAvatarState();
}

class _AnimatedProfileAvatarState extends State<_AnimatedProfileAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulseValue = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ring 3
            Container(
              width: 170 + (pulseValue * 15),
              height: 170 + (pulseValue * 15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: 0.02),
                border: Border.all(
                  color: c.primary.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
            ),
            // Outer Ring 2
            Container(
              width: 145 + (pulseValue * 10),
              height: 145 + (pulseValue * 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: 0.04),
                border: Border.all(
                  color: c.primary.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            // Outer Ring 1
            Container(
              width: 120 + (pulseValue * 5),
              height: 120 + (pulseValue * 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: 0.06),
                border: Border.all(
                  color: c.primary.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
            ),
            // Avatar wrapper with glow shadow
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: c.border,
                child: CustomAvatar(
                  name: widget.userName,
                  imageUrl: widget.imageUrl,
                  userId: widget.userId,
                  radius: 44,
                  heroTag: widget.heroTag,
                  clickable: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Custom Animated Press Scale Button ──

class _ScalePressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isOutline;

  const _ScalePressButton({
    required this.child,
    this.onTap,
    this.isOutline = false,
  });

  @override
  State<_ScalePressButton> createState() => _ScalePressButtonState();
}

class _ScalePressButtonState extends State<_ScalePressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _controller.forward(),
      onTapUp: widget.onTap == null ? null : (_) => _controller.reverse(),
      onTapCancel: widget.onTap == null ? null : () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: widget.isOutline ? c.surface : c.primary,
            border: widget.isOutline
                ? Border.all(color: c.border, width: 1.2)
                : Border.all(color: Colors.transparent, width: 0),
            boxShadow: [
              if (!widget.isOutline && widget.onTap != null)
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Hobby chip widget ──

class _HobbyChip extends StatelessWidget {
  final String label;
  const _HobbyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: context.isDarkMode ? 0.16 : 0.5),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: c.textSecondary,
        ),
      ),
    );
  }
}

// ── Profile content list ──

class _ProfileContentList extends StatelessWidget {
  final String authorId;
  final String targetType;
  const _ProfileContentList({required this.authorId, required this.targetType});

  void _confirmAndPurgePost(BuildContext context, String docId, String? mediaUrl) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete post?', style: TextStyle(fontWeight: FontWeight.w700, color: c.textHi, fontSize: 16)),
        content: const Text('This will permanently remove this post.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Cancel', style: TextStyle(color: c.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                if (mediaUrl != null && mediaUrl.isNotEmpty && mediaUrl.contains('firebase')) {
                  try { await FirebaseStorage.instance.refFromURL(mediaUrl).delete(); } catch (_) {}
                }
                await FirebaseFirestore.instance.collection('posts').doc(docId).delete();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post removed.'), behavior: SnackBarBehavior.floating));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: c.error));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').where('authorId', isEqualTo: authorId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 12)));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2));
        }
        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final String type = data['type'] ?? 'text';
          if (targetType == 'posts') return ['text', 'image', 'helpRequest'].contains(type);
          return type == targetType;
        }).toList()
          ..sort((a, b) {
            final aT = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bT = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aT == null || bT == null) return 0;
            return bT.compareTo(aT);
          });

        if (filtered.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(targetType == 'video' ? Icons.videocam_off_outlined : Icons.article_outlined, size: 40, color: c.chipBorder),
            const SizedBox(height: 10),
            Text('No $targetType yet', style: TextStyle(color: c.textMuted, fontSize: 13)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc  = filtered[index];
            final data = doc.data() as Map<String, dynamic>;
            final post = Post.fromFirestore(doc, authorId);
            return _StaggeredFadeSlide(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onLongPress: () => _confirmAndPurgePost(context, doc.id, data['mediaUrl']),
                  child: PostCard(
                    post: post,
                    heroTag: 'my_profile_post_${post.id}',
                    onTap: () {
                      if (post.type == PostType.video) {
                        final videoPosts = filtered
                            .map((d) => Post.fromFirestore(d, authorId))
                            .where((p) => p.type == PostType.video)
                            .toList();
                        final initialIdx = videoPosts.indexWhere((p) => p.id == post.id);
                        Navigator.of(context).pushNamed(
                          AppRoutes.echoViewer,
                          arguments: {
                            'posts': videoPosts,
                            'initialIndex': initialIdx >= 0 ? initialIdx : 0,
                          },
                        );
                      } else {
                        Navigator.of(context).pushNamed(
                          AppRoutes.postDetail,
                          arguments: {
                            'post': post,
                            'heroTag': 'my_profile_post_${post.id}',
                          },
                        );
                      }
                    },
                    onReact: (type) {
                      ReactionService.toggleReaction(
                        postId: doc.id,
                        postAuthorId: post.authorId,
                        postTitle: post.title,
                        currentUid: authorId,
                        reactionType: type,
                      );
                    },
                    onComment: () => Navigator.of(context).pushNamed(
                      AppRoutes.postDetail,
                      arguments: {
                        'post': post,
                        'heroTag': 'my_profile_post_${post.id}',
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Connections list screen ──

class _ConnectionsListScreen extends StatelessWidget {
  final String userId;
  final bool isFollowersMode;
  final String profileOwnerName;
  const _ConnectionsListScreen({required this.userId, required this.isFollowersMode, required this.profileOwnerName});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final collectionRef = isFollowersMode
        ? FirebaseFirestore.instance.collection('users').doc(userId).collection('followers')
        : FirebaseFirestore.instance.collection('users').doc(userId).collection('following');

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(isFollowersMode ? 'Followers' : 'Following',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.textHi)),
        foregroundColor: c.textHi,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: collectionRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          final connectionDocs = snapshot.data?.docs ?? [];
          if (connectionDocs.isEmpty) {
            return Center(child: Text(isFollowersMode ? 'No followers yet.' : 'Not following anyone yet.', style: TextStyle(color: c.textMuted, fontSize: 13)));
          }
          return ListView.separated(
            itemCount: connectionDocs.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 20, endIndent: 20, color: c.divider),
            itemBuilder: (context, index) {
              final String targetUid = connectionDocs[index].id;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(targetUid).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)));
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
                  final data = userSnapshot.data!.data() as Map<String, dynamic>;
                  final String name     = data['name']     ?? 'User';
                  final String username = data['username'] ?? 'user';
                  final String avatar   = data['avatarUrl'] ?? '';
                  return ListTile(
                    leading: CustomAvatar(name: name, imageUrl: avatar.isNotEmpty ? avatar : null, userId: targetUid, radius: 20),
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: c.textHi)),
                    subtitle: Text(username.startsWith('@') ? username : '@$username', style: TextStyle(fontSize: 12, color: c.textMuted)),
                    trailing: Icon(Icons.chevron_right_rounded, color: c.chipBorder),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileScreen(userId: targetUid, userName: name, userAvatar: avatar))),
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

// ── Staggered list fade-slide entry transition ──

class _StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredFadeSlide({required this.index, required this.child});

  @override
  State<_StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<_StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    final delay = Duration(milliseconds: 50 * widget.index);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

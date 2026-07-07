import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../shared/models/post_model.dart';
import '../widgets/post_card.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../messaging/screens/messages_list_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../profile/screens/my_profile_screen.dart';
import 'spark_viewer_screen.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/feed_algorithm.dart';
import '../../../core/services/reaction_service.dart';

class _RailSpark {
  final String uid;
  final String name;
  final String? avatar;
  final String sparkId;
  final bool isMe;
  bool viewed;

  _RailSpark({
    required this.uid,
    required this.name,
    this.avatar,
    required this.sparkId,
    required this.isMe,
    this.viewed = false,
  });

  bool get hasActiveSpark => sparkId.isNotEmpty;
}

enum _SidebarTab { sparks, search, alerts, chats }

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with SingleTickerProviderStateMixin {
  List<_RailSpark> _railSparks = [];
  List<SparkItem> _sparkItems = [];
  bool _sparksLoading = true;

  _SidebarTab _sidebarTab = _SidebarTab.sparks;

  late final Stream<QuerySnapshot> _postsStream;
  UserFeedProfile _feedProfile = UserFeedProfile.empty('');

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  late AppColorsExtension _c;

  late AnimationController _sidebarController;
  late Animation<Offset> _sidebarSlide;

  @override
  void initState() {
    super.initState();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();

    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _sidebarSlide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _preloadMeSlot();
    _loadSparks();
    _loadProfileInBackground();
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileInBackground() async {
    try {
      final profile = await FeedAlgorithm.buildUserProfile(_myUid)
          .timeout(const Duration(seconds: 6),
              onTimeout: () => UserFeedProfile.empty(_myUid));
      if (mounted) setState(() => _feedProfile = profile);
    } catch (_) {}
  }

  Future<void> _refreshProfile() async {
    await _loadProfileInBackground();
    await _loadSparks();
  }

  void _preloadMeSlot() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _railSparks = [
      _RailSpark(
        uid: user.uid,
        name: user.displayName ?? 'Me',
        avatar: user.photoURL,
        sparkId: '',
        isMe: true,
        viewed: true,
      ),
    ];
    _sparksLoading = false;
  }

  Future<void> _cleanupExpiredSparks() async {
    try {
      final now = DateTime.now();
      final snaps = await FirebaseFirestore.instance
          .collection('stories')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();
      if (snaps.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snaps.docs) batch.delete(doc.reference);
        await batch.commit();
      }
    } catch (_) {}
  }

  Future<void> _loadSparks() async {
    final myUid = _myUid;
    if (myUid.isEmpty) return;
    if (mounted && _railSparks.isEmpty) setState(() => _sparksLoading = true);
    _cleanupExpiredSparks();

    try {
      final now = DateTime.now();
      final List<_RailSpark> rail = [];
      final List<SparkItem> items = [];

      String myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Me';
      String? myAvatar = FirebaseAuth.instance.currentUser?.photoURL;

      try {
        final meDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .get();
        if (meDoc.exists) {
          myName =
              meDoc.data()?['name'] ?? meDoc.data()?['username'] ?? myName;
          myAvatar = meDoc.data()?['avatarUrl'] ??
              meDoc.data()?['photoURL'] ??
              myAvatar;
        }
      } catch (_) {}

      final mySnap = await FirebaseFirestore.instance
          .collection('stories')
          .where('authorId', isEqualTo: myUid)
          .get();

      final myValidDocs = mySnap.docs
          .where((doc) {
            final exp =
                (doc.data()['expiresAt'] as Timestamp?)?.toDate();
            return exp != null && exp.isAfter(now);
          })
          .toList()
        ..sort((a, b) {
          final aT =
              (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bT =
              (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return bT.compareTo(aT);
        });

      final myDoc = myValidDocs.isNotEmpty ? myValidDocs.first : null;

      rail.add(_RailSpark(
        uid: myUid,
        name: myName,
        avatar: myAvatar,
        sparkId: myDoc?.id ?? '',
        isMe: true,
        viewed: true,
      ));
      if (myDoc != null) items.add(SparkItem.fromFirestore(myDoc));

      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('following')
          .get();
      final followingUids = followingSnap.docs.map((d) => d.id).toList();

      if (followingUids.isNotEmpty) {
        for (var i = 0; i < followingUids.length; i += 30) {
          final chunk = followingUids.sublist(
              i,
              (i + 30) > followingUids.length
                  ? followingUids.length
                  : i + 30);

          final snap = await FirebaseFirestore.instance
              .collection('stories')
              .where('authorId', whereIn: chunk)
              .get();

          final validDocs = snap.docs
              .where((doc) {
                final exp =
                    (doc.data()['expiresAt'] as Timestamp?)?.toDate();
                return exp != null && exp.isAfter(now);
              })
              .toList()
            ..sort((a, b) {
              final aT = (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime(0);
              final bT = (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime(0);
              return bT.compareTo(aT);
            });

          final seenAuthors = <String>{};
          for (final doc in validDocs) {
            final data = doc.data();
            final aid = data['authorId'] as String? ?? '';
            if (aid.isEmpty || seenAuthors.contains(aid)) continue;
            seenAuthors.add(aid);
            final viewedBy = List<String>.from(data['viewedBy'] ?? []);
            rail.add(_RailSpark(
              uid: aid,
              name: data['authorName'] ?? data['name'] ?? 'User',
              avatar: data['authorAvatar'] ?? data['avatarUrl'],
              sparkId: doc.id,
              isMe: false,
              viewed: viewedBy.contains(myUid),
            ));
            items.add(SparkItem.fromFirestore(doc));
          }
        }
      }

      if (mounted) {
        setState(() {
          _railSparks = rail;
          _sparkItems = items;
          _sparksLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[HomeFeed] loadSparks error: $e\n$st');
      if (mounted) {
        setState(() => _sparksLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load sparks: $e'),
          backgroundColor: context.appColors.error,
        ));
      }
    }
  }

  void _onSparkTap(_RailSpark rail) {
    if (!rail.hasActiveSpark) {
      Navigator.of(context).pushNamed(AppRoutes.createSpark);
      return;
    }
    final idx = _sparkItems.indexWhere((s) => s.sparkId == rail.sparkId);
    if (idx < 0) { _loadSparks(); return; }
    if (!rail.isMe) {
      setState(() => rail.viewed = true);
      FirebaseFirestore.instance
          .collection('stories')
          .doc(rail.sparkId)
          .update({'viewedBy': FieldValue.arrayUnion([_myUid])});
    }
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => SparkViewerScreen(
        args: SparkViewerArgs(sparks: _sparkItems, initialIndex: idx),
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  Future<void> _handleReaction(
      String postId, String authorId, String title, String type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await ReactionService.toggleReaction(
      postId: postId,
      postAuthorId: authorId,
      postTitle: title,
      currentUid: uid,
      reactionType: type,
    );
  }

  Future<void> _handleSave(String postId, List savedBy) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (savedBy.contains(uid)) {
      await ref.update({'savedBy': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'savedBy': FieldValue.arrayUnion([uid])});
    }
  }

  void _openSidebar([_SidebarTab tab = _SidebarTab.sparks]) {
    setState(() => _sidebarTab = tab);
    if (_sidebarController.isCompleted) return;
    _sidebarController.forward();
  }

  void _closeSidebar() {
    if (_sidebarController.isDismissed) return;
    _sidebarController.reverse();
  }

  void _toggleSidebar() {
    if (_sidebarController.value > 0.5 ||
        _sidebarController.status == AnimationStatus.completed) {
      _closeSidebar();
    } else {
      _openSidebar();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _c = context.appColors;
    return Scaffold(
      backgroundColor: _c.bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildFeed(),
          _buildSidebarOverlay(),
        ],
      ),
    );
  }

  // ── Sidebar overlay ────────────────────────────────────────────────────────
  Widget _buildSidebarOverlay() {
    return AnimatedBuilder(
      animation: _sidebarController,
      builder: (context, child) {
        final t = _sidebarController.value;
        if (t == 0) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSidebar,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
                  child: Container(
                      color: Colors.black.withValues(alpha: 0.28 * t)),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: _sidebarSlide,
                child: _buildGlassPanel(),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Glass panel ────────────────────────────────────────────────────────────
  Widget _buildGlassPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        bottomLeft: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: 310,
          height: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.62),
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.7),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 40,
                offset: const Offset(-8, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sidebarTitle(),
                          style: TextStyle(
                            color: _c.textHi,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      _GlassIconButton(
                        icon: Icons.close_rounded,
                        onTap: _closeSidebar,
                        isDark: isDark,
                        color: _c.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSidebarTabBar(isDark),
                  const SizedBox(height: 16),
                  Expanded(child: _buildSidebarTabBody()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _sidebarTitle() {
    switch (_sidebarTab) {
      case _SidebarTab.sparks:   return 'Sparks';
      case _SidebarTab.search:   return 'Search';
      case _SidebarTab.alerts:   return 'Notifications';
      case _SidebarTab.chats:    return 'Messages';
    }
  }

  // ── Polished tab bar ───────────────────────────────────────────────────────
  Widget _buildSidebarTabBar(bool isDark) {
    return StreamBuilder<int>(
      stream: NotificationService.unreadCountStream(_myUid),
      builder: (context, snap) {
        final unreadCount = snap.data ?? 0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.45),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  _tabPill(
                    tab: _SidebarTab.sparks,
                    icon: Icons.auto_awesome_rounded,
                    label: 'Sparks',
                    isDark: isDark,
                  ),
                  _tabPill(
                    tab: _SidebarTab.search,
                    icon: Icons.search_rounded,
                    label: 'Search',
                    isDark: isDark,
                  ),
                  _tabPill(
                    tab: _SidebarTab.alerts,
                    icon: Icons.notifications_none_rounded,
                    label: 'Alerts',
                    isDark: isDark,
                    badge: unreadCount > 0,
                  ),
                  _tabPill(
                    tab: _SidebarTab.chats,
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chats',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tabPill({
    required _SidebarTab tab,
    required IconData icon,
    required String label,
    required bool isDark,
    bool badge = false,
  }) {
    final selected = _sidebarTab == tab;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _sidebarTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? _c.primary.withValues(alpha: 0.90)
                    : _c.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _c.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.55)
                            : _c.textPrimary.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.55)
                              : _c.textPrimary.withValues(alpha: 0.65)),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              if (badge)
                Positioned(
                  top: -3,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _c.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.4)
                            : Colors.white,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _c.error.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab body ───────────────────────────────────────────────────────────────
  Widget _buildSidebarTabBody() {
    switch (_sidebarTab) {
      case _SidebarTab.sparks:
        return _buildSparksTab();
      case _SidebarTab.search:
        return const SearchScreen();
      case _SidebarTab.alerts:
        return const NotificationsScreen();
      case _SidebarTab.chats:
        return const MessagesListScreen();
    }
  }

  Widget _buildSparksTab() {
    return _sparksLoading
        ? Center(
            child: CircularProgressIndicator(
                color: _c.primary, strokeWidth: 2))
        : ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _railSparks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) =>
                _buildSidebarSparkRow(_railSparks[index]),
          );
  }

  Widget _buildSidebarSparkRow(_RailSpark spark) {
    final hasUnread = !spark.viewed && !spark.isMe;
    final isAddSpark = spark.isMe && !spark.hasActiveSpark;
    final isViewMySpark = spark.isMe && spark.hasActiveSpark;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _closeSidebar();
          _onSparkTap(spark);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
              decoration: BoxDecoration(
                color: (hasUnread || isViewMySpark)
                    ? _c.primary.withValues(alpha: isDark ? 0.18 : 0.07)
                    : Colors.white.withValues(alpha: isDark ? 0.06 : 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (hasUnread || isViewMySpark)
                      ? _c.primary.withValues(alpha: 0.30)
                      : Colors.white
                          .withValues(alpha: isDark ? 0.10 : 0.50),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (hasUnread || isViewMySpark)
                            ? _c.primary
                            : Colors.white.withValues(alpha: 0.35),
                        width: (hasUnread || isViewMySpark) ? 2 : 0.8,
                      ),
                      boxShadow: (hasUnread || isViewMySpark)
                          ? [
                              BoxShadow(
                                color: _c.primary.withValues(alpha: 0.30),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: CustomAvatar(
                        name: spark.name,
                        imageUrl: spark.avatar,
                        userId: spark.uid,
                        radius: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAddSpark
                              ? 'Your spark'
                              : isViewMySpark
                                  ? 'My spark'
                                  : spark.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _c.textHi,
                            fontSize: 13,
                            fontWeight: (hasUnread ||
                                    isAddSpark ||
                                    isViewMySpark)
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAddSpark
                              ? 'Tap to add'
                              : hasUnread
                                  ? 'New spark'
                                  : 'Viewed',
                          style: TextStyle(
                            color: hasUnread
                                ? _c.primary.withValues(alpha: 0.8)
                                : _c.textMuted,
                            fontSize: 10.5,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAddSpark)
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _c.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _c.primary.withValues(alpha: 0.30),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(Icons.add_rounded,
                          color: _c.primary, size: 16),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Feed ───────────────────────────────────────────────────────────────────
  Widget _buildFeed() {
    final currentUid = _myUid;
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildError(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: _c.primary, strokeWidth: 2));
        }

        final docs = snapshot.data?.docs ?? [];
        final rawPosts =
            docs.map((d) => Post.fromFirestore(d, currentUid)).toList();
        final ranked = FeedAlgorithm.rankPosts(rawPosts, _feedProfile);
        final discoveryIdx =
            FeedAlgorithm.discoveryStartIndex(ranked, _feedProfile);
        final hasDiscovery = discoveryIdx < ranked.length;

        if (ranked.isEmpty) {
          return RefreshIndicator(
            color: _c.primary,
            backgroundColor: _c.surface,
            onRefresh: _refreshProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dynamic_feed_rounded,
                          size: 48, color: _c.textDim),
                      const SizedBox(height: 16),
                      Text('No posts yet',
                          style: TextStyle(
                              color: _c.textHi,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                      const SizedBox(height: 6),
                      Text('Pull down to refresh.',
                          style:
                              TextStyle(color: _c.textDim, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final extraItems = hasDiscovery ? 1 : 0;
        return RefreshIndicator(
          color: _c.primary,
          backgroundColor: _c.surface,
          onRefresh: _refreshProfile,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
            itemCount: ranked.length + extraItems,
            itemBuilder: (context, index) {
              if (hasDiscovery && index == discoveryIdx) {
                return _buildDiscoveryDivider();
              }
              final adjustedIndex =
                  (hasDiscovery && index > discoveryIdx)
                      ? index - 1
                      : index;
              if (adjustedIndex >= ranked.length) {
                return const SizedBox.shrink();
              }
              final post = ranked[adjustedIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PostCard(
                  post: post,
                  onTap: () {
                    FeedAlgorithm.markPostSeen(_myUid, post.id);
                    if (post.type == PostType.video) {
                      final videoPosts = ranked
                          .where((p) => p.type == PostType.video)
                          .toList();
                      final initialIdx = videoPosts.indexOf(post);
                      Navigator.of(context).pushNamed(
                        AppRoutes.echoViewer,
                        arguments: {
                          'posts': videoPosts,
                          'initialIndex':
                              initialIdx >= 0 ? initialIdx : 0,
                        },
                      );
                    } else {
                      Navigator.of(context).pushNamed(
                          AppRoutes.postDetail,
                          arguments: post);
                    }
                  },
                  onReact: (type) => _handleReaction(
                      post.id, post.authorId, post.title, type),
                  onSave: () =>
                      _handleSave(post.id, post.isSaved ? [_myUid] : []),
                  onComment: () {
                    FeedAlgorithm.markPostSeen(_myUid, post.id);
                    Navigator.of(context).pushNamed(
                        AppRoutes.postDetail,
                        arguments: post);
                  },
                  onShare: () {
                    Clipboard.setData(ClipboardData(
                        text:
                            'Check out this post on INTERA by ${post.authorUsername}:\n\n${post.title}\n${post.body}'));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Post copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDiscoveryDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: _c.border, thickness: 0.8)),
          const SizedBox(width: 12),
          Text(
            'Suggested for You',
            style: TextStyle(
              color: _c.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: _c.border, thickness: 0.8)),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  // Option B: hamburger icon on the left opens the sidebar, INTERA centered
  // as static branding, profile avatar stays on the right.
  AppBar _buildAppBar() {
    final user = FirebaseAuth.instance.currentUser;
    return AppBar(
      backgroundColor: _c.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      centerTitle: true,
      leadingWidth: 56,
      leading: StreamBuilder<int>(
        stream: NotificationService.unreadCountStream(_myUid),
        builder: (context, snap) {
          final unreadCount = snap.data ?? 0;
          return GestureDetector(
            onTap: _toggleSidebar,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _c.surface,
                    ),
                    child: Icon(Icons.menu_rounded,
                        color: _c.textPrimary, size: 20),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _c.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: _c.bg, width: 1.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      title: Text(
        AppStrings.homeFeed,
        style: TextStyle(
            color: _c.primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyProfileScreen())),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _c.border.withValues(alpha: 0.6), width: 0.8),
              ),
              child: ClipOval(
                child: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                    ? Image.network(user.photoURL!, fit: BoxFit.cover)
                    : Container(
                        color: _c.surface,
                        child: Icon(Icons.person_rounded,
                            color: _c.textPrimary, size: 18),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: _c.textDim, size: 36),
        const SizedBox(height: 10),
        Text('Could not load feed',
            style:
                TextStyle(color: _c.textHi, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(msg,
            style: TextStyle(color: _c.textDim, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Reusable glass icon button ─────────────────────────────────────────────────
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color color;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.5),
                width: 0.8,
              ),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}
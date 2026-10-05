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
import '../../../shared/widgets/shimmer.dart';
import '../widgets/post_card.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../messaging/screens/messages_list_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../profile/screens/my_profile_screen.dart';
import '../../../shared/widgets/share_post_sheet.dart';
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
  final int sparksCount;

  _RailSpark({
    required this.uid,
    required this.name,
    this.avatar,
    required this.sparkId,
    required this.isMe,
    this.viewed = false,
    this.sparksCount = 0,
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
  List<SparkUserGroup> _sparkGroups = [];
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
      final List<SparkUserGroup> groups = [];

      String myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Me';
      String? myAvatar = FirebaseAuth.instance.currentUser?.photoURL;

      try {
        final meDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .get();
        if (meDoc.exists) {
          myName = meDoc.data()?['name'] ?? meDoc.data()?['username'] ?? myName;
          myAvatar = meDoc.data()?['avatarUrl'] ?? meDoc.data()?['photoURL'] ?? myAvatar;
        }
      } catch (_) {}

      // 1. Get MY active sparks
      final mySnap = await FirebaseFirestore.instance
          .collection('stories')
          .where('authorId', isEqualTo: myUid)
          .get();

      final myValidDocs = mySnap.docs
          .where((doc) {
            final exp = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
            return exp != null && exp.isAfter(now);
          })
          .toList()
        ..sort((a, b) {
          final aT = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bT = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return aT.compareTo(bT);
        });

      final List<SparkItem> mySparks = myValidDocs.map((doc) => SparkItem.fromFirestore(doc)).toList();

      rail.add(_RailSpark(
        uid: myUid,
        name: myName,
        avatar: myAvatar,
        sparkId: mySparks.isNotEmpty ? mySparks.first.sparkId : '',
        isMe: true,
        viewed: true,
        sparksCount: mySparks.length,
      ));

      if (mySparks.isNotEmpty) {
        groups.add(SparkUserGroup(
          authorId: myUid,
          authorName: myName,
          authorAvatar: myAvatar,
          sparks: mySparks,
        ));
      }

      // 2. Get FOLLOWING active sparks
      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('following')
          .get();
      final followingUids = followingSnap.docs.map((d) => d.id).toList();

      if (followingUids.isNotEmpty) {
        final List<DocumentSnapshot> allFollowingDocs = [];
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
          allFollowingDocs.addAll(snap.docs);
        }

        final validFollowingDocs = allFollowingDocs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final exp = (data['expiresAt'] as Timestamp?)?.toDate();
              return exp != null && exp.isAfter(now);
            })
            .toList();

        final Map<String, List<SparkItem>> groupedSparks = {};
        for (final doc in validFollowingDocs) {
          final item = SparkItem.fromFirestore(doc);
          groupedSparks.putIfAbsent(item.authorId, () => []).add(item);
        }

        for (final authorId in groupedSparks.keys) {
          groupedSparks[authorId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }

        for (final authorId in groupedSparks.keys) {
          final userSparks = groupedSparks[authorId]!;
          if (userSparks.isEmpty) continue;

          final firstSpark = userSparks.first;

          bool allViewed = true;
          for (final spark in userSparks) {
            final snapDoc = validFollowingDocs.firstWhere((d) => d.id == spark.sparkId);
            final viewedBy = List<String>.from((snapDoc.data() as Map<String, dynamic>?)?['viewedBy'] ?? []);
            if (!viewedBy.contains(myUid)) {
              allViewed = false;
              break;
            }
          }

          rail.add(_RailSpark(
            uid: authorId,
            name: firstSpark.authorName,
            avatar: firstSpark.authorAvatar,
            sparkId: firstSpark.sparkId,
            isMe: false,
            viewed: allViewed,
            sparksCount: userSparks.length,
          ));

          groups.add(SparkUserGroup(
            authorId: authorId,
            authorName: firstSpark.authorName,
            authorAvatar: firstSpark.authorAvatar,
            sparks: userSparks,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _railSparks = rail;
          _sparkGroups = groups;
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
    final idx = _sparkGroups.indexWhere((g) => g.authorId == rail.uid);
    if (idx < 0) { _loadSparks(); return; }
    if (!rail.isMe) {
      setState(() => rail.viewed = true);
      final group = _sparkGroups[idx];
      for (final spark in group.sparks) {
        FirebaseFirestore.instance
            .collection('stories')
            .doc(spark.sparkId)
            .update({'viewedBy': FieldValue.arrayUnion([_myUid])});
      }
    }
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => SparkViewerScreen(
        args: SparkViewerArgs(groups: _sparkGroups, initialUserIndex: idx),
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

  Future<void> _openEchoViewer() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'video')
          .orderBy('createdAt', descending: true)
          .limit(40)
          .get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Echos (videos) found yet!')),
        );
        return;
      }

      final posts = snap.docs.map((doc) => Post.fromFirestore(doc, _myUid)).toList();
      
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        AppRoutes.echoViewer,
        arguments: {
          'posts': posts,
          'initialIndex': 0,
        },
      );
    } catch (e) {
      debugPrint('Error loading echos: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading echos: $e')),
      );
    }
  }

  //  Build 
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

  //  Sidebar overlay 
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

  //  Glass panel 
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
                        icon: Icons.play_circle_fill_rounded,
                        onTap: () {
                          _closeSidebar();
                          _openEchoViewer();
                        },
                        isDark: isDark,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
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

  //  Polished tab bar 
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

  Widget _buildSparksTab() {
    if (_sparksLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: _c.primary, strokeWidth: 2),
      );
    }
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 20,
        childAspectRatio: 0.82,
      ),
      itemCount: _railSparks.length,
      itemBuilder: (context, index) => _buildSidebarSparkRow(_railSparks[index]),
    );
  }

  Widget _buildSidebarSparkRow(_RailSpark spark) {
    final hasUnread = !spark.viewed && !spark.isMe;
    final isViewMySpark = spark.isMe && spark.hasActiveSpark;

    final avatarChild = CustomAvatar(
      name: spark.name,
      imageUrl: spark.avatar,
      userId: spark.uid,
      radius: 28,
      clickable: false,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            _closeSidebar();
            _onSparkTap(spark);
          },
          child: _buildStackedRings(avatarChild, hasUnread, spark.isMe, spark.sparksCount),
        ),
        const SizedBox(height: 8),
        Text(
          spark.isMe ? 'My Spark' : spark.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _c.textHi,
            fontSize: 11,
            fontWeight: (hasUnread || isViewMySpark) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStackedRings(Widget avatarChild, bool hasUnread, bool isMe, int sparksCount) {
    final showStack = sparksCount > 1;
    final ringColor = hasUnread ? _c.primary : Colors.grey.shade400;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (showStack) ...[
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor.withValues(alpha: 0.4), width: 1.5),
              ),
            ),
          ),
          Positioned(
            right: -1.5,
            bottom: -1.5,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor.withValues(alpha: 0.7), width: 1.5),
              ),
            ),
          ),
        ],
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasUnread
                ? LinearGradient(
                    colors: [_c.primary, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: hasUnread ? null : Colors.grey.withValues(alpha: 0.3),
            border: hasUnread ? null : Border.all(color: Colors.grey.shade400, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: ClipOval(child: avatarChild),
              ),
            ),
          ),
        ),
        if (isMe)
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: () {
                _closeSidebar();
                Navigator.of(context).pushNamed(AppRoutes.createSpark);
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _c.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Icon(Icons.add_rounded, size: 10, color: Colors.white),
              ),
            ),
          ),
      ],
    );
    }

  //  Tab body 
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

  //  Feed 
  Widget _buildFeed() {
    final currentUid = _myUid;
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildError(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, __) => const PostCardShimmer(),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final rawPosts = docs
            .map((d) {
              final post = Post.fromFirestore(d, currentUid);
              final data = d.data() as Map<String, dynamic>? ?? {};
              final visibility = data['visibility'] ?? 'Public';
              final scheduledAt = data['scheduledAt'] as Timestamp?;
              return _FeedFilterWrapper(post: post, visibility: visibility, scheduledAt: scheduledAt);
            })
            .where((w) {
              if (w.post.type == PostType.helpRequest) return false;
              if (w.post.communityId != null && w.post.communityId!.isNotEmpty) return false;
              if (w.scheduledAt != null && w.scheduledAt!.toDate().isAfter(DateTime.now())) {
                if (w.post.authorId != currentUid) return false;
              }
              if (w.visibility == 'Only Me' && w.post.authorId != currentUid) return false;
              if (w.visibility == 'Followers' && 
                  w.post.authorId != currentUid && 
                  !_feedProfile.followingIds.contains(w.post.authorId)) {
                return false;
              }
              return true;
            })
            .map((w) => w.post)
            .toList();
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
                  heroTag: 'home_post_${post.id}',
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
                          arguments: {
                            'post': post,
                            'heroTag': 'home_post_${post.id}',
                          });
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
                        arguments: {
                          'post': post,
                          'heroTag': 'home_post_${post.id}',
                        });
                  },
                  onShare: () => SharePostSheet.show(context, post, _myUid),
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

  //  AppBar 
  
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

// Reusable glass icon button 
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

// Feed filter wrapper 

class _FeedFilterWrapper {
  final Post post;
  final String visibility;
  final Timestamp? scheduledAt;
  const _FeedFilterWrapper({
    required this.post,
    required this.visibility,
    required this.scheduledAt,
  });
}

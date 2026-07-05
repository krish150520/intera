import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../widgets/post_card.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../messaging/screens/messages_list_screen.dart';
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

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  List<_RailSpark> _railSparks = [];
  List<SparkItem>  _sparkItems  = [];
  bool _sparksLoading = true;

  // ── Real-time stream (always works) ─────────────────────────────────────
  late final Stream<QuerySnapshot> _postsStream;

  // ── Algorithm profile (loads in background, non-blocking) ─────────────────
  UserFeedProfile _feedProfile = UserFeedProfile.empty('');

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Theme-aware color getters ─────────────────────────────────────────────
  late AppColorsExtension _c;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Stream gives immediate real-time results — ranking is applied on top
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _preloadMeSlot();
    _loadSparks();
    // Load profile in background — does NOT block the feed from showing
    _loadProfileInBackground();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Loads the user profile silently in the background.
  /// When ready, re-renders the feed with better ranking.
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

  // ── Cleanup expired sparks (older than 24 hours) ──────────────────────────
  Future<void> _cleanupExpiredSparks() async {
    try {
      final now = DateTime.now();
      final snaps = await FirebaseFirestore.instance
          .collection('stories')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      if (snaps.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snaps.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('[HomeFeed] Permanently deleted ${snaps.docs.length} expired sparks.');
      }
    } catch (e) {
      debugPrint('[HomeFeed] Expired sparks cleanup failed: $e');
    }
  }

  // ── Spark loading — no orderBy, so no composite index needed ──────────────
  Future<void> _loadSparks() async {
    final myUid = _myUid;
    if (myUid.isEmpty) return;

    if (mounted && _railSparks.isEmpty) setState(() => _sparksLoading = true);

    // Run cleanup in the background
    _cleanupExpiredSparks();

    try {
      final now = DateTime.now();
      final List<_RailSpark> rail  = [];
      final List<SparkItem>  items = [];

      String myName    = FirebaseAuth.instance.currentUser?.displayName ?? 'Me';
      String? myAvatar = FirebaseAuth.instance.currentUser?.photoURL;

      try {
        final meDoc = await FirebaseFirestore.instance
            .collection('users').doc(myUid).get();
        if (meDoc.exists) {
          myName   = meDoc.data()?['name'] ?? meDoc.data()?['username'] ?? myName;
          myAvatar = meDoc.data()?['avatarUrl'] ?? meDoc.data()?['photoURL'] ?? myAvatar;
        }
      } catch (_) {}

      // ── My own spark ──────────────────────────────────────────────────────
      final mySnap = await FirebaseFirestore.instance
          .collection('stories')
          .where('authorId', isEqualTo: myUid)
          .get();

      final myValidDocs = mySnap.docs.where((doc) {
        final exp = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
        return exp != null && exp.isAfter(now);
      }).toList()
        ..sort((a, b) {
          final aT = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bT = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return bT.compareTo(aT);
        });

      final myDoc = myValidDocs.isNotEmpty ? myValidDocs.first : null;

      rail.add(_RailSpark(
        uid:     myUid,
        name:    myName,
        avatar:  myAvatar,
        sparkId: myDoc?.id ?? '',
        isMe:    true,
        viewed:  true,
      ));
      if (myDoc != null) items.add(SparkItem.fromFirestore(myDoc));

      // ── Following sparks ────────────────────────────────────────────────
      final followingSnap = await FirebaseFirestore.instance
          .collection('users').doc(myUid).collection('following').get();
      final followingUids = followingSnap.docs.map((d) => d.id).toList();

      if (followingUids.isNotEmpty) {
        for (var i = 0; i < followingUids.length; i += 30) {
          final chunk = followingUids.sublist(
            i, (i + 30) > followingUids.length ? followingUids.length : i + 30);

          final snap = await FirebaseFirestore.instance
              .collection('stories')
              .where('authorId', whereIn: chunk)
              .get();

          final validDocs = snap.docs.where((doc) {
            final exp = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
            return exp != null && exp.isAfter(now);
          }).toList()
            ..sort((a, b) {
              final aT = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
              final bT = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
              return bT.compareTo(aT);
            });

          final seenAuthors = <String>{};
          for (final doc in validDocs) {
            final data = doc.data();
            final aid  = data['authorId'] as String? ?? '';
            if (aid.isEmpty || seenAuthors.contains(aid)) continue;
            seenAuthors.add(aid);

            final viewedBy = List<String>.from(data['viewedBy'] ?? []);
            rail.add(_RailSpark(
              uid:     aid,
              name:    data['authorName'] ?? data['name'] ?? 'User',
              avatar:  data['authorAvatar'] ?? data['avatarUrl'],
              sparkId: doc.id,
              isMe:    false,
              viewed:  viewedBy.contains(myUid),
            ));
            items.add(SparkItem.fromFirestore(doc));
          }
        }
      }

      if (mounted) {
        setState(() {
          _railSparks    = rail;
          _sparkItems     = items;
          _sparksLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[HomeFeed] loadSparks error: $e\n$st');
      if (mounted) {
        setState(() => _sparksLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load sparks: $e'),
            backgroundColor: context.appColors.error,
          ),
        );
      }
    }
  }

  // ── Spark tap ─────────────────────────────────────────────────────────────
  void _onSparkTap(_RailSpark rail) {
    if (!rail.hasActiveSpark) {
      Navigator.of(context).pushNamed(AppRoutes.createSpark);
      return;
    }

    final idx = _sparkItems.indexWhere((s) => s.sparkId == rail.sparkId);
    if (idx < 0) {
      _loadSparks();
      return;
    }

    if (!rail.isMe) {
      setState(() {
        rail.viewed = true;
      });
      FirebaseFirestore.instance
          .collection('stories')
          .doc(rail.sparkId)
          .update({
        'viewedBy': FieldValue.arrayUnion([_myUid])
      });
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


  Future<void> _handleReaction(String postId, String authorId, String title, String type) async {
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _c = context.appColors;

    return Scaffold(
      backgroundColor: _c.bg,
      appBar: _buildAppBar(),
      body: _buildFeed(),
    );
  }

  // ── Feed (stream + ranked) ────────────────────────────────────────────────
  Widget _buildFeed() {
    final currentUid = _myUid;
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: _c.primary, strokeWidth: 2));
        }

        final docs = snapshot.data?.docs ?? [];

        // Convert raw Firestore docs to Post objects
        final rawPosts =
            docs.map((d) => Post.fromFirestore(d, currentUid)).toList();

        // Apply ranking (uses whatever profile we have — starts empty,
        // gets better once _loadProfileInBackground completes)
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
                _buildSparkTray(),
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
                          style: TextStyle(
                              color: _c.textDim, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // +1 spark tray, optional divider, items
        final extraItems = 1 + (hasDiscovery ? 1 : 0);
        final itemCount  = ranked.length + extraItems;

        return RefreshIndicator(
          color: _c.primary,
          backgroundColor: _c.surface,
          onRefresh: _refreshProfile,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == 0) return _buildSparkTray();

              final postIndex = index - 1;

              if (hasDiscovery && postIndex == discoveryIdx) {
                return _buildDiscoveryDivider();
              }

              final adjustedIndex =
                  (hasDiscovery && postIndex > discoveryIdx)
                      ? postIndex - 1
                      : postIndex;

              if (adjustedIndex >= ranked.length) {
                return const SizedBox.shrink();
              }

              final post = ranked[adjustedIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: post,
                  onTap: () {
                    FeedAlgorithm.markPostSeen(_myUid, post.id);
                    Navigator.of(context)
                        .pushNamed(AppRoutes.postDetail, arguments: post);
                  },
                  onReact: (type) => _handleReaction(
                      post.id,
                      post.authorId,
                      post.title,
                      type),
                  onSave: () =>
                      _handleSave(post.id, post.isSaved ? [_myUid] : []),
                  onComment: () {
                    FeedAlgorithm.markPostSeen(_myUid, post.id);
                    Navigator.of(context)
                        .pushNamed(AppRoutes.postDetail, arguments: post);
                  },
                  onShare: () {
                    Clipboard.setData(ClipboardData(
                        text:
                            'Check out this post on INTERA by ${post.authorUsername}:\n\n${post.title}\n${post.body}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Post copied to clipboard!'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
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
      padding: const EdgeInsets.symmetric(vertical: 24),
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

  Widget _buildSparkTray() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 94,
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.border, width: 0.8),
      ),
      child: _sparksLoading
          ? ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => _buildShimmerAvatar(),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: _railSparks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildSparkAvatar(_railSparks[index]);
              },
            ),
    );
  }

  Widget _buildShimmerAvatar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _c.field,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 8,
          decoration: BoxDecoration(
            color: _c.field,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildSparkAvatar(_RailSpark spark) {
    final hasUnread     = !spark.viewed && !spark.isMe;
    final isAddSpark    = spark.isMe && !spark.hasActiveSpark;
    final isViewMySpark = spark.isMe && spark.hasActiveSpark;

    return GestureDetector(
      onTap: () => _onSparkTap(spark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(
                    color: (hasUnread || isViewMySpark)
                        ? _c.primary
                        : isAddSpark
                            ? _c.border
                            : _c.border,
                    width: (hasUnread || isViewMySpark) ? 2 : 0.8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: _c.field,
                    backgroundImage:
                        (spark.avatar != null && spark.avatar!.isNotEmpty)
                            ? NetworkImage(spark.avatar!)
                            : null,
                    child: (spark.avatar == null || spark.avatar!.isEmpty)
                        ? Text(
                            spark.name.isNotEmpty
                                ? spark.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: _c.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          )
                        : null,
                  ),
                ),
              ),
              if (isAddSpark)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                        color: _c.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.surface, width: 1.5)),
                    child: const Icon(Icons.add, size: 10, color: Colors.white),
                  ),
                ),
              if (isViewMySpark)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.surface, width: 1.5)),
                    child: Icon(Icons.play_arrow_rounded,
                        size: 10, color: _c.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              isAddSpark
                  ? 'Your spark'
                  : isViewMySpark
                      ? 'My spark'
                      : spark.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (hasUnread || isAddSpark || isViewMySpark)
                    ? _c.textPrimary
                    : _c.textMuted,
                fontSize: 10,
                fontWeight: (hasUnread || isAddSpark || isViewMySpark)
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _c.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      centerTitle: false,
      title: Text(
        AppStrings.homeFeed,
        style: TextStyle(
            color: _c.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5),
      ),
      actions: [
        StreamBuilder<int>(
          stream: NotificationService.unreadCountStream(_myUid),
          builder: (context, snap) {
            final unreadCount = snap.data ?? 0;
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _appBarBtn(
                  icon: Icons.notifications_none_rounded,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 10,
                    right: 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _c.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
        _appBarBtn(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MessagesListScreen())),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _appBarBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: _c.border, width: 0.8),
        ),
        child: Icon(icon, color: _c.textPrimary, size: 18),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildError(String msg) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: _c.textDim, size: 36),
        const SizedBox(height: 10),
        Text('Could not load feed',
            style: TextStyle(color: _c.textHi, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(msg,
            style: TextStyle(color: _c.textDim, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

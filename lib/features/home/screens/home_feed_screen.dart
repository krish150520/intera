import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/models/post_model.dart';
import '../widgets/post_card.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../messaging/screens/messages_list_screen.dart';
import 'story_viewver_screen.dart';

class _RailStory {
  final String uid;
  final String name;
  final String? avatar;
  final String storyId;
  final bool isMe;
  bool viewed;

  _RailStory({
    required this.uid,
    required this.name,
    this.avatar,
    required this.storyId,
    required this.isMe,
    this.viewed = false,
  });

  bool get hasActiveStory => storyId.isNotEmpty;
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with SingleTickerProviderStateMixin {
  static const double _panelWidth = 64.0;
  static const double _tabWidth   = 10.0;

  bool _drawerOpen = false;
  AnimationController? _anim;

  List<_RailStory> _railStories = [];
  List<StoryItem>  _storyItems  = [];
  bool _storiesLoading = true;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Theme-aware color getters ────────────────────────────────────────────
  // Pulled from context in build(); cached here per-build via _colors.
  late _ThemeColors _c;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..value = 0.0;
    _preloadMeSlot();
    _loadStories();
  }

  void _preloadMeSlot() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _railStories = [
      _RailStory(
        uid: user.uid,
        name: user.displayName ?? 'Me',
        avatar: user.photoURL,
        storyId: '',
        isMe: true,
        viewed: true,
      ),
    ];
    _storiesLoading = false;
  }

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  // ── Drawer helpers ────────────────────────────────────────────────────────
  void _openDrawer()  { setState(() => _drawerOpen = true); _anim?.forward(); }
  void _closeDrawer() { _anim?.reverse().then((_) { if (mounted) setState(() => _drawerOpen = false); }); }
  void _toggleDrawer() => _drawerOpen ? _closeDrawer() : _openDrawer();

  // ── Story loading — no orderBy, so no composite index needed ──────────────
  Future<void> _loadStories() async {
    final myUid = _myUid;
    if (myUid.isEmpty) return;

    if (mounted && _railStories.isEmpty) setState(() => _storiesLoading = true);

    try {
      final now = DateTime.now();
      final List<_RailStory> rail  = [];
      final List<StoryItem>  items = [];

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

      // ── My own story ──────────────────────────────────────────────────────
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

      rail.add(_RailStory(
        uid:     myUid,
        name:    myName,
        avatar:  myAvatar,
        storyId: myDoc?.id ?? '',
        isMe:    true,
        viewed:  true,
      ));
      if (myDoc != null) items.add(StoryItem.fromFirestore(myDoc));

      // ── Following stories ────────────────────────────────────────────────
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
            rail.add(_RailStory(
              uid:     aid,
              name:    data['authorName'] ?? data['name'] ?? 'User',
              avatar:  data['authorAvatar'] ?? data['avatarUrl'],
              storyId: doc.id,
              isMe:    false,
              viewed:  viewedBy.contains(myUid),
            ));
            items.add(StoryItem.fromFirestore(doc));
          }
        }
      }

      if (mounted) {
        setState(() {
          _railStories    = rail;
          _storyItems     = items;
          _storiesLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[HomeFeed] loadStories error: $e\n$st');
      if (mounted) {
        setState(() => _storiesLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load stories: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Story tap ─────────────────────────────────────────────────────────────
  void _onStoryTap(_RailStory rail) {
    _closeDrawer();

    if (!rail.hasActiveStory) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.of(context).pushNamed(AppRoutes.createStory);
      });
      return;
    }

    final idx = _storyItems.indexWhere((s) => s.storyId == rail.storyId);
    if (idx < 0) {
      _loadStories();
      return;
    }

    if (!rail.isMe) setState(() => rail.viewed = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => StoryViewerScreen(
          args: StoryViewerArgs(stories: _storyItems, initialIndex: idx),
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    });
  }

  // ── Like / save ───────────────────────────────────────────────────────────
  Future<void> _handleLike(String postId, List likedBy) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (likedBy.contains(uid)) {
      await ref.update({'likeCount': FieldValue.increment(-1), 'likedBy': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likeCount': FieldValue.increment(1),  'likedBy': FieldValue.arrayUnion([uid])});
    }
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
    _c = _ThemeColors(context);
    final unread = _railStories.where((s) => !s.viewed && !s.isMe).length;

    return Scaffold(
      backgroundColor: _c.bg,
      appBar: _buildAppBar(),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(right: _tabWidth),
              child: _buildFeed(),
            ),
          ),

          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDrawer,
                child: AnimatedBuilder(
                  animation: _anim ?? const AlwaysStoppedAnimation(0.0),
                  builder: (_, __) => ColoredBox(
                    color: Colors.black
                        .withOpacity(0.18 * (_anim?.value ?? 0.0)),
                  ),
                ),
              ),
            ),

          AnimatedBuilder(
            animation: _anim ?? const AlwaysStoppedAnimation(0.0),
            builder: (context, _) {
              final slide = CurvedAnimation(
                parent: _anim ?? const AlwaysStoppedAnimation(0.0),
                curve: Curves.easeOutCubic,
              ).value;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0, bottom: 0,
                    right: -_panelWidth + (slide * _panelWidth),
                    width: _panelWidth,
                    child: _buildDrawerPanel(),
                  ),
                  Positioned(
                    top: 0, bottom: 0,
                    right: slide * _panelWidth,
                    width: _tabWidth,
                    child: GestureDetector(
                      onTap: _toggleDrawer,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _c.primary,
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(6)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _tabLine(),
                            const SizedBox(height: 4),
                            if (unread > 0 && !_drawerOpen)
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    unread > 9 ? '9+' : '$unread',
                                    style: TextStyle(
                                        color: _c.primary,
                                        fontSize: 5,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            _tabLine(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tabLine() => Container(
        width: 3, height: 16,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  // ── Feed ──────────────────────────────────────────────────────────────────
  Widget _buildFeed() {
    final currentUid = _myUid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildError(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: _c.primary, strokeWidth: 2));
        }
        final docs = snapshot.data?.docs ?? [];
        return RefreshIndicator(
          color: _c.primary,
          backgroundColor: _c.surface,
          onRefresh: () async {
            await _loadStories();
            await Future.delayed(const Duration(milliseconds: 200));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc    = docs[index];
              final data   = doc.data() as Map<String, dynamic>? ?? {};
              final List likedBy = data['likedBy'] ?? [];
              final List savedBy = data['savedBy'] ?? [];
              final post = Post.fromFirestore(doc, currentUid);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: post,
                  onTap:     () => Navigator.of(context)
                      .pushNamed(AppRoutes.postDetail, arguments: post),
                  onLike:    () => _handleLike(doc.id, likedBy),
                  onSave:    () => _handleSave(doc.id, savedBy),
                  onComment: () => Navigator.of(context)
                      .pushNamed(AppRoutes.postDetail, arguments: post),
                  onShare:   () {},
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _c.bg,
      elevation: 0,
      titleSpacing: 20,
      centerTitle: false,
      title: Text(
        AppStrings.homeFeed,
        style: TextStyle(
            color: _c.textHi,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5),
      ),
      actions: [
        _appBarBtn(
          icon: Icons.send_outlined,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MessagesListScreen())),
        ),
        const SizedBox(width: 8),
        _appBarBtn(
          icon: Icons.notifications_outlined,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _appBarBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: _c.primaryTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _c.primary.withOpacity(0.15),
        child: SizedBox(
          width: 36, height: 36,
          child: Icon(icon, color: _c.primary, size: 20),
        ),
      ),
    );
  }

  // ── Story drawer panel ────────────────────────────────────────────────────
  Widget _buildDrawerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _c.panelBg,
        border: Border(left: BorderSide(color: _c.panelBorder, width: 1)),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: _c.primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                'MOMENTS',
                style: TextStyle(
                    color: _c.textDim.withOpacity(0.6),
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _storiesLoading
                  ? Center(
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: _c.primary, strokeWidth: 2),
                      ),
                    )
                  : _railStories.isEmpty
                      ? Center(
                          child: Icon(Icons.auto_stories_outlined,
                              color: _c.textDim.withOpacity(0.4), size: 20))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          itemCount: _railStories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _buildAvatar(_railStories[i]),
                        ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ── Story avatar tile ─────────────────────────────────────────────────────
  Widget _buildAvatar(_RailStory story) {
    final hasUnread     = !story.viewed && !story.isMe;
    final isAddStory    = story.isMe && !story.hasActiveStory;
    final isViewMyStory = story.isMe && story.hasActiveStory;

    return GestureDetector(
      onTap: () => _onStoryTap(story),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (hasUnread || isViewMyStory)
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isViewMyStory ? AppColors.storyRingGradient : null,
                    color: hasUnread && !isViewMyStory ? _c.primary : null,
                  ),
                ),
              if (isAddStory)
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _c.primary,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                ),
              if (!hasUnread && !isAddStory && !isViewMyStory)
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _c.panelBorder, width: 1.5,
                        strokeAlign: BorderSide.strokeAlignOutside),
                  ),
                ),
              CircleAvatar(
                radius: 19,
                backgroundColor: _c.primaryTint,
                backgroundImage:
                    (story.avatar != null && story.avatar!.isNotEmpty)
                        ? NetworkImage(story.avatar!)
                        : null,
                child: (story.avatar == null || story.avatar!.isEmpty)
                    ? Text(
                        story.name.isNotEmpty
                            ? story.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: _c.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      )
                    : null,
              ),
              if (isAddStory)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                        color: _c.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.panelBg, width: 1.5)),
                    child: const Icon(Icons.add, size: 10, color: Colors.white),
                  ),
                ),
              if (isViewMyStory)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.panelBg, width: 1.5)),
                    child: Icon(Icons.play_arrow_rounded,
                        size: 10, color: _c.primary),
                  ),
                ),
              if (hasUnread)
                Positioned(
                  top: 1, right: 1,
                  child: Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.panelBg, width: 1.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            isAddStory
                ? 'Add'
                : isViewMyStory
                    ? 'My story'
                    : story.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: (hasUnread || isAddStory || isViewMyStory)
                  ? _c.primary
                  : _c.textDim,
              fontSize: 8,
              fontWeight: (hasUnread || isAddStory || isViewMyStory)
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
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

// ── Theme color resolver ──────────────────────────────────────────────────────
// Centralizes the light/dark lookups so the rest of the file just reads
// `_c.primary`, `_c.bg`, etc. — backed entirely by AppColors / Theme.
class _ThemeColors {
  final BuildContext context;
  _ThemeColors(this.context);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get primary     => _isDark ? AppColors.primaryLight : AppColors.primary;
  Color get bg          => _isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get surface     => _isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get primaryTint => _isDark ? AppColors.darkField : AppColors.lightField;
  Color get panelBg     => _isDark ? AppColors.darkField : AppColors.lightField;
  Color get panelBorder => _isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get textHi      => _isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textDim     => _isDark ? AppColors.darkTextDim : AppColors.lightTextDim;
}
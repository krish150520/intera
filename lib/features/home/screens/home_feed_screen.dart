import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
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
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg          = Color(0xFFEEF0FB);
  static const Color _surface     = Color(0xFFFFFFFF);
  static const Color _primary     = Color(0xFF6C63D5);
  static const Color _primaryLight= Color(0xFFEDE9FF);
  static const Color _panelBg     = Color(0xFFF5F4FF);
  static const Color _panelBorder = Color(0xFFE0DCFF);
  static const Color _textHi      = Color(0xFF2D1B69);
  static const Color _textDim     = Color(0xFF9E9BD0);

  static const double _panelWidth = 64.0;
  static const double _tabWidth   = 10.0;

  bool _drawerOpen = false;
  AnimationController? _anim;

  List<_RailStory> _railStories = [];
  List<StoryItem>  _storyItems  = [];
  bool _storiesLoading = true;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

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

  // ── Story loading ─────────────────────────────────────────────────────────
  Future<void> _loadStories() async {
  final myUid = _myUid;
  if (myUid.isEmpty) return;

  if (mounted && _railStories.isEmpty) setState(() => _storiesLoading = true);

  try {
    final now = DateTime.now();
    final List<_RailStory> rail  = [];
    final List<StoryItem>  items = [];

    // ── 1. My display name + avatar ───────────────────────────────────────────
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

    // ── 2. My own story ───────────────────────────────────────────────────────
    // Query by authorId ONLY — no range filter in Firestore → no composite index needed.
    // Filter expiry and sort in Dart.
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
        return bT.compareTo(aT); // latest first
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

    // ── 3. Following stories ──────────────────────────────────────────────────
    final followingSnap = await FirebaseFirestore.instance
        .collection('users').doc(myUid).collection('following').get();
    final followingUids = followingSnap.docs.map((d) => d.id).toList();

    if (followingUids.isNotEmpty) {
      for (var i = 0; i < followingUids.length; i += 30) {
        final chunk = followingUids.sublist(
          i,
          (i + 30) > followingUids.length ? followingUids.length : i + 30,
        );

        // whereIn on authorId only — filter expiresAt in Dart
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
      // Now errors are visible instead of silent
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load stories: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
  // ── Story tap ─────────────────────────────────────────────────────────────
  void _onStoryTap(_RailStory rail) {
    _closeDrawer();

    // No active story → go to create
    if (!rail.hasActiveStory) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.of(context).pushNamed(AppRoutes.createStory);
      });
      return;
    }

    // Has a story → open viewer (works for both own and others)
    final idx = _storyItems.indexWhere((s) => s.storyId == rail.storyId);
    if (idx < 0) {
      // Story exists in rail but not loaded into items yet — refresh
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
    final unread = _railStories.where((s) => !s.viewed && !s.isMe).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Feed
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(right: _tabWidth),
              child: _buildFeed(),
            ),
          ),

          // Scrim
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

          // Panel + tab
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
                  // Story panel
                  Positioned(
                    top: 0, bottom: 0,
                    right: -_panelWidth + (slide * _panelWidth),
                    width: _panelWidth,
                    child: _buildDrawerPanel(),
                  ),
                  // Pull tab
                  Positioned(
                    top: 0, bottom: 0,
                    right: slide * _panelWidth,
                    width: _tabWidth,
                    child: GestureDetector(
                      onTap: _toggleDrawer,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.horizontal(
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
                                    style: const TextStyle(
                                        color: _primary,
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
          return const Center(
              child: CircularProgressIndicator(color: _primary, strokeWidth: 2));
        }
        final docs = snapshot.data?.docs ?? [];
        return RefreshIndicator(
          color: _primary,
          backgroundColor: _surface,
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
      backgroundColor: _bg,
      elevation: 0,
      titleSpacing: 20,
      centerTitle: false,
      title: const Text(
        AppStrings.homeFeed,
        style: TextStyle(
            color: _textHi,
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
      color: _primaryLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _primary.withOpacity(0.15),
        child: SizedBox(
          width: 36, height: 36,
          child: Icon(icon, color: _primary, size: 20),
        ),
      ),
    );
  }

  // ── Story drawer panel ────────────────────────────────────────────────────
  Widget _buildDrawerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _panelBg,
        border: const Border(left: BorderSide(color: _panelBorder, width: 1)),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // ── "MOMENTS" label ───────────────────────────────────────────
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                'MOMENTS',
                style: TextStyle(
                    color: _textDim.withOpacity(0.6),
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _storiesLoading
                  ? const Center(
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: _primary, strokeWidth: 2),
                      ),
                    )
                  : _railStories.isEmpty
                      ? Center(
                          child: Icon(Icons.auto_stories_outlined,
                              color: _textDim.withOpacity(0.4), size: 20))
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
    final hasUnread  = !story.viewed && !story.isMe;
    // "Add story" state: my slot AND no active story
    final isAddStory = story.isMe && !story.hasActiveStory;
    // "View my story" state: my slot AND has an active story
    final isViewMyStory = story.isMe && story.hasActiveStory;

    return GestureDetector(
      onTap: () => _onStoryTap(story),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring — purple for unread others, gradient for my posted story
              if (hasUnread || isViewMyStory)
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isViewMyStory
                        ? const LinearGradient(
                            colors: [Color(0xFF6C63D5), Color(0xFFB39DDB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: hasUnread && !isViewMyStory ? _primary : null,
                  ),
                ),
              // Dashed border for "add story"
              if (isAddStory)
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primary,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                ),
              // No ring for viewed others
              if (!hasUnread && !isAddStory && !isViewMyStory)
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _panelBorder, width: 1.5,
                        strokeAlign: BorderSide.strokeAlignOutside),
                  ),
                ),

              // Avatar
              CircleAvatar(
                radius: 19,
                backgroundColor: _primaryLight,
                backgroundImage:
                    (story.avatar != null && story.avatar!.isNotEmpty)
                        ? NetworkImage(story.avatar!)
                        : null,
                child: (story.avatar == null || story.avatar!.isEmpty)
                    ? Text(
                        story.name.isNotEmpty
                            ? story.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      )
                    : null,
              ),

              // "+" badge for add story
              if (isAddStory)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: _panelBg, width: 1.5)),
                    child: const Icon(Icons.add, size: 10, color: Colors.white),
                  ),
                ),

              // Play icon overlay for my posted story
              if (isViewMyStory)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _panelBg, width: 1.5)),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 10, color: _primary),
                  ),
                ),

              // Unread dot for others
              if (hasUnread)
                Positioned(
                  top: 1, right: 1,
                  child: Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _panelBg, width: 1.5)),
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
                  ? _primary
                  : _textDim,
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
        const Icon(Icons.wifi_off_rounded, color: _textDim, size: 36),
        const SizedBox(height: 10),
        const Text('Could not load feed',
            style: TextStyle(color: _textHi, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(msg,
            style: const TextStyle(color: _textDim, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
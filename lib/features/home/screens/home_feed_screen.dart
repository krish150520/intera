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
import 'story_viewver_screen.dart';
import '../../../core/services/notification_service.dart';

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

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  List<_RailStory> _railStories = [];
  List<StoryItem>  _storyItems  = [];
  bool _storiesLoading = true;

  late final Stream<QuerySnapshot> _postsStream;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Theme-aware color getters ────────────────────────────────────────────
  late AppColorsExtension _c;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
    super.dispose();
  }

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
            backgroundColor: context.appColors.error,
          ),
        );
      }
    }
  }

  // ── Story tap ─────────────────────────────────────────────────────────────
  void _onStoryTap(_RailStory rail) {
    if (!rail.hasActiveStory) {
      Navigator.of(context).pushNamed(AppRoutes.createStory);
      return;
    }

    final idx = _storyItems.indexWhere((s) => s.storyId == rail.storyId);
    if (idx < 0) {
      _loadStories();
      return;
    }

    if (!rail.isMe) {
      setState(() {
        rail.viewed = true;
      });
      FirebaseFirestore.instance
          .collection('stories')
          .doc(rail.storyId)
          .update({
        'viewedBy': FieldValue.arrayUnion([_myUid])
      });
    }

    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => StoryViewerScreen(
        args: StoryViewerArgs(stories: _storyItems, initialIndex: idx),
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  // ── Like / save ───────────────────────────────────────────────────────────
  Future<void> _handleLike(String postId, String authorId, String title, List likedBy) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await NotificationService.toggleLike(
      postId: postId,
      postAuthorId: authorId,
      postTitle: title,
      currentUid: uid,
      likedBy: likedBy,
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

  // ── Feed & Story Tray ─────────────────────────────────────────────────────
  Widget _buildFeed() {
    final currentUid = _myUid;
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
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
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildStoryTray();
              }
              final doc    = docs[index - 1];
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
                  onLike:    () => _handleLike(doc.id, post.authorId, post.title, likedBy),
                  onSave:    () => _handleSave(doc.id, savedBy),
                  onComment: () => Navigator.of(context)
                      .pushNamed(AppRoutes.postDetail, arguments: post),
                  onShare: () {
                    Clipboard.setData(ClipboardData(
                        text: 'Check out this post on INTERA by ${post.authorUsername}:\n\n${post.title}\n${post.body}'));
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

  Widget _buildStoryTray() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 106,
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _c.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _storiesLoading
          ? ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, __) => _buildShimmerAvatar(),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _railStories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildStoryAvatar(_railStories[index]);
              },
            ),
    );
  }

  Widget _buildShimmerAvatar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _c.field,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 8,
          decoration: BoxDecoration(
            color: _c.field,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryAvatar(_RailStory story) {
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
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isViewMyStory ? _c.storyRingGradient : _c.primaryGradient,
                  ),
                ),
              if (isAddStory)
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _c.primary.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                ),
              if (!hasUnread && !isAddStory && !isViewMyStory)
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _c.border,
                      width: 1.5,
                    ),
                  ),
                ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _c.surface,
                ),
              ),
              CircleAvatar(
                radius: 24,
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
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      )
                    : null,
              ),
              if (isAddStory)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                        color: _c.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.surface, width: 1.5)),
                    child: const Icon(Icons.add, size: 12, color: Colors.white),
                  ),
                ),
              if (isViewMyStory)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.surface, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                          )
                        ]),
                    child: Icon(Icons.play_arrow_rounded,
                        size: 12, color: _c.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              isAddStory
                  ? 'Your story'
                  : isViewMyStory
                      ? 'My story'
                      : story.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (hasUnread || isAddStory || isViewMyStory)
                    ? _c.textPrimary
                    : _c.textDim,
                fontSize: 10,
                fontWeight: (hasUnread || isAddStory || isViewMyStory)
                    ? FontWeight.w600
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
      titleSpacing: 20,
      centerTitle: false,
      title: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [_c.primary, _c.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          AppStrings.homeFeed,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8),
        ),
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
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 10),
        _appBarBtn(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MessagesListScreen())),
        ),
        const SizedBox(width: 18),
      ],
    );
  }

  Widget _appBarBtn({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: _c.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: _c.border.withOpacity(0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: _c.primary.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: _c.textPrimary, size: 20),
          ),
        ),
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


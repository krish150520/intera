import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/models/post_model.dart';
import '../widgets/post_card.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../messaging/screens/messages_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Story data model
// ─────────────────────────────────────────────────────────────────────────────
class _StoryEntry {
  final String uid;
  final String name;
  final String? avatar;
  final String storyId;
  final bool isMe;
  bool viewed;

  _StoryEntry({
    required this.uid,
    required this.name,
    this.avatar,
    required this.storyId,
    required this.isMe,
    this.viewed = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeFeedScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with SingleTickerProviderStateMixin {
  // ── Design tokens ─────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFEEF0FB);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _cardBg  = Color(0xFFF5F4FF);
  static const Color _border  = Color(0xFFE4E2F8);
  static const Color _primary = Color(0xFF6C63D5);
  static const Color _textHi  = Color(0xFF2D1B69);
  static const Color _textDim = Color(0xFF9E9BD0);

  // ── Rail animation ────────────────────────────────────────────────────────
  bool _railExpanded = false;
  AnimationController? _railAnim;
  Animation<double>? _railWidth; // animates 64 → 100

  // ── Story data ────────────────────────────────────────────────────────────
  List<_StoryEntry> _stories = [];
  bool _storiesLoading = true;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _railAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _railWidth = Tween<double>(begin: 64, end: 100).animate(
      CurvedAnimation(parent: _railAnim!, curve: Curves.easeOutCubic),
    );
    _loadStories();
  }

  @override
  void dispose() {
    _railAnim?.dispose();
    super.dispose();
  }

  // ── Toggle rail width ─────────────────────────────────────────────────────
  void _toggleRail() {
    setState(() => _railExpanded = !_railExpanded);
    if (_railExpanded) {
      _railAnim?.forward();
    } else {
      _railAnim?.reverse();
    }
  }

  // ── Load stories ──────────────────────────────────────────────────────────
  Future<void> _loadStories() async {
    final myUid = _myUid;
    if (myUid.isEmpty) return;
    setState(() => _storiesLoading = true);

    try {
      final now = DateTime.now();
      final List<_StoryEntry> entries = [];

      // My story slot — always first
      final mySnap = await FirebaseFirestore.instance
          .collection('stories')
          .where('authorId', isEqualTo: myUid)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .limit(1)
          .get();

      entries.add(_StoryEntry(
        uid: myUid,
        name: 'My Story',
        avatar: FirebaseAuth.instance.currentUser?.photoURL,
        storyId: mySnap.docs.isNotEmpty ? mySnap.docs.first.id : '',
        isMe: true,
        viewed: true,
      ));

      // Get following UIDs
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
            (i + 30) > followingUids.length ? followingUids.length : i + 30,
          );

          final snap = await FirebaseFirestore.instance
              .collection('stories')
              .where('authorId', whereIn: chunk)
              .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
              .orderBy('expiresAt', descending: true)
              .get();

          final seen = <String>{};
          for (final doc in snap.docs) {
            final data = doc.data();
            final authorId = data['authorId'] as String;
            if (seen.contains(authorId)) continue;
            seen.add(authorId);
            final viewedBy = List<String>.from(data['viewedBy'] ?? []);
            entries.add(_StoryEntry(
              uid: authorId,
              name: data['authorName'] ?? 'User',
              avatar: data['authorAvatar'],
              storyId: doc.id,
              isMe: false,
              viewed: viewedBy.contains(myUid),
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _stories = entries;
          _storiesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _storiesLoading = false);
    }
  }

  // ── Story tap ─────────────────────────────────────────────────────────────
  void _onStoryTap(_StoryEntry story) {
    if (story.isMe) {
      Navigator.of(context).pushNamed(AppRoutes.createStory);
      return;
    }
    if (!story.viewed && story.storyId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('stories')
          .doc(story.storyId)
          .update({'viewedBy': FieldValue.arrayUnion([_myUid])});
      setState(() => story.viewed = true);
    }
    // TODO: push to full-screen story viewer
  }

  // ── Like / save ───────────────────────────────────────────────────────────
  void _handleLike(String postId, List likedBy) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (likedBy.contains(uid)) {
      await ref.update({'likeCount': FieldValue.increment(-1), 'likedBy': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likeCount': FieldValue.increment(1), 'likedBy': FieldValue.arrayUnion([uid])});
    }
  }

  void _handleSave(String postId, List savedBy) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (savedBy.contains(uid)) {
      await ref.update({'savedBy': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'savedBy': FieldValue.arrayUnion([uid])});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUid = _myUid;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Animated left rail ───────────────────────────────────────
          AnimatedBuilder(
            animation: _railWidth ?? AlwaysStoppedAnimation(64),
            builder: (context, _) =>
                _buildRail(_railWidth?.value ?? 64),
          ),

          // ── Post feed ────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _primary, strokeWidth: 2),
                  );
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
                    padding: const EdgeInsets.fromLTRB(0, 12, 12, 100),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final List likedBy = data['likedBy'] ?? [];
                      final List savedBy = data['savedBy'] ?? [];
                      final post = Post.fromFirestore(doc, currentUid);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PostCard(
                          post: post,
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.postDetail, arguments: post),
                          onLike: () => _handleLike(doc.id, likedBy),
                          onSave: () => _handleSave(doc.id, savedBy),
                          onComment: () => Navigator.of(context)
                              .pushNamed(AppRoutes.postDetail, arguments: post),
                          onShare: () {},
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      titleSpacing: 20,
      title: const Text(
        AppStrings.homeFeed,
        style: TextStyle(
          color: _textHi,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        _appBarBtn(
          icon: Icons.send_outlined,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MessagesListScreen())),
        ),
        const SizedBox(width: 10),
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
    return ClipOval(
      child: Material(
        color: _cardBg,
        child: InkWell(
          onTap: onTap,
          splashColor: _primary.withOpacity(0.18),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, color: _primary, size: 20),
          ),
        ),
      ),
    );
  }

  // ── Left rail ─────────────────────────────────────────────────────────────
  Widget _buildRail(double width) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(right: BorderSide(color: _border, width: 0.5)),
      ),
      child: Column(
        children: [
          // Arrow toggle button
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: GestureDetector(
              onTap: _toggleRail,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: AnimatedRotation(
                  turns: _railExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 280),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _primary,
                  ),
                ),
              ),
            ),
          ),

          // Stories
          Expanded(
            child: _storiesLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: _primary, strokeWidth: 2),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _stories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    itemBuilder: (context, index) =>
                        _buildStoryTile(_stories[index], width),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryTile(_StoryEntry story, double railWidth) {
    final hasUnread = !story.viewed && !story.isMe;
    final showName = railWidth > 80;

    return GestureDetector(
      onTap: () => _onStoryTap(story),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Gradient ring for unread, plain border for viewed
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasUnread
                      ? const LinearGradient(
                          colors: [Color(0xFF6C63D5), Color(0xFF3B2F8F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: !hasUnread
                      ? Border.all(color: _border, width: 1.5)
                      : null,
                ),
              ),
              // Avatar
              CircleAvatar(
                radius: 19,
                backgroundColor: _cardBg,
                backgroundImage:
                    (story.avatar != null && story.avatar!.isNotEmpty)
                        ? NetworkImage(story.avatar!)
                        : null,
                child: (story.avatar == null || story.avatar!.isEmpty)
                    ? Text(
                        story.name[0],
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
              // Add badge
              if (story.isMe)
                Positioned(
                  bottom: 0,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          // Name fades in when expanded
          if (showName) ...[
            const SizedBox(height: 5),
            AnimatedOpacity(
              opacity: showName ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  story.isMe ? 'My' : story.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        hasUnread ? FontWeight.w600 : FontWeight.w400,
                    color: hasUnread ? _textHi : _textDim,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: _textDim, size: 36),
          const SizedBox(height: 10),
          const Text('Could not load feed',
              style: TextStyle(color: _textHi, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(msg,
              style: const TextStyle(color: _textDim, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Story model — passed in from HomeFeedScreen / rail tap
// ─────────────────────────────────────────────────────────────────────────────
class StoryViewerArgs {
  /// All story entries to show (one per user, in order).
  final List<StoryItem> stories;

  /// Which index to start at.
  final int initialIndex;

  const StoryViewerArgs({
    required this.stories,
    required this.initialIndex,
  });
}

class StoryItem {
  final String storyId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? mediaUrl;
  final bool isVideo;
  final String? caption;
  final List<int>? gradientColors; // two Color.value ints
  final DateTime createdAt;

  const StoryItem({
    required this.storyId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.mediaUrl,
    this.isVideo = false,
    this.caption,
    this.gradientColors,
    required this.createdAt,
  });

  factory StoryItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StoryItem(
      storyId: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'User',
      authorAvatar: d['authorAvatar'],
      mediaUrl: d['mediaUrl'],
      isVideo: d['isVideo'] ?? false,
      caption: d['caption'],
      gradientColors: d['gradientColors'] != null
          ? List<int>.from(d['gradientColors'])
          : null,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Viewer screen
// ─────────────────────────────────────────────────────────────────────────────
class StoryViewerScreen extends StatefulWidget {
  final StoryViewerArgs args;
  const StoryViewerScreen({super.key, required this.args});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ─────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF6C63D5);
  static const Color _cardBg  = Color(0xFF1C1B2E);

  // ── Story navigation ──────────────────────────────────────────────────────
  late int _currentIndex;
  StoryItem get _current => widget.args.stories[_currentIndex];
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Progress bar animation ────────────────────────────────────────────────
  AnimationController? _progressCtrl;
  static const Duration _storyDuration = Duration(seconds: 5);

  // ── Pause on long-press ───────────────────────────────────────────────────
  bool _paused = false;

  // ── Viewers bottom sheet ──────────────────────────────────────────────────
  bool _showViewers = false;
  List<Map<String, dynamic>> _viewers = [];
  bool _viewersLoading = false;

  // ── Image loaded flag ─────────────────────────────────────────────────────
  bool _mediaReady = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.args.initialIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initStory();
  }

  @override
  void dispose() {
    _progressCtrl?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Set up progress timer for current story ───────────────────────────────
  void _initStory() {
    _progressCtrl?.dispose();
    _mediaReady = _current.mediaUrl == null; // text stories are instant-ready

    _progressCtrl = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _nextStory();
      });

    // Mark as viewed in Firestore
    _markViewed();

    if (_mediaReady) _progressCtrl!.forward();
    setState(() {});
  }

  void _markViewed() {
    if (_current.authorId == _myUid) return;
    FirebaseFirestore.instance
        .collection('stories')
        .doc(_current.storyId)
        .update({'viewedBy': FieldValue.arrayUnion([_myUid])});
  }

  void _onMediaReady() {
    if (!_mediaReady) {
      setState(() => _mediaReady = true);
      _progressCtrl?.forward();
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _nextStory() {
    if (_currentIndex < widget.args.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _showViewers = false;
      });
      _initStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showViewers = false;
      });
      _initStory();
    }
  }

  void _pause() {
    _progressCtrl?.stop();
    setState(() => _paused = true);
  }

  void _resume() {
    if (_mediaReady) _progressCtrl?.forward();
    setState(() => _paused = false);
  }

  // ── Viewers sheet ─────────────────────────────────────────────────────────
  Future<void> _openViewers() async {
    if (_current.authorId != _myUid) return;
    _pause();
    setState(() {
      _showViewers = true;
      _viewersLoading = true;
      _viewers = [];
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('stories')
          .doc(_current.storyId)
          .get();
      final viewedBy =
          List<String>.from(doc.data()?['viewedBy'] ?? []);

      final List<Map<String, dynamic>> result = [];
      for (final uid in viewedBy) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = userDoc.data() ?? {};
        result.add({
          'uid': uid,
          'name': data['name'] ?? 'User',
          'avatar': data['avatarUrl'],
        });
      }

      if (mounted) {
        setState(() {
          _viewers = result;
          _viewersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _viewersLoading = false);
    }
  }

  void _closeViewers() {
    setState(() => _showViewers = false);
    _resume();
  }

  // ── Relative time label ───────────────────────────────────────────────────
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final story = _current;
    final isOwn = story.authorId == _myUid;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Full-screen background ──────────────────────────────────
          Positioned.fill(child: _buildBackground(story)),

          // ── 2. Bottom gradient scrim ───────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: size.height * 0.35,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // ── 3. Tap zones: left = prev, right = next ────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTapUp: (details) {
                if (_showViewers) return;
                final x = details.globalPosition.dx;
                if (x < size.width * 0.35) {
                  _prevStory();
                } else {
                  _nextStory();
                }
              },
              onLongPressStart: (_) => _pause(),
              onLongPressEnd: (_) => _resume(),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

          // ── 4. Progress bars ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: List.generate(
                  widget.args.stories.length,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: i < widget.args.stories.length - 1
                              ? 4
                              : 0),
                      child: _ProgressBar(
                        filled: i < _currentIndex,
                        active: i == _currentIndex,
                        controller: i == _currentIndex
                            ? _progressCtrl
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 5. Header: avatar + name + time + close ────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _primary, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: _cardBg,
                      backgroundImage: (story.authorAvatar != null &&
                              story.authorAvatar!.isNotEmpty)
                          ? NetworkImage(story.authorAvatar!)
                          : null,
                      child: (story.authorAvatar == null ||
                              story.authorAvatar!.isEmpty)
                          ? Text(
                              story.authorName[0],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          story.authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _timeAgo(story.createdAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pause indicator
                  if (_paused)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('PAUSED',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ),
                  // Close
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 6. Caption ─────────────────────────────────────────────────
          if (story.caption != null && story.caption!.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: isOwn ? 100 : 60,
              child: Text(
                story.caption!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  shadows: [
                    Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),

          // ── 7. Viewers bar (own stories only) ──────────────────────────
          if (isOwn)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: _openViewers,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Seen by',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        const Spacer(),
                        const Icon(Icons.keyboard_arrow_up_rounded,
                            color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── 8. Viewers bottom sheet ────────────────────────────────────
          if (_showViewers)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeViewers,
                child: Container(color: Colors.black54),
              ),
            ),
          if (_showViewers)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildViewersSheet(),
            ),
        ],
      ),
    );
  }

  // ── Background layer ──────────────────────────────────────────────────────
  Widget _buildBackground(StoryItem story) {
    if (story.mediaUrl != null && !story.isVideo) {
      return Image.network(
        story.mediaUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _onMediaReady());
            return child;
          }
          return _gradientBg(story);
        },
        errorBuilder: (_, __, ___) => _gradientBg(story),
      );
    }
    if (story.mediaUrl != null && story.isVideo) {
      // Video placeholder — integrate video_player package if needed
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _onMediaReady());
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle_fill_rounded,
                    size: 64, color: Colors.white60),
              ),
              const SizedBox(height: 12),
              Text('Video story',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return _gradientBg(story);
  }

  Widget _gradientBg(StoryItem story) {
    final colors = (story.gradientColors != null &&
            story.gradientColors!.length >= 2)
        ? [
            Color(story.gradientColors![0]),
            Color(story.gradientColors![1])
          ]
        : [const Color(0xFF6C63D5), const Color(0xFF3B2F8F)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  // ── Viewers sheet ─────────────────────────────────────────────────────────
  Widget _buildViewersSheet() {
    return GestureDetector(
      onTap: () {}, // prevent scrim close when tapping inside
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined,
                      color: Color(0xFF9E9BD0), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _viewersLoading
                        ? 'Loading viewers…'
                        : '${_viewers.length} ${_viewers.length == 1 ? 'viewer' : 'viewers'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _closeViewers,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            // List
            if (_viewersLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                    color: Color(0xFF6C63D5), strokeWidth: 2),
              )
            else if (_viewers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.visibility_off_outlined,
                        color: Color(0xFF9E9BD0), size: 32),
                    const SizedBox(height: 10),
                    Text(
                      'No one has viewed this yet',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _viewers.length,
                  itemBuilder: (context, i) {
                    final v = _viewers[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF2D2B45),
                        backgroundImage: (v['avatar'] != null &&
                                (v['avatar'] as String).isNotEmpty)
                            ? NetworkImage(v['avatar'])
                            : null,
                        child: (v['avatar'] == null ||
                                (v['avatar'] as String).isEmpty)
                            ? Text(
                                (v['name'] as String)[0],
                                style: const TextStyle(
                                    color: Color(0xFF6C63D5),
                                    fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      title: Text(
                        v['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '@${(v['name'] as String).toLowerCase().replaceAll(' ', '')}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            // Bottom safe area padding
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar widget
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final bool filled;
  final bool active;
  final AnimationController? controller;

  const _ProgressBar({
    required this.filled,
    required this.active,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 2.5,
        child: filled
            ? const ColoredBox(color: Colors.white)
            : active && controller != null
                ? AnimatedBuilder(
                    animation: controller!,
                    builder: (_, __) => LinearProgressIndicator(
                      value: controller!.value,
                      backgroundColor: Colors.white30,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 2.5,
                    ),
                  )
                : const ColoredBox(color: Colors.white30),
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StoryViewerArgs {
  final List<StoryItem> stories;
  final int initialIndex;
  const StoryViewerArgs({required this.stories, required this.initialIndex});
}

class StoryItem {
  final String storyId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? mediaUrl;
  final bool isVideo;
  final String? caption;
  final List<int>? gradientColors;
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

class StoryViewerScreen extends StatefulWidget {
  final StoryViewerArgs args;
  const StoryViewerScreen({super.key, required this.args});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF6C63D5);
  static const Color _cardBg  = Color(0xFF1C1B2E);

  late int _currentIndex;
  StoryItem get _current => widget.args.stories[_currentIndex];
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  AnimationController? _progressCtrl;
  static const Duration _storyDuration = Duration(seconds: 5);

  bool _paused         = false;
  bool _showViewers    = false;
  bool _viewersLoading = false;
  bool _mediaReady     = false;
  bool _isDeleting     = false;
  List<Map<String, dynamic>> _viewers = [];

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

  void _initStory() {
    _progressCtrl?.dispose();
    _mediaReady = _current.mediaUrl == null || _current.mediaUrl!.isEmpty;

    _progressCtrl = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _nextStory();
      });

    _markViewed();
    if (_mediaReady) _progressCtrl!.forward();
    setState(() {});
  }

  void _markViewed() {
    if (_current.authorId == _myUid) return;
    FirebaseFirestore.instance
        .collection('stories')
        .doc(_current.storyId)
        .update({'viewedBy': FieldValue.arrayUnion([_myUid])})
        .catchError((_) {});
  }

  void _onMediaReady() {
    if (!_mediaReady && mounted) {
      setState(() => _mediaReady = true);
      _progressCtrl?.forward();
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.args.stories.length - 1) {
      setState(() { _currentIndex++; _showViewers = false; });
      _initStory();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() { _currentIndex--; _showViewers = false; });
      _initStory();
    } else {
      _progressCtrl?.reset();
      _progressCtrl?.forward();
    }
  }

  void _pause()  { _progressCtrl?.stop(); setState(() => _paused = true); }
  void _resume() { if (_mediaReady) _progressCtrl?.forward(); setState(() => _paused = false); }

  // ── Delete story ──────────────────────────────────────────────────────────
  Future<void> _deleteStory() async {
    // Show confirmation dialog — pause timer while it's open
    _pause();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete story?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will remove your story for everyone immediately.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    // User cancelled — resume timer and bail
    if (confirm != true) {
      _resume();
      return;
    }

    if (!mounted) return;
    setState(() => _isDeleting = true);

    try {
      final storyId  = _current.storyId;
      final mediaUrl = _current.mediaUrl;

      // 1. Delete Firestore document
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .delete();

      // 2. Delete Storage file if one exists (image / video)
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        try {
          final uri       = Uri.parse(mediaUrl);
          final pathMatch = RegExp(r'/o/(.+?)(\?|$)').firstMatch(uri.path);
          if (pathMatch != null) {
            final storagePath = Uri.decodeComponent(pathMatch.group(1)!);
            await FirebaseStorage.instance.ref(storagePath).delete();
          }
        } catch (e) {
          // Non-fatal — Firestore doc is gone, Storage cleanup failing is ok
          debugPrint('Storage delete failed: $e');
        }
      }

      if (!mounted) return;

      // 3. Move to next story if available, otherwise close viewer
      if (_currentIndex < widget.args.stories.length - 1) {
        setState(() { _currentIndex++; _showViewers = false; _isDeleting = false; });
        _initStory();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete story: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Viewers sheet ─────────────────────────────────────────────────────────
  Future<void> _openViewers() async {
    if (_current.authorId != _myUid) return;
    _pause();
    setState(() { _showViewers = true; _viewersLoading = true; _viewers = []; });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('stories').doc(_current.storyId).get();
      final viewedBy = List<String>.from(doc.data()?['viewedBy'] ?? []);

      final result = <Map<String, dynamic>>[];
      for (final uid in viewedBy) {
        final uDoc = await FirebaseFirestore.instance
            .collection('users').doc(uid).get();
        final data = uDoc.data() ?? {};
        result.add({
          'uid': uid,
          'name': data['name'] ?? 'User',
          'avatar': data['avatarUrl'] ?? '',
        });
      }
      if (mounted) setState(() { _viewers = result; _viewersLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _viewersLoading = false);
    }
  }

  void _closeViewers() { setState(() => _showViewers = false); _resume(); }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24)   return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final story  = _current;
    final isOwn  = story.authorId == _myUid;
    final size   = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ── 1. Background ─────────────────────────────────────────────────
          _buildBackground(story),

          // ── 2. Top gradient scrim ─────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0, height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── 3. Bottom gradient scrim ──────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.35,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // ── 4. Tap / hold gesture catcher ────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) {
                if (_showViewers || _isDeleting) return;
                d.localPosition.dx < size.width * 0.35
                    ? _prevStory()
                    : _nextStory();
              },
              onLongPressStart: (_) => _pause(),
              onLongPressEnd:   (_) => _resume(),
              child: const SizedBox.expand(),
            ),
          ),

          // ── 5. Progress bars + header (one Positioned block) ──────────────
          Positioned(
            top: topPad + 8,
            left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Progress bars
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: List.generate(widget.args.stories.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: i < widget.args.stories.length - 1 ? 4 : 0),
                          child: _ProgressBar(
                            filled: i < _currentIndex,
                            active: i == _currentIndex,
                            controller:
                                i == _currentIndex ? _progressCtrl : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 10),

                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                  story.authorName.isNotEmpty
                                      ? story.authorName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700))
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
                            Text(story.authorName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            Text(_timeAgo(story.createdAt),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11)),
                          ],
                        ),
                      ),

                      // Paused pill
                      if (_paused && !_isDeleting)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
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

                      // ── Delete button (own stories only) ──────────────────
                      if (isOwn)
                        GestureDetector(
                          onTap: _isDeleting ? null : _deleteStory,
                          child: Container(
                            width: 32, height: 32,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                                color: Colors.black38,
                                shape: BoxShape.circle),
                            child: _isDeleting
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                        color: Colors.redAccent,
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 18),
                          ),
                        ),

                      // Close button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(
                              color: Colors.black38, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 6. Caption ────────────────────────────────────────────────────
          if (story.caption != null && story.caption!.isNotEmpty)
            Positioned(
              left: 20, right: 20,
              bottom: isOwn ? (botPad + 90) : (botPad + 40),
              child: Text(
                story.caption!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  shadows: [Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2))],
                ),
              ),
            ),

          // ── 7. "Seen by" bar — own stories only ───────────────────────────
          if (isOwn && !_showViewers && !_isDeleting)
            Positioned(
              left: 0, right: 0,
              bottom: botPad + 16,
              child: GestureDetector(
                onTap: _openViewers,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined,
                          color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text('Seen by',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Spacer(),
                      Icon(Icons.keyboard_arrow_up_rounded,
                          color: Colors.white54, size: 20),
                    ],
                  ),
                ),
              ),
            ),

          // ── 8. Viewers sheet ──────────────────────────────────────────────
          if (_showViewers) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeViewers,
                child: const ColoredBox(color: Colors.black54),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildViewersSheet(),
            ),
          ],

          // ── 9. Deleting overlay ───────────────────────────────────────────
          if (_isDeleting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.55),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: Colors.redAccent, strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text('Deleting story…',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────
  Widget _buildBackground(StoryItem story) {
    if (story.mediaUrl != null &&
        story.mediaUrl!.isNotEmpty &&
        !story.isVideo) {
      return Image.network(
        story.mediaUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (_, child, progress) {
          if (progress == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _onMediaReady());
            return child;
          }
          return _gradientBg(story);
        },
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _onMediaReady());
          return _gradientBg(story);
        },
      );
    }

    if (story.mediaUrl != null &&
        story.mediaUrl!.isNotEmpty &&
        story.isVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onMediaReady());
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
                      color: Colors.white.withOpacity(0.4), fontSize: 13)),
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

    return DecoratedBox(
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
      onTap: () {},
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined,
                      color: Color(0xFF9E9BD0), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _viewersLoading
                        ? 'Loading...'
                        : '${_viewers.length} ${_viewers.length == 1 ? 'viewer' : 'viewers'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _closeViewers,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.white12, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
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
                    Text('No one has viewed this yet',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 13)),
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
                    final v      = _viewers[i];
                    final avatar = v['avatar'] as String? ?? '';
                    final name   = v['name'] as String;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF2D2B45),
                        backgroundImage: avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: Color(0xFF6C63D5),
                                    fontWeight: FontWeight.w700))
                            : null,
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      subtitle: Text(
                          '@${name.toLowerCase().replaceAll(' ', '')}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 12)),
                    );
                  },
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final bool filled;
  final bool active;
  final AnimationController? controller;
  const _ProgressBar(
      {required this.filled, required this.active, this.controller});

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
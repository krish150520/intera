import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../core/services/notification_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class SparkViewerArgs {
  final List<SparkItem> sparks;
  final int initialIndex;
  const SparkViewerArgs({required this.sparks, required this.initialIndex});
}

class SparkItem {
  final String sparkId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? mediaUrl;
  final bool isVideo;
  final String? caption;
  final List<int>? gradientColors;
  final DateTime createdAt;

  const SparkItem({
    required this.sparkId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.mediaUrl,
    this.isVideo = false,
    this.caption,
    this.gradientColors,
    required this.createdAt,
  });

  factory SparkItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SparkItem(
      sparkId: doc.id,
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

// ═══════════════════════════════════════════════════════════════════════════════
//  SPARK VIEWER SCREEN — Instagram-style
// ═══════════════════════════════════════════════════════════════════════════════

class SparkViewerScreen extends StatefulWidget {
  final SparkViewerArgs args;
  const SparkViewerScreen({super.key, required this.args});

  @override
  State<SparkViewerScreen> createState() => _SparkViewerScreenState();
}

class _SparkViewerScreenState extends State<SparkViewerScreen>
    with TickerProviderStateMixin {
  late int _currentIndex;
  SparkItem get _current => widget.args.sparks[_currentIndex];
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  AnimationController? _progressCtrl;
  static const Duration _sparkDuration = Duration(seconds: 5);

  bool _paused = false;
  bool _showViewers = false;
  bool _viewersLoading = false;
  bool _mediaReady = false;
  bool _isDeleting = false;
  List<Map<String, dynamic>> _viewers = [];

  // ── Swipe-to-dismiss state ──────────────────────────────────────────────
  double _dragOffset = 0;
  bool _isDragging = false;

  // ── Reply ───────────────────────────────────────────────────────────────
  final _replyController = TextEditingController();
  bool _showReplyField = false;
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.args.initialIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initSpark();
  }

  @override
  void dispose() {
    _progressCtrl?.dispose();
    _replyController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Spark lifecycle ─────────────────────────────────────────────────────
  void _initSpark() {
    _progressCtrl?.dispose();
    _mediaReady = _current.mediaUrl == null || _current.mediaUrl!.isEmpty;

    _progressCtrl = AnimationController(vsync: this, duration: _sparkDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _nextSpark();
      });

    _markViewed();
    if (_mediaReady) _progressCtrl!.forward();
    setState(() {});
  }

  void _markViewed() {
    if (_current.authorId == _myUid) return;
    FirebaseFirestore.instance
        .collection('stories')
        .doc(_current.sparkId)
        .update({
      'viewedBy': FieldValue.arrayUnion([_myUid])
    }).catchError((_) {});
  }

  void _onMediaReady() {
    if (!_mediaReady && mounted) {
      setState(() => _mediaReady = true);
      _progressCtrl?.forward();
    }
  }

  void _nextSpark() {
    if (_currentIndex < widget.args.sparks.length - 1) {
      setState(() {
        _currentIndex++;
        _showViewers = false;
        _showReplyField = false;
      });
      _initSpark();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _prevSpark() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showViewers = false;
        _showReplyField = false;
      });
      _initSpark();
    } else {
      _progressCtrl?.reset();
      _progressCtrl?.forward();
    }
  }

  void _pause() {
    _progressCtrl?.stop();
    setState(() => _paused = true);
  }

  void _resume() {
    if (_mediaReady && !_showReplyField) _progressCtrl?.forward();
    setState(() => _paused = false);
  }

  // ── Delete spark ────────────────────────────────────────────────────────
  Future<void> _deleteSpark() async {
    _pause();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete spark?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
            'This will remove your spark for everyone immediately.',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
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

    if (confirm != true) {
      _resume();
      return;
    }

    if (!mounted) return;
    setState(() => _isDeleting = true);

    try {
      final sparkId = _current.sparkId;
      final mediaUrl = _current.mediaUrl;

      await FirebaseFirestore.instance
          .collection('stories')
          .doc(sparkId)
          .delete();

      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(mediaUrl);
          final pathMatch = RegExp(r'/o/(.+?)(\?|$)').firstMatch(uri.path);
          if (pathMatch != null) {
            final storagePath = Uri.decodeComponent(pathMatch.group(1)!);
            await FirebaseStorage.instance.ref(storagePath).delete();
          }
        } catch (e) {
          debugPrint('Storage delete failed: $e');
        }
      }

      if (!mounted) return;

      if (_currentIndex < widget.args.sparks.length - 1) {
        setState(() {
          _currentIndex++;
          _showViewers = false;
          _isDeleting = false;
        });
          _initSpark();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not delete spark: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  // ── Viewers sheet ───────────────────────────────────────────────────────
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
          .doc(_current.sparkId)
          .get();
      final viewedBy = List<String>.from(doc.data()?['viewedBy'] ?? []);

      final result = <Map<String, dynamic>>[];
      for (final uid in viewedBy) {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = uDoc.data() ?? {};
        result.add({
          'uid': uid,
          'name': data['name'] ?? 'User',
          'avatar': data['avatarUrl'] ?? '',
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

  // ── Reply ───────────────────────────────────────────────────────────────
  void _toggleReply() {
    setState(() => _showReplyField = !_showReplyField);
    if (_showReplyField) {
      _pause();
    } else {
      _resume();
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sendingReply = true);

    try {
      // Save reply to subcollection
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(_current.sparkId)
          .collection('replies')
          .add({
        'senderId': _myUid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notification to spark author
      NotificationService.sendNotification(
        recipientId: _current.authorId,
        type: 'spark_reply',
        title: 'replied to your spark',
        subtitle: text,
        relatedId: _current.sparkId,
      );

      _replyController.clear();
      setState(() {
        _showReplyField = false;
        _sendingReply = false;
      });
      _resume();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reply sent!'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _sendingReply = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reply: $e')),
        );
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final spark = _current;
    final isOwn = spark.authorId == _myUid;
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    // ── Swipe-to-dismiss transform ────────────────────────────────────────
    final dismissProgress = (_dragOffset / (size.height * 0.4)).clamp(0.0, 1.0);
    final scale = 1.0 - (dismissProgress * 0.15);
    final radius = dismissProgress * 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // ── Vertical drag for dismiss ──────────────────────────────────
        onVerticalDragStart: (_) {
          if (_showViewers || _isDeleting || _showReplyField) return;
          _isDragging = true;
          _pause();
        },
        onVerticalDragUpdate: (details) {
          if (!_isDragging) return;
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, size.height * 0.5);
          });
        },
        onVerticalDragEnd: (_) {
          if (!_isDragging) return;
          _isDragging = false;
          if (_dragOffset > size.height * 0.15) {
            Navigator.of(context).pop();
          } else {
            setState(() => _dragOffset = 0);
            _resume();
          }
        },
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Transform.scale(
            scale: scale,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── 1. Background ─────────────────────────────────────────
                  _buildBackground(spark),

                  // ── 2. Top scrim ──────────────────────────────────────────
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 180,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── 3. Bottom scrim ───────────────────────────────────────
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: size.height * 0.35,
                    child: const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── 4. Tap / hold gesture ─────────────────────────────────
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (d) {
                        if (_showViewers || _isDeleting || _showReplyField) return;
                        d.localPosition.dx < size.width * 0.35
                            ? _prevSpark()
                            : _nextSpark();
                      },
                      onLongPressStart: (_) => _pause(),
                      onLongPressEnd: (_) => _resume(),
                      child: const SizedBox.expand(),
                    ),
                  ),

                  // ── 5. Progress bars + header ─────────────────────────────
                  Positioned(
                    top: topPad + 8,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bars
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: List.generate(
                                widget.args.sparks.length, (i) {
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      right:
                                          i < widget.args.sparks.length - 1
                                              ? 3
                                              : 0),
                                  child: _ProgressBar(
                                    filled: i < _currentIndex,
                                    active: i == _currentIndex,
                                    controller: i == _currentIndex
                                        ? _progressCtrl
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Header row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              // Avatar with gradient ring
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      context.appColors.primary,
                                      context.appColors.primaryDark,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                  ),
                                  child: CustomAvatar(
                                    name: spark.authorName,
                                    imageUrl: spark.authorAvatar,
                                    userId: spark.authorId,
                                    radius: 17,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Name + time
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(spark.authorName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Text(_timeAgo(spark.createdAt),
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.5),
                                            fontSize: 12)),
                                  ],
                                ),
                              ),

                              // Paused pill
                              if (_paused &&
                                  !_isDeleting &&
                                  !_showReplyField)
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

                              // Delete button (own sparks)
                              if (isOwn)
                                GestureDetector(
                                  onTap: _isDeleting ? null : _deleteSpark,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 6),
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
                                        : const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 17),
                                  ),
                                ),

                              // Close
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                      color: Colors.black38,
                                      shape: BoxShape.circle),
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

                  // ── 6. Caption ────────────────────────────────────────────
                  if (spark.caption != null && spark.caption!.isNotEmpty)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: isOwn ? (botPad + 100) : (botPad + 80),
                      child: Text(
                        spark.caption!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          shadows: [
                            Shadow(
                                color: Colors.black87,
                                blurRadius: 12,
                                offset: Offset(0, 2)),
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 24,
                                offset: Offset(0, 4)),
                          ],
                        ),
                      ),
                    ),

                  // ── 7. Bottom bar ─────────────────────────────────────────
                  if (!_showViewers && !_isDeleting)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: botPad + 12,
                      child: isOwn
                          ? _buildSeenByBar()
                          : _buildReplyBar(),
                    ),

                  // ── 8. Reply text field ───────────────────────────────────
                  if (_showReplyField)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: botPad + 12,
                      child: _buildReplyInput(),
                    ),

                  // ── 9. Viewers sheet ──────────────────────────────────────
                  if (_showViewers) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _closeViewers,
                        child: const ColoredBox(color: Colors.black54),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildViewersSheet(),
                    ),
                  ],

                  // ── 10. Deleting overlay ──────────────────────────────────
                  if (_isDeleting)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: Colors.redAccent, strokeWidth: 2.5),
                              SizedBox(height: 16),
                              Text('Deleting spark…',
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
            ),
          ),
        ),
      ),
    );
  }

  // ── Background ──────────────────────────────────────────────────────────────
  Widget _buildBackground(SparkItem spark) {
    if (spark.mediaUrl != null &&
        spark.mediaUrl!.isNotEmpty &&
        !spark.isVideo) {
      return Image.network(
        spark.mediaUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (_, child, progress) {
          if (progress == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _onMediaReady());
            return child;
          }
          return _gradientBg(context, spark);
        },
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _onMediaReady());
          return _gradientBg(context, spark);
        },
      );
    }

    if (spark.mediaUrl != null &&
        spark.mediaUrl!.isNotEmpty &&
        spark.isVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onMediaReady());
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle_fill_rounded,
                    size: 64, color: Colors.white60),
              ),
              const SizedBox(height: 14),
              Text('Video spark',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return _gradientBg(context, spark);
  }

  Widget _gradientBg(BuildContext context, SparkItem spark) {
    final colors = (spark.gradientColors != null &&
            spark.gradientColors!.length >= 2)
        ? [
            Color(spark.gradientColors![0]),
            Color(spark.gradientColors![1])
          ]
        : [context.appColors.primary, context.appColors.primaryDark];

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

  // ── Seen-by bar (own sparks) ───────────────────────────────────────────────
  Widget _buildSeenByBar() {
    return GestureDetector(
      onTap: _openViewers,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.remove_red_eye_outlined,
                color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            const Text('Seen by',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const Spacer(),
            Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white.withValues(alpha: 0.4), size: 22),
          ],
        ),
      ),
    );
  }

  // ── Reply bar (other users' sparks) ────────────────────────────────────────
  Widget _buildReplyBar() {
    return GestureDetector(
      onTap: _toggleReply,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Text('Send a message...',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14)),
            const Spacer(),
            Icon(Icons.favorite_border_rounded,
                color: Colors.white.withValues(alpha: 0.4), size: 22),
            const SizedBox(width: 12),
            Icon(Icons.send_rounded,
                color: Colors.white.withValues(alpha: 0.4), size: 20),
          ],
        ),
      ),
    );
  }

  // ── Reply input ─────────────────────────────────────────────────────────────
  Widget _buildReplyInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B2E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Reply to ${_current.authorName}...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => _sendReply(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendingReply ? null : _sendReply,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    context.appColors.primary,
                    context.appColors.primaryDark,
                  ],
                ),
              ),
              child: _sendingReply
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Viewers sheet ───────────────────────────────────────────────────────────
  Widget _buildViewersSheet() {
    return GestureDetector(
      onTap: () {}, // Prevent dismiss on sheet tap
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              Padding(
                padding: const EdgeInsets.all(32),
                child: CircularProgressIndicator(
                    color: context.appColors.primary, strokeWidth: 2),
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
                            color: Colors.white.withValues(alpha: 0.4),
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
                    final v = _viewers[i];
                    final avatar = v['avatar'] as String? ?? '';
                    final name = v['name'] as String;
                    return ListTile(
                      leading: CustomAvatar(
                        name: name,
                        imageUrl: avatar.isNotEmpty ? avatar : null,
                        userId: v['uid'],
                        radius: 20,
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      subtitle: Text(
                          '@${name.toLowerCase().replaceAll(' ', '')}',
                          style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.35),
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

// ═══════════════════════════════════════════════════════════════════════════════
//  PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════════════

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
        height: 3,
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
                      minHeight: 3,
                    ),
                  )
                : const ColoredBox(color: Colors.white30),
      ),
    );
  }
}
import 'dart:async';
import 'dart:math';
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

class SparkUserGroup {
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final List<SparkItem> sparks;

  const SparkUserGroup({
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.sparks,
  });
}

class SparkViewerArgs {
  final List<SparkUserGroup> groups;
  final int initialUserIndex;
  const SparkViewerArgs({required this.groups, required this.initialUserIndex});
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
  late int _currentUserIndex;
  late int _currentSparkIndex;

  SparkUserGroup get _currentGroup => widget.args.groups[_currentUserIndex];
  SparkItem get _currentSpark => _currentGroup.sparks[_currentSparkIndex];

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

  // ── Floating flares ──────────────────────────────────────────────────────
  final List<_FloatingFlare> _floatingFlares = [];

  // ── Reply ───────────────────────────────────────────────────────────────
  final _replyController = TextEditingController();
  bool _showReplyField = false;
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.args.initialUserIndex;
    _currentSparkIndex = 0;
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
    _mediaReady = _currentSpark.mediaUrl == null || _currentSpark.mediaUrl!.isEmpty;

    _progressCtrl = AnimationController(vsync: this, duration: _sparkDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _nextSpark();
      });

    _markViewed();
    if (_mediaReady) _progressCtrl!.forward();
    setState(() {});
  }

  void _markViewed() {
    if (_currentSpark.authorId == _myUid) return;
    FirebaseFirestore.instance
        .collection('stories')
        .doc(_currentSpark.sparkId)
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
    if (_currentSparkIndex < _currentGroup.sparks.length - 1) {
      setState(() {
        _currentSparkIndex++;
        _showViewers = false;
        _showReplyField = false;
      });
      _initSpark();
    } else {
      // Move to next user
      if (_currentUserIndex < widget.args.groups.length - 1) {
        setState(() {
          _currentUserIndex++;
          _currentSparkIndex = 0;
          _showViewers = false;
          _showReplyField = false;
        });
        _initSpark();
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  void _prevSpark() {
    if (_currentSparkIndex > 0) {
      setState(() {
        _currentSparkIndex--;
        _showViewers = false;
        _showReplyField = false;
      });
      _initSpark();
    } else {
      // Move to previous user
      if (_currentUserIndex > 0) {
        setState(() {
          _currentUserIndex--;
          _currentSparkIndex = widget.args.groups[_currentUserIndex].sparks.length - 1;
          _showViewers = false;
          _showReplyField = false;
        });
        _initSpark();
      } else {
        _progressCtrl?.reset();
        _progressCtrl?.forward();
      }
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

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete current spark', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'current'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              title: const Text('Delete all sparks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'all'),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.white54),
              title: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onTap: () => Navigator.pop(ctx, 'cancel'),
            ),
          ],
        ),
      ),
    );

    if (action == null || action == 'cancel') {
      _resume();
      return;
    }

    if (!mounted) return;
    setState(() => _isDeleting = true);

    try {
      if (action == 'current') {
        final sparkId = _currentSpark.sparkId;
        final mediaUrl = _currentSpark.mediaUrl;

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
          } catch (_) {}
        }

        if (!mounted) return;
        if (_currentGroup.sparks.length > 1) {
          _currentGroup.sparks.removeAt(_currentSparkIndex);
          if (_currentSparkIndex >= _currentGroup.sparks.length) {
            _currentSparkIndex = _currentGroup.sparks.length - 1;
          }
          setState(() => _isDeleting = false);
          _initSpark();
        } else {
          Navigator.of(context).pop();
        }
      } else if (action == 'all') {
        final batch = FirebaseFirestore.instance.batch();
        for (final spark in _currentGroup.sparks) {
          final ref = FirebaseFirestore.instance.collection('stories').doc(spark.sparkId);
          batch.delete(ref);
          if (spark.mediaUrl != null && spark.mediaUrl!.isNotEmpty) {
            try {
              final uri = Uri.parse(spark.mediaUrl!);
              final pathMatch = RegExp(r'/o/(.+?)(\?|$)').firstMatch(uri.path);
              if (pathMatch != null) {
                final storagePath = Uri.decodeComponent(pathMatch.group(1)!);
                await FirebaseStorage.instance.ref(storagePath).delete();
              }
            } catch (_) {}
          }
        }
        await batch.commit();
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _snack('Could not delete: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ── Viewers sheet ───────────────────────────────────────────────────────
  Future<void> _openViewers() async {
    if (_currentSpark.authorId != _myUid) return;
    _pause();
    setState(() {
      _showViewers = true;
      _viewersLoading = true;
      _viewers = [];
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('stories')
          .doc(_currentSpark.sparkId)
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
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(_currentSpark.sparkId)
          .collection('replies')
          .add({
        'senderId': _myUid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      String senderName = 'Someone';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_myUid)
            .get();
        if (userDoc.exists) {
          senderName = userDoc.data()?['name'] ?? 'Someone';
        }
      } catch (_) {}

      NotificationService.sendNotification(
        recipientId: _currentSpark.authorId,
        type: 'spark_reply',
        title: '$senderName replied to your spark',
        subtitle: text,
        relatedId: _currentSpark.sparkId,
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

  Future<void> _showFlareEffect() async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    // Spawn 3 flares with random horizontal scatter for a fire-burst feel
    final rng = Random();
    for (int i = 0; i < 3; i++) {
      setState(() {
        _floatingFlares.add(_FloatingFlare(
          x: width - 80 + (rng.nextDouble() * 60 - 30),
          y: height - 120 - (rng.nextDouble() * 20),
        ));
      });
    }

    if (_currentSpark.authorId != _myUid) {
      String senderName = 'Someone';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_myUid)
            .get();
        if (userDoc.exists) {
          senderName = userDoc.data()?['name'] ?? 'Someone';
        }
      } catch (_) {}

      NotificationService.sendNotification(
        recipientId: _currentSpark.authorId,
        type: 'spark_like',
        title: '$senderName flared your spark',
        subtitle: '🔥',
        relatedId: _currentSpark.sparkId,
      );
    }
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final spark = _currentSpark;
    final isOwn = spark.authorId == _myUid;
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    final dismissProgress = (_dragOffset / (size.height * 0.4)).clamp(0.0, 1.0);
    final scale = 1.0 - (dismissProgress * 0.15);
    final radius = dismissProgress * 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
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
        onHorizontalDragEnd: (details) {
          if (_showViewers || _isDeleting || _showReplyField) return;
          final velocity = details.primaryVelocity ?? 0.0;
          if (velocity < -300) {
            // Swipe Left -> Next User Group
            if (_currentUserIndex < widget.args.groups.length - 1) {
              setState(() {
                _currentUserIndex++;
                _currentSparkIndex = 0;
                _showViewers = false;
                _showReplyField = false;
              });
              _initSpark();
            } else {
              Navigator.of(context).pop();
            }
          } else if (velocity > 300) {
            // Swipe Right -> Prev User Group
            if (_currentUserIndex > 0) {
              setState(() {
                _currentUserIndex--;
                _currentSparkIndex = 0;
                _showViewers = false;
                _showReplyField = false;
              });
              _initSpark();
            }
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
                  _buildBackground(spark),
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
                  Positioned(
                    top: topPad + 8,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: List.generate(
                                _currentGroup.sparks.length, (i) {
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      right:
                                          i < _currentGroup.sparks.length - 1
                                              ? 3
                                              : 0),
                                  child: _ProgressBar(
                                    filled: i < _currentSparkIndex,
                                    active: i == _currentSparkIndex,
                                    controller: i == _currentSparkIndex
                                        ? _progressCtrl
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'spark_avatar_${spark.authorId}',
                                child: Container(
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
                              ),
                              const SizedBox(width: 10),
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
                  if (!_showViewers && !_isDeleting)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: botPad + 12,
                      child: isOwn
                          ? _buildSeenByBar()
                          : _buildReplyBar(),
                    ),
                  if (_showReplyField)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: botPad + 12,
                      child: _buildReplyInput(),
                    ),
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
                  ..._floatingFlares.map((flare) {
                    return _AnimatedFlare(
                      initialX: flare.x,
                      initialY: flare.y,
                      onFinished: () {
                        setState(() {
                          _floatingFlares.remove(flare);
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildReplyBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _toggleReply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text('Send message...',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFlareEffect,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B35), size: 22),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Spark link copied!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

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
                hintText: 'Reply to ${_currentSpark.authorName}...',
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

  Widget _buildViewersSheet() {
    return GestureDetector(
      onTap: () {},
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

// ═══════════════════════════════════════════════════════════════════════════════
//  FLOATING FLARE
// ═══════════════════════════════════════════════════════════════════════════════

class _FloatingFlare {
  final double x;
  final double y;
  _FloatingFlare({required this.x, required this.y});
}

class _AnimatedFlare extends StatefulWidget {
  final double initialX;
  final double initialY;
  final VoidCallback onFinished;

  const _AnimatedFlare({
    required this.initialX,
    required this.initialY,
    required this.onFinished,
  });

  @override
  State<_AnimatedFlare> createState() => _AnimatedFlareState();
}

class _AnimatedFlareState extends State<_AnimatedFlare>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim;
  late Animation<double> _xAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _rotationAnim;
  late final double _xDrift;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _xDrift = (rng.nextDouble() * 50 - 25); // random horizontal drift

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onFinished();
        }
      });

    _yAnim = Tween<double>(
      begin: widget.initialY,
      end: widget.initialY - 240,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _xAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: widget.initialX,
          end: widget.initialX + _xDrift,
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: widget.initialX + _xDrift,
          end: widget.initialX - _xDrift * 0.5,
        ),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.6),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.6, end: 0.8),
        weight: 75,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Subtle rotation wobble (fire flickers)
    _rotationAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.15),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.15, end: -0.15),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.0),
        weight: 25,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _xAnim.value,
          top: _yAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Transform.rotate(
              angle: _rotationAnim.value,
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: const Text('🔥', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
        );
      },
    );
  }
}

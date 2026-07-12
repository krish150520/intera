import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/routes/app_routes.dart';

class AudioPageScreen extends StatefulWidget {
  final String audioId;
  final String? audioTitle;
  final String? audioAuthorId;

  const AudioPageScreen({
    super.key,
    required this.audioId,
    this.audioTitle,
    this.audioAuthorId,
  });

  @override
  State<AudioPageScreen> createState() => _AudioPageScreenState();
}

class _AudioPageScreenState extends State<AudioPageScreen> {
  late final Stream<QuerySnapshot> _echosStream;
  String _audioTitle = '';
  String _authorUsername = '';
  int _echoCount = 0;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _audioTitle = widget.audioTitle ?? 'Loading audio details...';

    // Stream posts using this specific audioId
    _echosStream = FirebaseFirestore.instance
        .collection('posts')
        .where('audioId', isEqualTo: widget.audioId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    _fetchAudioDetails();
  }

  Future<void> _fetchAudioDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('audios')
          .doc(widget.audioId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _audioTitle = data['title'] ?? _audioTitle;
          _authorUsername = data['authorUsername'] ?? '';
          _echoCount = data['echoCount'] ?? 0;
          _coverUrl = data['coverUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching audio details: $e');
    }
  }

  void _useThisAudio() {
    Navigator.of(context).pushNamed(
      AppRoutes.createPost, // We will map `/create-post` arguments or create-echo route
      arguments: {
        'audioId': widget.audioId,
        'audioTitle': _audioTitle,
        'audioAuthorId': widget.audioAuthorId,
        'postType': 'video',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textHi, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Audio Track',
          style: TextStyle(
            color: c.textHi,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _echosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }

          final docs = snapshot.data?.docs ?? [];
          final posts = docs.map((doc) => Post.fromFirestore(doc, myUid)).toList();

          if (posts.isNotEmpty && _echoCount != posts.length) {
            // Keep local count in sync if mismatch
            _echoCount = posts.length;
          }

          return CustomScrollView(
            slivers: [
              // Header Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.border.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Glassmorphic / Gradient Disk
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: _coverUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_coverUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                gradient: _coverUrl == null
                                    ? LinearGradient(
                                        colors: [c.primary, const Color(0xFF8870EE)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                              ),
                              child: _coverUrl == null
                                  ? const Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _audioTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.textHi,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (_authorUsername.isNotEmpty)
                                    Text(
                                      'Created by $_authorUsername',
                                      style: TextStyle(
                                        color: c.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_echoCount echos',
                                    style: TextStyle(
                                      color: c.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // CTA Action Button
                        GestureDetector(
                          onTap: _useThisAudio,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: c.primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.video_call_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Use This Audio',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Title Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Trending Echos',
                    style: TextStyle(
                      color: c.textHi,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Grid Content
              if (posts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No Echos created with this audio yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = posts[index];
                        final thumbnail = post.videoThumbnailUrl;
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.echoViewer,
                              arguments: {
                                'posts': posts,
                                'initialIndex': index,
                              },
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: c.field,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (thumbnail != null && thumbnail.isNotEmpty)
                                    Image.network(thumbnail, fit: BoxFit.cover)
                                  else
                                    Container(
                                      color: Colors.grey[900],
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.play_circle_outline, color: Colors.white70, size: 32),
                                    ),
                                  // Overlay likes
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.favorite_rounded, color: Colors.white, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${post.likeCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(blurRadius: 4, color: Colors.black54),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: posts.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3 / 4,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

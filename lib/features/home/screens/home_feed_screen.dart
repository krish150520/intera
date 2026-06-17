import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/models/post_model.dart';
import '../widgets/post_card.dart';

/// Screen 5: Home Feed Screen
/// Displays real-time live database updates for stories, tasks, questions,
/// and common social feed posts.
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF5F3FF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _muted   = Color(0xFFEDE9FF);
  static const Color _border  = Color(0xFFE9E4FF);
  static const Color _primary = Color(0xFF7C3AED);
  static const Color _textHi  = Color(0xFF2D1B69);
  static const Color _textDim = Color(0xFFA89FCC);

  // Temporary mock data mapping for stories space.
  // TODO: Convert this collection space to a dedicated 'stories' StreamBuilder collection later
  final List<Map<String, dynamic>> _mockStories = [
    {'name': 'My Story', 'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Me',    'isMe': true,  'hasUnread': false},
    {'name': 'Alex M.',  'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',  'isMe': false, 'hasUnread': true},
    {'name': 'Sarah J.', 'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah', 'isMe': false, 'hasUnread': true},
    {'name': 'David K.', 'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=David', 'isMe': false, 'hasUnread': false},
  ];

  /// Updates post metrics (like count and user dynamic arrays) live in Cloud Firestore
  void _handleLikeEngine(String postId, List likedByArray) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (likedByArray.contains(uid)) {
      await docRef.update({
        'likeCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await docRef.update({
        'likeCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  /// Toggles saving a reference pointer collection directly on the document node
  void _handleSaveEngine(String postId, List savedByArray) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (savedByArray.contains(uid)) {
      await docRef.update({'savedBy': FieldValue.arrayRemove([uid])});
    } else {
      await docRef.update({'savedBy': FieldValue.arrayUnion([uid])});
    }
  }

  void _openPostDetail(Post post) {
    Navigator.of(context).pushNamed(AppRoutes.postDetail, arguments: post);
  }

  void _onStoryTap(int index) {
    if (_mockStories[index]['isMe']) {
      // FIXED: Safely maps navigation straight to your new story editor workspace view
      Navigator.of(context).pushNamed(AppRoutes.createStory);
    } else {
      setState(() {
        _mockStories[index]['hasUnread'] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: _textDim, size: 36),
                  const SizedBox(height: 10),
                  const Text('Could not load feed',
                      style: TextStyle(color: _textHi, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${snapshot.error}',
                      style: const TextStyle(color: _textDim, fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // ── Layout: left rail (stories) + scrollable feed (posts) ─────────
          return RefreshIndicator(
            color: _primary,
            backgroundColor: _surface,
            onRefresh: () async {
              // StreamBuilder refreshes natively on updates, slight structural anchor delay
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left side rail: stories ──────────────────────────────
                _buildSideRail(),

                // ── Right: scrollable post feed ──────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 12, 12, 100),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final docSnapshot = docs[index];
                      final data = docSnapshot.data() as Map<String, dynamic>? ?? {};
                      final docId = docSnapshot.id;
                      final List likedBy = data['likedBy'] ?? [];
                      final List savedBy = data['savedBy'] ?? [];
                      final postItem = Post.fromFirestore(docSnapshot, currentUid);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PostCard(
                          post: postItem,
                          onTap: () => _openPostDetail(postItem),
                          onLike: () => _handleLikeEngine(docId, likedBy),
                          onSave: () => _handleSaveEngine(docId, savedBy),
                          onComment: () => _openPostDetail(postItem),
                          onShare: () {
                            // TODO: Implement native sharing operations system link sheets
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
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
        Container(
          margin: const EdgeInsets.only(right: 16),
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: _muted, shape: BoxShape.circle),
          child: const Icon(Icons.notifications_outlined, color: _primary, size: 20),
        ),
      ],
    );
  }

  // ── Left side rail ─────────────────────────────────────────────────────────
  Widget _buildSideRail() {
    return Container(
      width: 64,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(right: BorderSide(color: _border, width: 1)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _mockStories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final story     = _mockStories[index];
          final bool isMe      = story['isMe']      ?? false;
          final bool hasUnread = story['hasUnread'] ?? false;

          return GestureDetector(
            onTap: () => _onStoryTap(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Unread ring
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasUnread ? _primary : _border,
                          width: hasUnread ? 2 : 1.5,
                        ),
                      ),
                    ),
                    // Avatar
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: _muted,
                      backgroundImage: story['avatar'] != null
                          ? NetworkImage(story['avatar'])
                          : null,
                      child: story['avatar'] == null
                          ? Text(
                              (story['name'] as String)[0],
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    ),
                    // "Add" badge for own story
                    if (isMe)
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
                const SizedBox(height: 5),
                // Name label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    (story['name'] as String).split(' ')[0],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: hasUnread ? _textHi : _textDim,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
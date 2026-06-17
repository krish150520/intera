import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../widgets/post_card.dart';

/// Screen 6: Post Detail Screen
/// Shows the full post alongside real-time live comments streaming from Firebase.
class PostDetailScreen extends StatefulWidget {
  final Post? post;

  const PostDetailScreen({super.key, this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSending = false; // Prevents spamming duplicate comments during cloud writes

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Commits a comment item into a subcollection space under the post item node
  void _submitComment() async {
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final post = widget.post;

    if (text.isEmpty || post == null) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to participate in the discussion.')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // FIXED: Fetch the active sender's profile document from Firestore to extract the true custom username
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final String verifiedUsername = userData != null && userData['username'] != null
          ? userData['username']
          : (user.email != null ? '@${user.email!.split("@")[0]}' : '@user');

      final String verifiedDisplayName = userData != null && userData['name'] != null
          ? userData['name']
          : (user.displayName ?? 'Anonymous');

      final postDocRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
      final commentSubcollectionRef = postDocRef.collection('comments');

      // Use a Firestore Batch write to ensure both operations complete atomically
      final batch = FirebaseFirestore.instance.batch();

      // Create a reference for a new comment document
      final newCommentRef = commentSubcollectionRef.doc();

      final Map<String, dynamic> commentPayload = {
        'authorName': verifiedDisplayName,
        'authorUsername': verifiedUsername.startsWith('@') ? verifiedUsername : '@$verifiedUsername', // ◄── FIXED: Eliminates raw email slice handles
        'authorAvatar': user.photoURL ?? '', 
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Stage the new comment entry
      batch.set(newCommentRef, commentPayload);

      // 2. Stage the comment count increment on the core parent post document
      batch.update(postDocRef, {
        'commentCount': FieldValue.increment(1),
      });

      // Commit operations simultaneously
      await batch.commit();

      _commentController.clear();
      FocusScope.of(context).unfocus(); // Automatically drops keyboard layout out of view safely
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish comment: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Discussion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: post == null
          ? const Center(child: Text('Post context missing.'))
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(post.id)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Failed to load comment streams: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                        );
                      }

                      final commentDocs = snapshot.data?.docs ?? [];

                      return CustomScrollView(
                        slivers: [
                          // 1. Core Post Card Node
                          SliverToBoxAdapter(
                            child: PostCard(post: post),
                          ),
                          
                          // 2. Header Section Label
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                              child: Text(
                                'Comments (${commentDocs.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),

                          // 3. Fallback View State (If no comments exist yet)
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const SliverToBoxAdapter(
                              child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
                            )
                          else if (commentDocs.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
                                child: Center(
                                  child: Text(
                                    'No responses yet. Start the conversation below!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                  ),
                                ),
                              ),
                            )
                          else
                            // 4. Live Render Comment List Stream Items Builder
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final data = commentDocs[index].data() as Map<String, dynamic>;
                                  
                                  final commentItem = _Comment(
                                    authorName: data['authorName'] ?? 'Anonymous',
                                    authorUsername: data['authorUsername'] ?? '@user',
                                    content: data['content'] ?? '',
                                    authorAvatar: data['authorAvatar'] ?? '',
                                  );

                                  return Column(
                                    children: [
                                      _CommentTile(comment: commentItem),
                                      if (index < commentDocs.length - 1)
                                        Divider(color: Colors.grey.shade100, height: 1, indent: 16, endIndent: 16),
                                    ],
                                  );
                                },
                                childCount: commentDocs.length,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                
                // Comment text entry workspace bar container
                _CommentInput(
                  controller: _commentController,
                  isSending: _isSending,
                  userAvatarUrl: currentUser?.photoURL,
                  onSend: _submitComment,
                ),
              ],
            ),
    );
  }
}

// --- PRIVATELY SCOPED MODEL ---

class _Comment {
  final String authorName;
  final String authorUsername;
  final String content;
  final String authorAvatar;

  const _Comment({
    required this.authorName,
    required this.authorUsername,
    required this.content,
    required this.authorAvatar,
  });
}

// --- COMPONENT UI TILES ---

class _CommentTile extends StatelessWidget {
  final _Comment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomAvatar(
            name: comment.authorName, 
            radius: 16,
            imageUrl: comment.authorAvatar.isNotEmpty ? comment.authorAvatar : null, 
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      comment.authorUsername,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content, 
                  style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    // Handled downstream via comment tags
                  },
                  child: const Text(
                    'Reply',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final String? userAvatarUrl;
  final VoidCallback onSend;

  const _CommentInput({
    required this.controller, 
    required this.isSending,
    this.userAvatarUrl,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), offset: const Offset(0, -3), blurRadius: 4),
        ],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          CustomAvatar(
            name: 'You', 
            radius: 16,
            imageUrl: userAvatarUrl, 
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                maxLines: null, 
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Add to the discussion...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          isSending
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                  onPressed: onSend,
                ),
        ],
      ),
    );
  }
}
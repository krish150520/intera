import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/follow_service.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../messaging/services/messaging_service.dart';
import '../../messaging/screens/chat_screen.dart';
import 'connections_list_screen.dart'; // ◄── IMPORT THE PUBLIC CONNECTIONS SCREEN

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userAvatar;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _messagingService = MessagingService();
  bool _isOpeningChat = false;

  /// Opens (or creates) the conversation with this profile's user and
  /// navigates to ChatScreen. If the recipient doesn't follow me back yet,
  /// this still proceeds - it just opens as a message request, and
  /// ChatScreen shows the appropriate banner / "request sent" state.
  Future<void> _onMessageTap(String currentUid) async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);

    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final myData = myDoc.data() ?? {};
      final myName = myData['name'] ?? 'User';
      final myAvatar = myData['avatarUrl'] ?? '';

      final result = await _messagingService.getOrCreateConversation(
        otherUid: widget.userId,
        myName: myName,
        myAvatar: myAvatar,
        otherName: widget.userName,
        otherAvatar: widget.userAvatar,
      );

      if (!mounted) return;

      if (result.access == ConversationAccess.pending) {
        // Let the sender know up front this will go out as a request,
        // rather than surprising them inside the chat screen.
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send message request?'),
            content: Text(
              '${widget.userName} doesn\'t follow you yet, so this will '
              'be sent as a message request. They\'ll see it once they '
              'accept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Send Request'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isOpeningChat = false);
          return;
        }
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: result.conversationId,
            otherUid: widget.userId,
            otherName: widget.userName,
            otherAvatar: widget.userAvatar,
            initialAccess: result.access,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = currentUid == widget.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(child: Text('Error loading profile: ${userSnapshot.error}'));
          }
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final followersCount = userData['followersCount'] ?? 0;
          final followingCount = userData['followingCount'] ?? 0;
          final karmaPoints = userData['karmaPoints'] ?? 0;
          final bio = userData['bio'] ?? 'Hey there! I am excited to join the INTERA community. 🚀';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Header Card Info
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: widget.userAvatar.isNotEmpty ? NetworkImage(widget.userAvatar) : null,
                              child: widget.userAvatar.isEmpty
                                  ? Text(widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                                      style: TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            // Message icon button, anchored to the avatar -
                            // only shown on other people's profiles.
                            if (!isMe)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: GestureDetector(
                                  onTap: _isOpeningChat
                                      ? null
                                      : () => _onMessageTap(currentUid),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: _isOpeningChat
                                        ? const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Expanded(child: SizedBox()),
                        
                        // Statistics Row
                        _buildStatColumn('Posts', FirebaseFirestore.instance.collection('posts').where('authorId', isEqualTo: widget.userId).snapshots().map((s) => s.docs.length)),
                        
                        // FIXED: Wrapped Followers column in an interactive detector routing to the public screen layout
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ConnectionsListScreen(
                                userId: widget.userId, 
                                isFollowersMode: true, 
                                profileOwnerName: widget.userName,
                              ),
                            ),
                          ),
                          child: _buildStaticStatColumn('Followers', followersCount),
                        ),
                        
                        // FIXED: Wrapped Following column in an interactive detector routing to the public screen layout
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ConnectionsListScreen(
                                userId: widget.userId, 
                                isFollowersMode: false, 
                                profileOwnerName: widget.userName,
                              ),
                            ),
                          ),
                          child: _buildStaticStatColumn('Following', followingCount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 2),
                        Text('$karmaPoints Karma', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(bio, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                    const SizedBox(height: 16),
                    
                    if (!isMe)
                      StreamBuilder<bool>(
                        stream: FollowService().isFollowingStream(currentUserId: currentUid, targetUserId: widget.userId),
                        builder: (context, followSnapshot) {
                          final isFollowing = followSnapshot.data ?? false;
                          return SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isFollowing ? Colors.white : AppColors.primary,
                                foregroundColor: isFollowing ? Colors.black : Colors.white,
                                side: BorderSide(color: isFollowing ? Colors.grey.shade300 : AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                try {
                                  await FollowService().toggleFollowUser(
                                    currentUserId: currentUid,
                                    targetUserId: widget.userId,
                                    isCurrentlyFollowing: isFollowing,
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Action failed: $e')),
                                  );
                                }
                              },
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onPressed: () {
                            // Edit profile routing hook path
                          },
                          child: const Text('Edit Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),

              // 2. User's Personal Shared Posts Stream
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('authorId', isEqualTo: widget.userId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.hasError) {
                      return Center(child: Text('Error loading posts: ${postSnapshot.error}'));
                    }
                    if (postSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final postsDocs = postSnapshot.data?.docs ?? [];

                    if (postsDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('No posts shared yet.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: postsDocs.length,
                      itemBuilder: (context, index) {
                        final doc = postsDocs[index];
                        final postItem = Post.fromFirestore(doc, currentUid);

                        return PostCard(
                          post: postItem,
                          onTap: () {},
                          onLike: () {
                            final docRef = FirebaseFirestore.instance.collection('posts').doc(doc.id);
                            if (postItem.isLiked) {
                              docRef.update({
                                'likeCount': FieldValue.increment(-1),
                                'likedBy': FieldValue.arrayRemove([currentUid])
                              });
                            } else {
                              docRef.update({
                                'likeCount': FieldValue.increment(1),
                                'likedBy': FieldValue.arrayUnion([currentUid])
                              });
                            }
                          },
                          onComment: () {},
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStaticStatColumn(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, Stream<int> countStream) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return _buildStaticStatColumn(label, count);
      },
    );
  }
}
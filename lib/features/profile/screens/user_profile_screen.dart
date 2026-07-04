import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/follow_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../messaging/services/messaging_service.dart';
import '../../messaging/screens/chat_screen.dart';
import 'connections_list_screen.dart';
import '../../../core/routes/app_routes.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.userName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _ThemeResolver.textHi(context),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: context.colors.surface,
        foregroundColor: _ThemeResolver.textHi(context),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(
              child: Text('Error loading profile: ${userSnapshot.error}'),
            );
          }
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            );
          }

          final userData =
              userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final followersCount = userData['followersCount'] ?? 0;
          final followingCount = userData['followingCount'] ?? 0;
          final karmaPoints = userData['karmaPoints'] ?? 0;
          final bio =
              userData['bio'] ??
              'Hey there! I am excited to join the INTERA community. 🚀';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
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
                              backgroundColor: context.colors.primary
                                  .withOpacity(0.1),
                              backgroundImage: widget.userAvatar.isNotEmpty
                                  ? NetworkImage(widget.userAvatar)
                                  : null,
                              child: widget.userAvatar.isEmpty
                                  ? Text(
                                      widget.userName.isNotEmpty
                                          ? widget.userName[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        color: context.colors.primary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
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
                                      color: context.colors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: context.colors.surface,
                                        width: 2,
                                      ),
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
                        _buildStatColumn(
                          context,
                          'Posts',
                          FirebaseFirestore.instance
                              .collection('posts')
                              .where('authorId', isEqualTo: widget.userId)
                              .snapshots()
                              .map((s) => s.docs.length),
                        ),
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
                          child: _buildStaticStatColumn(
                            context,
                            'Followers',
                            followersCount,
                          ),
                        ),
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
                          child: _buildStaticStatColumn(
                            context,
                            'Following',
                            followingCount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.userName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _ThemeResolver.textHi(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: AppColors.warningKarma,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$karmaPoints Karma',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.warningKarma,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _ThemeResolver.textBody(context),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isMe)
                      StreamBuilder<bool>(
                        stream: FollowService().isFollowingStream(
                          currentUserId: currentUid,
                          targetUserId: widget.userId,
                        ),
                        builder: (context, followSnapshot) {
                          final isFollowing = followSnapshot.data ?? false;
                          return SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? context.colors.surface
                                    : context.colors.primary,
                                foregroundColor: isFollowing
                                    ? _ThemeResolver.textHi(context)
                                    : Colors.white,
                                side: BorderSide(
                                  color: isFollowing
                                      ? context.colors.outline
                                      : context.colors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                                    SnackBar(
                                      content: Text('Action failed: $e'),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: context.colors.outline),
                          ),
                          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: _ThemeResolver.textHi(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('authorId', isEqualTo: widget.userId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading posts: ${postSnapshot.error}',
                        ),
                      );
                    }
                    if (postSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: context.colors.primary,
                        ),
                      );
                    }

                    final postsDocs = postSnapshot.data?.docs ?? [];

                    if (postsDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              size: 40,
                              color: _ThemeResolver.textDim(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No posts shared yet.',
                              style: TextStyle(
                                color: _ThemeResolver.textDim(context),
                              ),
                            ),
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
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.postDetail, arguments: postItem),
                          onLike: () {
                            final dataMap = doc.data() as Map<String, dynamic>?;
                            final List likedBy = dataMap?['likedBy'] ?? [];
                            NotificationService.toggleLike(
                              postId: doc.id,
                              postAuthorId: postItem.authorId,
                              postTitle: postItem.title,
                              currentUid: currentUid,
                              likedBy: likedBy,
                            );
                          },
                          onComment: () => Navigator.of(context)
                              .pushNamed(AppRoutes.postDetail, arguments: postItem),
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

  Widget _buildStaticStatColumn(BuildContext context, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _ThemeResolver.textHi(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: _ThemeResolver.textDim(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    Stream<int> countStream,
  ) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return _buildStaticStatColumn(context, label, count);
      },
    );
  }
}

class _ThemeResolver {
  const _ThemeResolver._();

  static Color textHi(BuildContext context) => context.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;

  static Color textBody(BuildContext context) => context.isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  static Color textDim(BuildContext context) =>
      context.isDarkMode ? AppColors.darkTextDim : AppColors.lightTextDim;
}

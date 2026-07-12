import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/post_model.dart';
import '../../shared/widgets/custom_avatar.dart';
import '../../features/messaging/services/messaging_service.dart';

class SharePostSheet extends StatefulWidget {
  final Post post;
  final String currentUid;

  const SharePostSheet({
    super.key,
    required this.post,
    required this.currentUid,
  });

  static Future<void> show(BuildContext context, Post post, String currentUid) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => SharePostSheet(post: post, currentUid: currentUid),
    );
  }

  @override
  State<SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends State<SharePostSheet> {
  List<Map<String, dynamic>> _mutuals = [];
  bool _isLoading = true;
  final Set<String> _sentUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadMutuals();
  }

  Future<void> _loadMutuals() async {
    try {
      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUid)
          .collection('following')
          .get();

      final followersSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUid)
          .collection('followers')
          .get();

      final followingIds = followingSnap.docs.map((d) => d.id).toSet();
      final followersIds = followersSnap.docs.map((d) => d.id).toSet();
      final mutualIds = followingIds.intersection(followersIds);

      if (mutualIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final List<Map<String, dynamic>> mutualUsers = [];
      final idList = mutualIds.toList();
      for (var i = 0; i < idList.length; i += 30) {
        final chunk = idList.sublist(i, (i + 30 > idList.length) ? idList.length : i + 30);
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in usersSnap.docs) {
          final data = doc.data();
          data['uid'] = doc.id;
          mutualUsers.add(data);
        }
      }

      if (mounted) {
        setState(() {
          _mutuals = mutualUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading mutuals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPostToUser(Map<String, dynamic> user) async {
    final otherUid = user['uid'] as String;
    if (_sentUserIds.contains(otherUid)) return;

    setState(() => _sentUserIds.add(otherUid));

    try {
      final messagingService = MessagingService();
      
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUid).get();
      final myData = myDoc.data() ?? {};
      final myName = myData['name'] as String? ?? 'User';
      final myAvatar = myData['profileImageUrl'] as String? ?? myData['photoURL'] as String? ?? '';
      
      final otherName = user['name'] as String? ?? 'User';
      final otherAvatar = user['profileImageUrl'] as String? ?? user['photoURL'] as String? ?? '';

      final convo = await messagingService.getOrCreateConversation(
        otherUid: otherUid,
        myName: myName,
        myAvatar: myAvatar,
        otherName: otherName,
        otherAvatar: otherAvatar,
      );

      await messagingService.sendSharedPostMessage(
        conversationId: convo.conversationId,
        otherUid: otherUid,
        postId: widget.post.id,
        postType: widget.post.type.name,
        postTitle: widget.post.title,
        postBody: widget.post.body,
        postImageUrl: widget.post.imageUrl,
        postVideoThumbnail: widget.post.videoThumbnailUrl,
        postAuthorUsername: widget.post.authorUsername,
      );

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .update({'shareCount': FieldValue.increment(1)});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post shared with $otherName!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending post: $e');
      if (mounted) {
        setState(() => _sentUserIds.remove(otherUid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(
        text: 'Check out this post on INTERA by ${widget.post.authorUsername}:\n\n${widget.post.title}\n${widget.post.body}'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Post link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.88),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.6),
                width: 0.8,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    decoration: BoxDecoration(
                      color: c.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Share Post',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textHi,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),

                const Divider(height: 1, color: Colors.transparent),

                // Followers list
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: c.primary),
                        )
                      : _mutuals.isEmpty
                          ? Center(
                              child: Text(
                                'No mutual connections to share with.',
                                style: TextStyle(color: c.textMuted, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _mutuals.length,
                              itemBuilder: (context, idx) {
                                final user = _mutuals[idx];
                                final name = user['name'] as String? ?? 'User';
                                final username = user['username'] as String? ?? '';
                                final avatar = user['profileImageUrl'] as String? ?? user['photoURL'] as String?;
                                final uid = user['uid'] as String;
                                final sent = _sentUserIds.contains(uid);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    leading: CustomAvatar(
                                      name: name,
                                      imageUrl: avatar,
                                      userId: uid,
                                      radius: 20,
                                    ),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        color: c.textHi,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '@$username',
                                      style: TextStyle(
                                        color: c.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    trailing: SizedBox(
                                      width: 80,
                                      height: 32,
                                      child: ElevatedButton(
                                        onPressed: sent ? null : () => _sendPostToUser(user),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: sent ? Colors.transparent : c.primary,
                                          foregroundColor: sent ? c.textMuted : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: sent ? BorderSide(color: c.border) : BorderSide.none,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          sent ? 'Sent' : 'Send',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                const Divider(height: 1),

                // External utilities
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Copy Link'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.textHi,
                            side: BorderSide(color: c.border, width: 0.8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

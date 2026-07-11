import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../services/community_chat_service.dart';
import '../widgets/community_chat_settings_sheet.dart';

class CommunityChatScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String? communityAvatar;

  const CommunityChatScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    this.communityAvatar,
  });

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  bool _isSending = false;
  bool _isUploadingImage = false;
  final Set<String> _animatedMessageIds = {};

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      final success = await CommunityChatService.sendTextMessage(
        communityId: widget.communityId,
        text: text,
      );
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You do not have permission to send messages in this chat.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isUploadingImage) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      final success = await CommunityChatService.sendImageMessage(
        communityId: widget.communityId,
        imageFile: File(pickedFile.path),
      );

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You do not have permission to send messages in this chat.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showSettings(CommunityChatMode currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommunityChatSettingsSheet(
        communityId: widget.communityId,
        currentMode: currentMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .snapshots(),
      builder: (context, communitySnapshot) {
        final communityData =
            communitySnapshot.data?.data() as Map<String, dynamic>? ?? {};

        final name = communityData['name'] ?? widget.communityName;
        final avatarUrl = communityData['avatarUrl'] ?? widget.communityAvatar ?? '';
        final admins = List.from(communityData['admins'] ?? []);
        final members = List.from(communityData['members'] ?? []);
        final isMember = members.contains(_currentUid);
        final isAdmin = admins.contains(_currentUid) ||
            communityData['creatorId'] == _currentUid;
        final chatMode = CommunityChatMode.fromString(
            communityData['chatMode'] as String?);

        final bool hasSendPermission = CommunityChatService.canSend(
          chatMode: chatMode,
          admins: admins,
          members: members,
          uid: _currentUid,
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.isDarkMode
                    ? [
                        const Color(0xFF1E213A),
                        const Color(0xFF121424),
                      ]
                    : [
                        const Color(0xFFF2F4FF),
                        Colors.white,
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ── Custom AppBar ──
                  _buildAppBar(context, name, avatarUrl, chatMode, isAdmin),

                  // ── Message Area ──
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: CommunityChatService.messagesStream(widget.communityId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.forum_outlined,
                                    size: 64, color: c.textMuted),
                                const SizedBox(height: 16),
                                Text(
                                  'Welcome to the Space Chat!',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: c.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Be the first to send a message.',
                                  style: TextStyle(
                                      fontSize: 12, color: c.textSecondary),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          itemCount: docs.length,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final msgId = doc.id;
                            final senderId = doc['senderId'] ?? '';
                            final senderName = doc['senderName'] ?? 'User';
                            final senderAvatar = doc['senderAvatar'] ?? '';
                            final text = doc['text'] as String?;
                            final imageUrl = doc['imageUrl'] as String?;
                            final type = doc['type'] ?? 'text';
                            final createdAt =
                                (doc['createdAt'] as Timestamp?)?.toDate() ??
                                    DateTime.now();

                            final isMe = senderId == _currentUid;
                            final animate = !_animatedMessageIds.contains(msgId);
                            if (animate) {
                              _animatedMessageIds.add(msgId);
                            }

                            if (type == 'system') {
                              return _buildSystemMessage(text ?? '');
                            }

                            return _CommunityMessageBubble(
                              senderName: senderName,
                              senderAvatar: senderAvatar,
                              text: text,
                              imageUrl: imageUrl,
                              isMe: isMe,
                              createdAt: createdAt,
                              animate: animate,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // ── Input Area ──
                  if (_isUploadingImage)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: c.surface,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Uploading image...',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                  _buildInputArea(context, hasSendPermission, isMember, chatMode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, String name, String avatarUrl,
      CommunityChatMode chatMode, bool isAdmin) {
    final c = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: c.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          CustomAvatar(
            name: name,
            imageUrl: avatarUrl,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      chatMode.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.settings_suggest_rounded,
                  color: c.primary, size: 24),
              onPressed: () => _showSettings(chatMode),
            ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String text) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: c.field.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: c.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, bool hasSendPermission,
      bool isMember, CommunityChatMode chatMode) {
    final c = context.appColors;

    if (!isMember) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: c.surface,
        child: Center(
          child: Text(
            'Join this space to participate in the chatroom.',
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (!hasSendPermission) {
      String prompt = '';
      if (chatMode == CommunityChatMode.announcement) {
        prompt = 'Only admins can send messages in Announcement mode.';
      } else if (chatMode == CommunityChatMode.membersOnly) {
        prompt = 'Only members can send messages.';
      }
      return Container(
        padding: const EdgeInsets.all(20),
        color: c.surface,
        child: Center(
          child: Text(
            prompt,
            style: TextStyle(
              fontSize: 13,
              color: c.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.image_outlined, color: c.primary, size: 24),
            onPressed: _pickAndSendImage,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.field,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.8),
              ),
              child: TextField(
                controller: _textController,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send_rounded, color: c.primary, size: 24),
            onPressed: _sendText,
          ),
        ],
      ),
    );
  }
}

class _CommunityMessageBubble extends StatefulWidget {
  final String senderName;
  final String senderAvatar;
  final String? text;
  final String? imageUrl;
  final bool isMe;
  final DateTime createdAt;
  final bool animate;

  const _CommunityMessageBubble({
    required this.senderName,
    required this.senderAvatar,
    this.text,
    this.imageUrl,
    required this.isMe,
    required this.createdAt,
    required this.animate,
  });

  @override
  State<_CommunityMessageBubble> createState() => _CommunityMessageBubbleState();
}

class _CommunityMessageBubbleState extends State<_CommunityMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isMe ? 0.08 : -0.08, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            mainAxisAlignment:
                widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isMe) ...[
                CustomAvatar(
                  name: widget.senderName,
                  imageUrl: widget.senderAvatar,
                  radius: 16,
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment:
                    widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!widget.isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        widget.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Column(
                      crossAxisAlignment: widget.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: radius,
                            child: Image.network(
                              widget.imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  width: 200,
                                  height: 200,
                                  color: c.field,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: c.primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stack) => Container(
                                width: 200,
                                height: 200,
                                color: c.field,
                                child: Icon(Icons.broken_image_outlined,
                                    color: c.textDim),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: widget.isMe ? c.primary : c.field,
                              borderRadius: radius,
                              border: widget.isMe
                                  ? null
                                  : Border.all(color: c.border.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: Text(
                              widget.text ?? '',
                              style: TextStyle(
                                color: widget.isMe ? Colors.white : c.textPrimary,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _formatTime(widget.createdAt),
                            style: TextStyle(fontSize: 9, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

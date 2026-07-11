import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../models/message_model.dart';
import '../services/messaging_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUid;
  final String otherName;
  final String? otherAvatar;
  final ConversationAccess initialAccess;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUid,
    required this.otherName,
    this.otherAvatar,
    this.initialAccess = ConversationAccess.active,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messagingService = MessagingService();
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _isResponding = false;
  final Set<String> _animatedMessageIds = {};

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _convoStream;

  @override
  void initState() {
    super.initState();
    _convoStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .snapshots();
    if (widget.initialAccess == ConversationAccess.active) {
      _messagingService.markConversationRead(widget.conversationId);
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _convoStream = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await _messagingService.sendTextMessage(
        conversationId: widget.conversationId,
        otherUid: widget.otherUid,
        text: text,
      );
      _messagingService.markConversationRead(widget.conversationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isUploadingImage) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);
      await _messagingService.sendImageMessage(
        conversationId: widget.conversationId,
        otherUid: widget.otherUid,
        imageFile: File(picked.path),
      );
      _messagingService.markConversationRead(widget.conversationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _accept() async {
    setState(() => _isResponding = true);
    try {
      await _messagingService.acceptMessageRequest(widget.conversationId);
      _messagingService.markConversationRead(widget.conversationId);
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _isResponding = true);
    try {
      await _messagingService.declineMessageRequest(widget.conversationId);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: widget.otherUid,
          userName: widget.otherName,
          userAvatar: widget.otherAvatar ?? '',
        ),
      ),
    );
  }

  Future<void> _showChatActions(String myUid) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatActionsSheet(
        otherName: widget.otherName,
        onViewProfile: () {
          Navigator.of(context).pop();
          _openProfile();
        },
        onDeleteForMe: () async {
          Navigator.of(context).pop();
          await _confirmDeleteForMe(myUid);
        },
        onDeleteForEveryone: () async {
          Navigator.of(context).pop();
          await _confirmDeleteForEveryone();
        },
      ),
    );
  }

  Future<void> _confirmDeleteForMe(String myUid) async {
    final confirmed = await _confirmDestructiveAction(
      title: 'Delete chat for you?',
      message:
          'This will remove the conversation from your inbox. It will still be visible for ${widget.otherName}.',
      actionLabel: 'Delete for me',
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'hiddenFor': FieldValue.arrayUnion([myUid]),
            'deletedFor': FieldValue.arrayUnion([myUid]),
          });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete chat: $e')));
      }
    }
  }

  Future<void> _confirmDeleteForEveryone() async {
    final confirmed = await _confirmDestructiveAction(
      title: 'Delete chat for everyone?',
      message:
          'This permanently deletes this conversation and all messages for both people. This cannot be undone.',
      actionLabel: 'Delete for everyone',
    );
    if (confirmed != true) return;

    try {
      await _deleteConversationPermanently(widget.conversationId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete chat: $e')));
      }
    }
  }

  Future<bool?> _confirmDestructiveAction({
    required String title,
    required String message,
    required String actionLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConversationPermanently(String conversationId) async {
    final firestore = FirebaseFirestore.instance;
    final conversationRef = firestore
        .collection('conversations')
        .doc(conversationId);
    final messagesRef = conversationRef.collection('messages');

    while (true) {
      final page = await messagesRef.limit(400).get();
      if (page.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await conversationRef.delete();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _convoStream,
          builder: (context, convoSnapshot) {
            if (convoSnapshot.hasData && !convoSnapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This conversation has been deleted.')),
                  );
                }
              });
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final convoData =
                convoSnapshot.data?.data() as Map<String, dynamic>?;
            final status = convoData?['status'] as String? ?? 'active';
            final requestedBy = convoData?['requestedBy'] as String?;
            final isPending = status == 'pending';
            final isMyRequest = isPending && requestedBy == myUid;
            final isIncomingRequest = isPending && requestedBy != myUid;

            return Column(
              children: [
                _ChatHeader(
                  name: widget.otherName,
                  avatar: widget.otherAvatar,
                  otherUid: widget.otherUid,
                  isPending: isPending,
                  isIncomingRequest: isIncomingRequest,
                  onActionsTap: () => _showChatActions(myUid),
                ),
                if (isPending)
                  _RequestBanner(
                    isMyRequest: isMyRequest,
                    otherName: widget.otherName,
                  ),
                Expanded(
                  child: _MessagesPanel(
                    messagingService: _messagingService,
                    conversationId: widget.conversationId,
                    myUid: myUid,
                    otherName: widget.otherName,
                    animatedMessageIds: _animatedMessageIds,
                  ),
                ),
                if (isIncomingRequest)
                  _AcceptDeclineBar(
                    isResponding: _isResponding,
                    onAccept: _accept,
                    onDecline: _decline,
                  )
                else
                  _Composer(
                    controller: _textController,
                    isSending: _isSending,
                    isUploadingImage: _isUploadingImage,
                    onAttachImage: _pickAndSendImage,
                    onSend: _sendText,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String name;
  final String? avatar;
  final String otherUid;
  final bool isPending;
  final bool isIncomingRequest;
  final VoidCallback onActionsTap;

  const _ChatHeader({
    required this.name,
    required this.avatar,
    required this.otherUid,
    required this.isPending,
    required this.isIncomingRequest,
    required this.onActionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border, width: 0.8)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary,
              size: 18,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CustomAvatar(
                name: name,
                imageUrl: avatar,
                userId: otherUid,
                radius: 20,
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isPending
                        ? c.primary
                        : AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                ),
              ),
            ],
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
                    color: c.textHi,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isIncomingRequest
                      ? 'Message request'
                      : isPending
                      ? 'Request pending'
                      : 'Direct message',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onActionsTap,
            icon: Icon(
              Icons.more_horiz_rounded,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatActionsSheet extends StatelessWidget {
  final String otherName;
  final VoidCallback onViewProfile;
  final VoidCallback onDeleteForMe;
  final VoidCallback onDeleteForEveryone;

  const _ChatActionsSheet({
    required this.otherName,
    required this.onViewProfile,
    required this.onDeleteForMe,
    required this.onDeleteForEveryone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  otherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textHi,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.person_outline_rounded,
              title: 'View profile',
              subtitle: 'Open this user profile',
              onTap: onViewProfile,
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Delete chat for me',
              subtitle: 'Hide this conversation only from your inbox',
              onTap: onDeleteForMe,
            ),
            _ActionTile(
              icon: Icons.delete_forever_rounded,
              title: 'Delete chat for everyone',
              subtitle: 'Permanently remove all messages for both people',
              isDestructive: true,
              onTap: onDeleteForEveryone,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = isDestructive ? AppColors.error : c.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive
                          ? AppColors.error
                          : c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: c.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestBanner extends StatelessWidget {
  final bool isMyRequest;
  final String otherName;

  const _RequestBanner({required this.isMyRequest, required this.otherName});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMyRequest
                  ? 'Message request sent. $otherName will see your chat once they accept.'
                  : '$otherName is not following you yet. Accept this request to continue the conversation.',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesPanel extends StatefulWidget {
  final MessagingService messagingService;
  final String conversationId;
  final String myUid;
  final String otherName;
  final Set<String> animatedMessageIds;

  const _MessagesPanel({
    required this.messagingService,
    required this.conversationId,
    required this.myUid,
    required this.otherName,
    required this.animatedMessageIds,
  });

  @override
  State<_MessagesPanel> createState() => _MessagesPanelState();
}

class _MessagesPanelState extends State<_MessagesPanel> {
  bool _initialized = false;
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = widget.messagingService.messagesStream(widget.conversationId);
  }

  @override
  void didUpdateWidget(covariant _MessagesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _messagesStream = widget.messagingService.messagesStream(widget.conversationId);
      _initialized = false;
    }
  }

  void _showMessageActions(BuildContext context, String messageId, MessageModel message, bool isMe) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (message.text != null && message.text!.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: c.primary),
                  title: Text('Copy text', style: TextStyle(color: c.textPrimary)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text!));
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard')),
                    );
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Delete for Everyone', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Delete message?'),
                        content: const Text('This will delete the message for everyone in this chat.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(widget.conversationId)
                          .collection('messages')
                          .doc(messageId)
                          .delete();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return StreamBuilder(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load messages',
              style: TextStyle(color: c.textMuted),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: c.primary,
              strokeWidth: 2,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyConversation(otherName: widget.otherName);
        }

        // Initialize the animatedMessageIds with existing messages on load
        if (!_initialized && docs.isNotEmpty) {
          _initialized = true;
          for (final doc in docs) {
            widget.animatedMessageIds.add(doc.id);
          }
        }

        return Container(
          color: c.bg,
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final message = MessageModel.fromFirestore(doc);
              final isMe = message.senderId == widget.myUid;
              
              final bool shouldAnimate = !widget.animatedMessageIds.contains(message.id);
              if (shouldAnimate) {
                widget.animatedMessageIds.add(message.id);
              }

              return Padding(
                key: ValueKey(message.id),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: GestureDetector(
                  onLongPress: () => _showMessageActions(context, doc.id, message, isMe),
                  child: MessageBubble(
                    message: message,
                    isMe: isMe,
                    animate: shouldAnimate,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  final String otherName;

  const _EmptyConversation({required this.otherName});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: c.primary, width: 0.8),
              ),
              child: Icon(
                Icons.waving_hand_rounded,
                color: c.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Say hello to $otherName',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textHi,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start with a quick note, a question, or share a photo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptDeclineBar extends StatelessWidget {
  final bool isResponding;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _AcceptDeclineBar({
    required this.isResponding,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isResponding ? null : onDecline,
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Decline'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textSecondary,
                side: BorderSide(color: c.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isResponding ? null : onAccept,
              icon: isResponding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 17),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isUploadingImage;
  final VoidCallback onAttachImage;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isSending,
    required this.isUploadingImage,
    required this.onAttachImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ComposerIconButton(
            onPressed: isUploadingImage ? null : onAttachImage,
            child: isUploadingImage
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: c.primary,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    Icons.add_photo_alternate_outlined,
                    color: c.textPrimary,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: c.field,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border, width: 0.8),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: TextStyle(color: c.textMuted),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _ComposerIconButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.field,
          shape: BoxShape.circle,
          border: Border.all(color: c.border, width: 0.8),
        ),
        child: Center(child: child),
      ),
    );
  }
}



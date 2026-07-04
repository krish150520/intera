import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.initialAccess == ConversationAccess.active) {
      _messagingService.markConversationRead(widget.conversationId);
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
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .snapshots(),
          builder: (context, convoSnapshot) {
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
  final bool isPending;
  final bool isIncomingRequest;
  final VoidCallback onActionsTap;

  const _ChatHeader({
    required this.name,
    required this.avatar,
    required this.isPending,
    required this.isIncomingRequest,
    required this.onActionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatar != null && avatar!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: _ChatColors.border(context))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.colors.primary,
              size: 18,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: context.colors.surfaceContainerHighest,
                backgroundImage: hasAvatar ? NetworkImage(avatar!) : null,
                child: !hasAvatar
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: isPending
                        ? AppColors.warningKarma
                        : AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.surface, width: 2),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _ChatColors.textHi(context),
                    fontSize: 16,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _ChatColors.textDim(context),
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
              color: _ChatColors.textDim(context),
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
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _ChatColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(context.isDarkMode ? 0.28 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _ChatColors.border(context),
                borderRadius: BorderRadius.circular(99),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _ChatColors.textHi(context),
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
    final color = isDestructive ? AppColors.error : context.colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(context.isDarkMode ? 0.18 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDestructive
                          ? AppColors.error
                          : _ChatColors.textHi(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _ChatColors.textDim(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _ChatColors.textDim(context),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ChatColors.warningBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ChatColors.warningBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.warningKarma,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMyRequest
                  ? 'Message request sent. $otherName will see your chat once they accept.'
                  : '$otherName is not following you yet. Accept this request to continue the conversation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _ChatColors.warningText(context),
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

class _MessagesPanel extends StatelessWidget {
  final MessagingService messagingService;
  final String conversationId;
  final String myUid;
  final String otherName;

  const _MessagesPanel({
    required this.messagingService,
    required this.conversationId,
    required this.myUid,
    required this.otherName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: messagingService.messagesStream(conversationId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load messages',
              style: TextStyle(color: _ChatColors.textDim(context)),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.primary,
              strokeWidth: 2,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyConversation(otherName: otherName);
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                context.colors.surfaceContainerHighest.withOpacity(0.6),
              ],
            ),
          ),
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final message = MessageModel.fromFirestore(docs[index]);
              final isMe = message.senderId == myUid;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: MessageBubble(message: message, isMe: isMe),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Say hello to $otherName',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _ChatColors.textHi(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start with a quick note, a question, or share a photo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _ChatColors.textDim(context),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDarkMode ? 0.20 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isResponding ? null : onDecline,
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Decline'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ChatColors.textDim(context),
                side: BorderSide(color: _ChatColors.border(context)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: _ChatColors.border(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDarkMode ? 0.20 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
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
                      color: context.colors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    Icons.add_photo_alternate_outlined,
                    color: context.colors.primary,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _ChatColors.border(context)),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _ChatColors.textHi(context),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: TextStyle(color: _ChatColors.textDim(context)),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withOpacity(0.24),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
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
                      size: 18,
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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: _ChatColors.border(context)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ChatColors {
  const _ChatColors._();

  static Color textHi(BuildContext context) => context.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;

  static Color textDim(BuildContext context) =>
      context.isDarkMode ? AppColors.darkTextDim : AppColors.lightTextDim;

  static Color border(BuildContext context) =>
      context.isDarkMode ? AppColors.darkDivider : AppColors.lightDivider;

  static Color warningBg(BuildContext context) => context.isDarkMode
      ? AppColors.warningKarma.withOpacity(0.16)
      : AppColors.warningKarmaBg;

  static Color warningBorder(BuildContext context) => context.isDarkMode
      ? AppColors.warningKarma.withOpacity(0.36)
      : AppColors.warningKarmaBorder;

  static Color warningText(BuildContext context) =>
      context.isDarkMode ? AppColors.darkTextSecondary : AppColors.warningKarma;
}

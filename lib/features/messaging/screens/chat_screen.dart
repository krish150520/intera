import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import '../services/messaging_service.dart';
import '../widgets/message_bubble.dart';

/// 1-on-1 chat thread. [conversationId] should already exist (created via
/// MessagingService.getOrCreateConversation before navigating here).
///
/// [initialAccess] is a hint from the caller (active vs pending) used only
/// to decide whether to skip marking the thread read on open - the
/// conversation document itself (streamed live) is the source of truth for
/// banner/accept-decline UI, since status can change while this screen is
/// open (e.g. I reply to a request and it flips to active).
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
  static const Color _bg      = Color(0xFFF5F3FF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _muted   = Color(0xFFEDE9FF);
  static const Color _border  = Color(0xFFE9E4FF);
  static const Color _primary = Color(0xFF7C3AED);
  static const Color _textHi  = Color(0xFF2D1B69);
  static const Color _textDim = Color(0xFFA89FCC);
  static const Color _warnBg  = Color(0xFFFFF4E5);
  static const Color _warnTxt = Color(0xFF92610C);

  final _messagingService = MessagingService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    // Only clear the unread badge if this isn't an incoming pending
    // request - opening a request preview shouldn't silently mark it read
    // before the user explicitly accepts or declines it.
    if (widget.initialAccess == ConversationAccess.active) {
      _messagingService.markConversationRead(widget.conversationId);
    }
  }

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
      await _messagingService.sendTextMessage(
        conversationId: widget.conversationId,
        otherUid: widget.otherUid,
        text: text,
      );
      _messagingService.markConversationRead(widget.conversationId);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _muted,
              backgroundImage: widget.otherAvatar != null
                  ? NetworkImage(widget.otherAvatar!)
                  : null,
              child: widget.otherAvatar == null
                  ? Text(
                      widget.otherName.isNotEmpty ? widget.otherName[0] : '?',
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherName,
              style: const TextStyle(
                color: _textHi,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      // The conversation doc itself is streamed so the request banner
      // updates live (e.g. flips away the instant the other side replies).
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .snapshots(),
        builder: (context, convoSnapshot) {
          final convoData = convoSnapshot.data?.data() as Map<String, dynamic>?;
          final status = convoData?['status'] as String? ?? 'active';
          final requestedBy = convoData?['requestedBy'] as String?;
          final isPending = status == 'pending';
          final isMyRequest = isPending && requestedBy == myUid;
          final isIncomingRequest = isPending && requestedBy != myUid;

          return Column(
            children: [
              if (isPending) _buildRequestBanner(isMyRequest, isIncomingRequest),
              Expanded(
                child: StreamBuilder(
                  stream:
                      _messagingService.messagesStream(widget.conversationId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Could not load messages',
                            style: TextStyle(color: _textDim)),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: _primary, strokeWidth: 2),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'Say hello to ${widget.otherName} 👋',
                          style: const TextStyle(color: _textDim, fontSize: 13),
                        ),
                      );
                    }

                    // messagesStream is newest-first; with a reversed
                    // ListView that anchors content to the bottom like a
                    // normal chat.
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final message = MessageModel.fromFirestore(docs[index]);
                        final isMe = message.senderId == myUid;
                        return MessageBubble(message: message, isMe: isMe);
                      },
                    );
                  },
                ),
              ),
              // Recipient of an unanswered request sees Accept/Decline
              // instead of a composer until they respond.
              if (isIncomingRequest)
                _buildAcceptDeclineBar()
              else
                _buildComposer(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestBanner(bool isMyRequest, bool isIncomingRequest) {
    return Container(
      width: double.infinity,
      color: _warnBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        isMyRequest
            ? 'Message request sent. ${widget.otherName} will see it once they accept.'
            : '${widget.otherName} isn\'t following you yet. Accepting will let them message you freely.',
        style: const TextStyle(color: _warnTxt, fontSize: 12.5, height: 1.3),
      ),
    );
  }

  Widget _buildAcceptDeclineBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isResponding ? null : _decline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textDim,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _isResponding ? null : _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isResponding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Accept'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border, width: 1)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _isUploadingImage ? null : _pickAndSendImage,
              icon: _isUploadingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: _primary, strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined, color: _primary),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _muted,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: _textHi, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: _textDim),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  onSubmitted: (_) => _sendText(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _isSending ? null : _sendText,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../services/messaging_service.dart';
import 'chat_screen.dart';

/// Tab / screen showing all 1-on-1 conversations the current user has.
///
/// Split into two tabs:
/// - "Chats": active threads, plus pending requests *I* sent (shown as
///   "Request sent" until the other person replies).
/// - "Requests": pending threads sent *to me* by people I don't follow
///   back yet - tapping one opens ChatScreen's Accept/Decline flow.
class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg      = Color(0xFFF5F3FF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _muted   = Color(0xFFEDE9FF);
  static const Color _border  = Color(0xFFE9E4FF);
  static const Color _primary = Color(0xFF7C3AED);
  static const Color _textHi  = Color(0xFF2D1B69);
  static const Color _textDim = Color(0xFFA89FCC);

  final _messagingService = MessagingService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  void _openChat(ConversationModel convo, String myUid) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: convo.id,
          otherUid: convo.otherUid(myUid),
          otherName: convo.otherName(myUid),
          otherAvatar: convo.otherAvatar(myUid),
          initialAccess: convo.isPending
              ? ConversationAccess.pending
              : ConversationAccess.active,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: _textHi,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primary,
          unselectedLabelColor: _textDim,
          indicatorColor: _primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatsTab(
            messagingService: _messagingService,
            myUid: myUid,
            relativeTime: _relativeTime,
            onOpenChat: _openChat,
          ),
          _RequestsTab(
            messagingService: _messagingService,
            myUid: myUid,
            relativeTime: _relativeTime,
            onOpenChat: _openChat,
          ),
        ],
      ),
    );
  }
}

/// "Chats" tab - active threads plus my own outgoing pending requests.
class _ChatsTab extends StatelessWidget {
  final MessagingService messagingService;
  final String myUid;
  final String Function(DateTime?) relativeTime;
  final void Function(ConversationModel, String) onOpenChat;

  static const Color _muted   = Color(0xFFEDE9FF);
  static const Color _border  = Color(0xFFE9E4FF);
  static const Color _primary = Color(0xFF7C3AED);
  static const Color _textHi  = Color(0xFF2D1B69);
  static const Color _textDim = Color(0xFFA89FCC);

  const _ChatsTab({
    required this.messagingService,
    required this.myUid,
    required this.relativeTime,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: messagingService.conversationsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not load conversations',
                style: TextStyle(color: _textDim)),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        // Exclude incoming requests (those live in the Requests tab) and
        // declined threads (hidden entirely).
        final docs = allDocs.where((doc) {
          final convo = ConversationModel.fromFirestore(doc);
          if (convo.status == 'declined') return false;
          if (convo.isPending && convo.requestedBy != myUid) return false;
          return true;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: _muted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      color: _primary, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No messages yet',
                  style: TextStyle(
                    color: _textHi,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Start a conversation from someone\'s profile',
                  style: TextStyle(color: _textDim, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 78, color: _border),
          itemBuilder: (context, index) {
            final convo = ConversationModel.fromFirestore(docs[index]);
            final otherName = convo.otherName(myUid);
            final otherAvatar = convo.otherAvatar(myUid);
            final unread = convo.unreadFor(myUid);
            final isUnread = unread > 0;
            final isMine = convo.lastSenderId == myUid;
            final isMyPendingRequest = convo.isPending;

            return InkWell(
              onTap: () => onOpenChat(convo, myUid),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: _muted,
                      backgroundImage:
                          otherAvatar != null ? NetworkImage(otherAvatar) : null,
                      child: otherAvatar == null
                          ? Text(
                              otherName.isNotEmpty ? otherName[0] : '?',
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textHi,
                              fontSize: 15,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isMyPendingRequest
                                ? 'Request sent'
                                : convo.lastMessage.isEmpty
                                    ? 'Say hello 👋'
                                    : isMine
                                        ? 'You: ${convo.lastMessage}'
                                        : convo.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMyPendingRequest
                                  ? _primary
                                  : isUnread
                                      ? _textHi
                                      : _textDim,
                              fontSize: 13,
                              fontStyle: isMyPendingRequest
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              fontWeight: isUnread && !isMyPendingRequest
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          relativeTime(convo.lastMessageAt),
                          style: const TextStyle(color: _textDim, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        if (isUnread && !isMyPendingRequest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                            constraints:
                                const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// "Requests" tab - incoming pending threads awaiting Accept/Decline.
class _RequestsTab extends StatelessWidget {
  final MessagingService messagingService;
  final String myUid;
  final String Function(DateTime?) relativeTime;
  final void Function(ConversationModel, String) onOpenChat;

  static const Color _muted   = Color(0xFFEDE9FF);
  static const Color _border  = Color(0xFFE9E4FF);
  static const Color _primary = Color(0xFF7C3AED);
  static const Color _textHi  = Color(0xFF2D1B69);
  static const Color _textDim = Color(0xFFA89FCC);

  const _RequestsTab({
    required this.messagingService,
    required this.myUid,
    required this.relativeTime,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: messagingService.pendingRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not load requests',
                style: TextStyle(color: _textDim)),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
          );
        }

        // pendingRequestsStream already filters to status == 'pending' for
        // threads I'm part of; drop the ones I myself sent (those surface
        // in the Chats tab as "Request sent" instead).
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final convo = ConversationModel.fromFirestore(doc);
          return convo.requestedBy != myUid;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: _muted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inbox_outlined,
                      color: _primary, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No message requests',
                  style: TextStyle(
                    color: _textHi,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Requests from people you don\'t follow back\nwill show up here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textDim, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 78, color: _border),
          itemBuilder: (context, index) {
            final convo = ConversationModel.fromFirestore(docs[index]);
            final otherName = convo.otherName(myUid);
            final otherAvatar = convo.otherAvatar(myUid);

            return InkWell(
              onTap: () => onOpenChat(convo, myUid),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: _muted,
                      backgroundImage:
                          otherAvatar != null ? NetworkImage(otherAvatar) : null,
                      child: otherAvatar == null
                          ? Text(
                              otherName.isNotEmpty ? otherName[0] : '?',
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textHi,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            convo.lastMessage.isEmpty
                                ? 'Wants to message you'
                                : convo.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDim,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      relativeTime(convo.lastMessageAt),
                      style: const TextStyle(color: _textDim, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
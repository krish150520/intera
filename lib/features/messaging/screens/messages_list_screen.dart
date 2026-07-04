import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/message_model.dart';
import '../services/messaging_service.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen>
    with SingleTickerProviderStateMixin {
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 20,
        title: Text(
          'Messages',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: _ThemeResolver.textHi(context),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.colors.primary,
          unselectedLabelColor: _ThemeResolver.textDim(context),
          indicatorColor: context.colors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
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

class _ChatsTab extends StatelessWidget {
  final MessagingService messagingService;
  final String myUid;
  final String Function(DateTime?) relativeTime;
  final void Function(ConversationModel, String) onOpenChat;

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
          return _CenteredMessage(text: 'Could not load conversations');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.primary,
              strokeWidth: 2,
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hiddenFor = List<String>.from(data['hiddenFor'] ?? const []);
          final deletedFor = List<String>.from(data['deletedFor'] ?? const []);
          if (hiddenFor.contains(myUid) || deletedFor.contains(myUid)) {
            return false;
          }

          final convo = ConversationModel.fromFirestore(doc);
          if (convo.status == 'declined') return false;
          if (convo.isPending && convo.requestedBy != myUid) return false;
          return true;
        }).toList();

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            subtitle: 'Start a conversation from someone\'s profile',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 78,
            color: _ThemeResolver.border(context),
          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _ConversationAvatar(name: otherName, avatar: otherAvatar),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _ThemeResolver.textHi(context),
                                  fontSize: 15,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isMyPendingRequest
                                      ? context.colors.primary
                                      : isUnread
                                      ? _ThemeResolver.textHi(context)
                                      : _ThemeResolver.textDim(context),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _ThemeResolver.textDim(context),
                                fontSize: 11,
                              ),
                        ),
                        const SizedBox(height: 6),
                        if (isUnread && !isMyPendingRequest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primary,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
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

class _RequestsTab extends StatelessWidget {
  final MessagingService messagingService;
  final String myUid;
  final String Function(DateTime?) relativeTime;
  final void Function(ConversationModel, String) onOpenChat;

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
          return _CenteredMessage(text: 'Could not load requests');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.primary,
              strokeWidth: 2,
            ),
          );
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hiddenFor = List<String>.from(data['hiddenFor'] ?? const []);
          final deletedFor = List<String>.from(data['deletedFor'] ?? const []);
          if (hiddenFor.contains(myUid) || deletedFor.contains(myUid)) {
            return false;
          }

          final convo = ConversationModel.fromFirestore(doc);
          return convo.requestedBy != myUid;
        }).toList();

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No message requests',
            subtitle:
                'Requests from people you don\'t follow back\nwill show up here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 78,
            color: _ThemeResolver.border(context),
          ),
          itemBuilder: (context, index) {
            final convo = ConversationModel.fromFirestore(docs[index]);
            final otherName = convo.otherName(myUid);
            final otherAvatar = convo.otherAvatar(myUid);

            return InkWell(
              onTap: () => onOpenChat(convo, myUid),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _ConversationAvatar(name: otherName, avatar: otherAvatar),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _ThemeResolver.textHi(context),
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _ThemeResolver.textDim(context),
                                  fontSize: 13,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      relativeTime(convo.lastMessageAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _ThemeResolver.textDim(context),
                        fontSize: 11,
                      ),
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

class _ConversationAvatar extends StatelessWidget {
  final String name;
  final String? avatar;

  const _ConversationAvatar({required this.name, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: context.colors.surfaceContainerHighest,
      backgroundImage: avatar != null ? NetworkImage(avatar!) : null,
      child: avatar == null
          ? Text(
              name.isNotEmpty ? name[0] : '?',
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.colors.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _ThemeResolver.textHi(context),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _ThemeResolver.textDim(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String text;

  const _CenteredMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: _ThemeResolver.textDim(context)),
      ),
    );
  }
}

class _ThemeResolver {
  const _ThemeResolver._();

  static Color textHi(BuildContext context) => context.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;

  static Color textDim(BuildContext context) =>
      context.isDarkMode ? AppColors.darkTextDim : AppColors.lightTextDim;

  static Color border(BuildContext context) =>
      context.isDarkMode ? AppColors.darkDivider : AppColors.lightDivider;
}

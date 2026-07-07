import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_avatar.dart';
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

  // ── Glass tab bar ──────────────────────────────────────────────────────────
  Widget _buildGlassTabBar(AppColorsExtension c, bool isDark) {
    final tabs = ['Chats', 'Requests'];
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Row(
          children: List.generate(tabs.length, (i) {
            final selected = _tabController.index == i;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tabController.animateTo(i)),
                child: Container(
                  margin: EdgeInsets.only(right: i == 0 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? c.primary
                        : Colors.white
                            .withValues(alpha: isDark ? 0.10 : 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : Colors.white.withValues(
                              alpha: isDark ? 0.18 : 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : c.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bare Column — no Scaffold/AppBar. Inherits sidebar glass background.
    return Column(
      children: [
        _buildGlassTabBar(c, isDark),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ChatsTab(
                messagingService: _messagingService,
                myUid: myUid,
                relativeTime: _relativeTime,
                onOpenChat: _openChat,
                isDark: isDark,
              ),
              _RequestsTab(
                messagingService: _messagingService,
                myUid: myUid,
                relativeTime: _relativeTime,
                onOpenChat: _openChat,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Chats Tab ──────────────────────────────────────────────────────────────────

class _ChatsTab extends StatelessWidget {
  final MessagingService messagingService;
  final String myUid;
  final String Function(DateTime?) relativeTime;
  final void Function(ConversationModel, String) onOpenChat;
  final bool isDark;

  const _ChatsTab({
    required this.messagingService,
    required this.myUid,
    required this.relativeTime,
    required this.onOpenChat,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return StreamBuilder(
      stream: messagingService.conversationsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GlassCenteredMessage(text: 'Could not load conversations');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: c.primary, strokeWidth: 2));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hiddenFor =
              List<String>.from(data['hiddenFor'] ?? const []);
          final deletedFor =
              List<String>.from(data['deletedFor'] ?? const []);
          if (hiddenFor.contains(myUid) || deletedFor.contains(myUid)) {
            return false;
          }
          final convo = ConversationModel.fromFirestore(doc);
          if (convo.status == 'declined') return false;
          if (convo.isPending && convo.requestedBy != myUid) return false;
          return true;
        }).toList();

        if (docs.isEmpty) {
          return _GlassEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            subtitle: "Start a conversation from someone's profile",
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final convo = ConversationModel.fromFirestore(docs[index]);
            final otherName = convo.otherName(myUid);
            final otherAvatar = convo.otherAvatar(myUid);
            final unread = convo.unreadFor(myUid);
            final isUnread = unread > 0;
            final isMine = convo.lastSenderId == myUid;
            final isMyPendingRequest = convo.isPending;

            return GestureDetector(
              onTap: () => onOpenChat(convo, myUid),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUnread && !isMyPendingRequest
                          ? (isDark
                              ? c.primary.withValues(alpha: 0.15)
                              : c.primary.withValues(alpha: 0.07))
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.white.withValues(alpha: 0.40)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUnread && !isMyPendingRequest
                            ? c.primary.withValues(alpha: 0.30)
                            : Colors.white.withValues(
                                alpha: isDark ? 0.12 : 0.50),
                        width: isUnread && !isMyPendingRequest ? 1.0 : 0.5,
                      ),
                    ),
                    child: Row(children: [
                      _GlassConversationAvatar(
                          name: otherName, avatar: otherAvatar),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                otherName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textHi,
                                  fontSize: 13.5,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
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
                                      ? c.primary
                                      : isUnread
                                          ? c.textHi
                                          : c.textMuted,
                                  fontSize: 11.5,
                                  fontStyle: isMyPendingRequest
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  fontWeight:
                                      isUnread && !isMyPendingRequest
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                ),
                              ),
                            ]),
                      ),
                      const SizedBox(width: 6),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              relativeTime(convo.lastMessageAt),
                              style: TextStyle(
                                  color: c.textDim, fontSize: 10),
                            ),
                            const SizedBox(height: 5),
                            if (isUnread && !isMyPendingRequest)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                constraints: const BoxConstraints(
                                    minWidth: 18, minHeight: 18),
                                decoration: BoxDecoration(
                                  color: c.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                          ]),
                    ]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Requests Tab ───────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final MessagingService messagingService;
  final String myUid;
  final String Function(DateTime?) relativeTime;
  final void Function(ConversationModel, String) onOpenChat;
  final bool isDark;

  const _RequestsTab({
    required this.messagingService,
    required this.myUid,
    required this.relativeTime,
    required this.onOpenChat,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return StreamBuilder(
      stream: messagingService.pendingRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GlassCenteredMessage(text: 'Could not load requests');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: c.primary, strokeWidth: 2));
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hiddenFor =
              List<String>.from(data['hiddenFor'] ?? const []);
          final deletedFor =
              List<String>.from(data['deletedFor'] ?? const []);
          if (hiddenFor.contains(myUid) || deletedFor.contains(myUid)) {
            return false;
          }
          final convo = ConversationModel.fromFirestore(doc);
          return convo.requestedBy != myUid;
        }).toList();

        if (docs.isEmpty) {
          return _GlassEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No message requests',
            subtitle:
                "Requests from people you don't follow\nwill show up here",
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final convo =
                ConversationModel.fromFirestore(docs[index]);
            final otherName = convo.otherName(myUid);
            final otherAvatar = convo.otherAvatar(myUid);

            return GestureDetector(
              onTap: () => onOpenChat(convo, myUid),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.white.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: isDark ? 0.12 : 0.50),
                        width: 0.5,
                      ),
                    ),
                    child: Row(children: [
                      _GlassConversationAvatar(
                          name: otherName, avatar: otherAvatar),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                otherName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: c.textHi,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                convo.lastMessage.isEmpty
                                    ? 'Wants to message you'
                                    : convo.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: c.textMuted, fontSize: 11.5),
                              ),
                            ]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        relativeTime(convo.lastMessageAt),
                        style:
                            TextStyle(color: c.textDim, fontSize: 10),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Shared glass sub-widgets ───────────────────────────────────────────────────

class _GlassConversationAvatar extends StatelessWidget {
  final String name;
  final String? avatar;
  const _GlassConversationAvatar(
      {required this.name, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: CustomAvatar(
          name: name,
          imageUrl: avatar,
          radius: 22,
        ),
      ),
    );
  }
}

class _GlassEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _GlassEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white
                      .withValues(alpha: isDark ? 0.18 : 0.6),
                  width: 0.8,
                ),
              ),
              child: Icon(icon, color: c.primary, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(title,
            style: TextStyle(
                color: c.textHi,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: c.textMuted, fontSize: 12, height: 1.4)),
      ]),
    );
  }
}

class _GlassCenteredMessage extends StatelessWidget {
  final String text;
  const _GlassCenteredMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Text(text,
          style: TextStyle(color: c.textMuted, fontSize: 12)),
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
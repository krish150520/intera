import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/screens/home_feed_screen.dart';
import '../../home/screens/pinterest_feed_screen.dart';
import '../../create/screens/create_post_screen.dart';
import '../../videos/screens/communities_screen.dart';
import '../../tasks/screens/task_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/reaction_service.dart';
import '../../../core/karma/karma_service.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  static final ValueNotifier<int> indexNotifier = ValueNotifier<int>(0);

  static void switchToTab(int index) {
    indexNotifier.value = index;
  }

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _currentIndex = 0;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsListenerInitialized = false;

  static final List<Widget> _screens = [
    HomeFeedScreen(),
    PinterestFeedScreen(),
    CreatePostScreen(),
    CommunitiesScreen(),
    HelpRequestScreen(),
  ];

  final List<_NavItem> _items = [
    _NavItem(icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,          label: AppStrings.home),
    _NavItem(icon: Icons.explore_outlined,       activeIcon: Icons.explore_rounded,       label: 'Discover'),
    _NavItem(icon: Icons.add_rounded,             activeIcon: Icons.add_rounded,           label: AppStrings.create),
    _NavItem(icon: Icons.group_outlined,          activeIcon: Icons.group_rounded,         label: 'Communities'),
    _NavItem(icon: Icons.task_alt_outlined,       activeIcon: Icons.task_rounded,          label: 'Tasks'),
  ];

  static const int _createIndex = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      ReactionService.syncUserPoints(uid);
      KarmaService.syncKarmaBalance(uid);
      _initLocalNotificationsAndListen(uid);
    }
    _currentIndex = BottomNavScreen.indexNotifier.value;
    BottomNavScreen.indexNotifier.addListener(_handleIndexChange);
  }

  Future<void> _initLocalNotificationsAndListen(String uid) async {
    if (_notificationsListenerInitialized) return;
    _notificationsListenerInitialized = true;

    try {
      final androidInit = const AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosInit = const DarwinInitializationSettings();
      final initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
      await _localNotificationsPlugin.initialize(
        settings: initSettings,
      );

      final launchTime = Timestamp.now();
      FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .where('createdAt', isGreaterThan: launchTime)
          .snapshots()
          .listen((snap) {
            for (final change in snap.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data() as Map<String, dynamic>? ?? {};
                final title = data['title'] ?? 'New Notification';
                final subtitle = data['subtitle'] ?? '';
                _showLocalNotification(title, subtitle);
              }
            }
          });
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  void _showLocalNotification(String title, String body) async {
    final androidDetails = const AndroidNotificationDetails(
      'intera_channel_id',
      'INTERA Notifications',
      channelDescription: 'Real-time notifications for INTERA DMs, comments, and activities',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    final iosDetails = const DarwinNotificationDetails();
    final platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  void _handleIndexChange() {
    if (mounted) {
      setState(() {
        _currentIndex = BottomNavScreen.indexNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    BottomNavScreen.indexNotifier.removeListener(_handleIndexChange);
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPrompted = prefs.getBool('has_prompted_notifications') ?? false;
      if (hasPrompted) return;

      final notifStatus = await Permission.notification.status;

      if (notifStatus.isDenied) {
        if (!mounted) return;
        _showNotificationPermissionSheet(prefs);
      }
    } catch (e) {
      debugPrint('Notification permission check failed: $e');
    }
  }

  void _showNotificationPermissionSheet(SharedPreferences prefs) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Enable Notifications',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Allow notification permissions to get the best experience on INTERA, like receiving chat messages and replies in real-time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPermissionRow(
                      icon: Icons.notifications_active_rounded,
                      color: Colors.orangeAccent,
                      title: 'Push Notifications',
                      subtitle: 'Stay updated on replies, likes, and sparks.',
                      onTap: () async {
                        final status = await Permission.notification.request();
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (status.isGranted && uid != null && uid.isNotEmpty) {
                          _initLocalNotificationsAndListen(uid);
                        }
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () async {
                        await prefs.setBool('has_prompted_notifications', true);
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _buildPermissionRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final c = context.appColors;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: c.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: c.field,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: c.border, width: 0.8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(
            'Allow',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: c.primary,
            ),
          ),
        ),
      ],
    );
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    BottomNavScreen.indexNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border.withValues(alpha: 0.5), width: 0.6)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_items.length, (i) {
                final selected = i == _currentIndex;
                final item = _items[i];

                // ── Create button — lifted pill ──────────────────────────
                if (i == _createIndex) {
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -6),
                            child: AnimatedScale(
                              scale: selected ? 1.05 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFA597EC),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFA597EC).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                ),
                                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -4),
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: selected ? c.primary : c.inactive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // ── Regular nav item ─────────────────────────────────────
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: selected ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 52,
                            height: 28,
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF2C2754) : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: Icon(
                                  selected ? item.activeIcon : item.icon,
                                  key: ValueKey(selected),
                                  size: 22,
                                  color: selected ? Colors.white : c.inactive,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? c.primary : c.inactive,
                          ),
                          child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav item data ─────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
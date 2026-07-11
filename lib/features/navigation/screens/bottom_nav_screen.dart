import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../../core/services/permission_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/services/notification_service.dart';


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
    _NavItem( icon: Icons.explore_outlined,activeIcon: Icons.explore, label: 'Discover',),    _NavItem(icon: Icons.add_rounded,             activeIcon: Icons.add_rounded,           label: AppStrings.create),
    _NavItem(icon: Icons.people_outline_rounded,  activeIcon: Icons.people_rounded,        label: 'Communities'),
    _NavItem(icon: Icons.assignment_turned_in_outlined, activeIcon: Icons.assignment_turned_in_rounded, label: 'Tasks'),
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
      // Fetch current FCM token on startup/permission grant and save to Firestore
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await NotificationService.saveFcmToken(token);
        }
      } catch (e) {
        debugPrint('FCM Token retrieval failed inside bottom_nav_screen: $e');
      }

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
                final data = change.doc.data() ?? {};
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
      final newIndex = BottomNavScreen.indexNotifier.value;
      if (newIndex == _createIndex) {
        BottomNavScreen.indexNotifier.value = _currentIndex;
        _showCreateBottomSheet();
        return;
      }
      setState(() {
        _currentIndex = newIndex;
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
      final isGranted = await PermissionService.requestNotificationPermission(context);
      if (isGranted) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          _initLocalNotificationsAndListen(uid);
        }
      }
    } catch (e) {
      debugPrint('Notification permission check failed: $e');
    }
  }


  void _onTap(int index) {
    if (index == _createIndex) {
      _showCreateBottomSheet();
      return;
    }
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    BottomNavScreen.indexNotifier.value = index;
  }

  void _showCreateBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _PinterestBottomSheet(
          onSelectMedia: (file, isVideo) {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreatePostScreen(
                  initialMediaFile: file,
                  isVideo: isVideo,
                ),
              ),
            );
          },
          onSelectText: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreatePostScreen(),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      // Set resizeToAvoidBottomInset to false to prevent navigation bar jumping with keyboard
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: Container(
        color: Colors.transparent, // Background under margins is transparent
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Container(
          height: 60, // Exact visual height matching the user's screenshot
          decoration: BoxDecoration(
            color: context.isDarkMode ? c.surface : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDarkMode ? 0.25 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / _items.length;
              const circleSize = 42.0;
              final circleTop = (60.0 - circleSize) / 2; // Center circle vertically
              
              final showIndicator = _currentIndex != _createIndex;
              final leftOffset = (tabWidth * _currentIndex) + (tabWidth - circleSize) / 2;

              return Stack(
                children: [
                  // Liquid sliding indicator circle behind the items
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: leftOffset,
                    top: circleTop,
                    width: circleSize,
                    height: circleSize,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: showIndicator ? 1.0 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.isDarkMode
                                ? c.primary.withValues(alpha: 0.15)
                                : const Color(0xFFF1EEFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Navigation items row
                  Row(
                    children: List.generate(_items.length, (i) {
                      final item = _items[i];
                      if (i == _createIndex) {
                        return _FloatingCreateButton(
                          selected: _currentIndex == _createIndex,
                          onTap: () => _onTap(_createIndex),
                        );
                      }
                      return _FloatingNavItem(
                        icon: item.icon,
                        activeIcon: item.activeIcon,
                        selected: _currentIndex == i,
                        onTap: () => _onTap(i),
                      );
                    }),
                  ),
                ],
              );
            },
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

// ── Floating Nav Item Widget ──────────────────────────────────────────────────

class _FloatingNavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FloatingNavItem> createState() => _FloatingNavItemState();
}

class _FloatingNavItemState extends State<_FloatingNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _FloatingNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final activeColor = c.primary;
    final inactiveColor = c.textDim;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 250),
                  tween: ColorTween(
                    end: widget.selected ? activeColor : inactiveColor,
                  ),
                  builder: (context, color, child) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        widget.selected ? widget.activeIcon : widget.icon,
                        key: ValueKey(widget.selected),
                        size: 22,
                        color: color,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating Create Button ────────────────────────────────────────────────────

class _FloatingCreateButton extends StatefulWidget {
  final bool selected;
  final VoidCallback onTap;

  const _FloatingCreateButton({
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FloatingCreateButton> createState() => _FloatingCreateButtonState();
}

class _FloatingCreateButtonState extends State<_FloatingCreateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.94, // Premium subtle click compression to 0.94
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final buttonColor = c.primary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _controller.animateTo(0.94, curve: Curves.easeInOut),
        onTapUp: (_) {
          _controller.animateTo(1.0, curve: Curves.easeInOut);
          widget.onTap();
        },
        onTapCancel: () => _controller.animateTo(1.0, curve: Curves.easeInOut),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 44, // Matches layout size exactly
              height: 44,
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: context.isDarkMode ? 0.35 : 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pinterest Bottom Sheet Modal ──────────────────────────────────────────────

class _PinterestBottomSheet extends StatelessWidget {
  final Function(File file, bool isVideo) onSelectMedia;
  final VoidCallback onSelectText;

  const _PinterestBottomSheet({
    required this.onSelectMedia,
    required this.onSelectText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ImagePicker picker = ImagePicker();

    Future<void> pick(ImageSource source, bool isVideo) async {
      final file = isVideo
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source);
      if (file != null) {
        onSelectMedia(File(file.path), isVideo);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 10,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          
          // Header title & close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.close_rounded, color: c.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text(
                'Start creating now',
                style: TextStyle(
                  color: c.textHi,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 48), // Align spacer
            ],
          ),
          const SizedBox(height: 24),

          // Selection Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PinterestOptionButton(
                icon: Icons.photo_library_outlined,
                label: 'Photo',
                onTap: () => pick(ImageSource.gallery, false),
              ),
              _PinterestOptionButton(
                icon: Icons.video_library_outlined,
                label: 'Video',
                onTap: () => pick(ImageSource.gallery, true),
              ),
              _PinterestOptionButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => pick(ImageSource.camera, false),
              ),
              _PinterestOptionButton(
                icon: Icons.article_outlined,
                label: 'Text Post',
                onTap: onSelectText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pinterest Option Button ───────────────────────────────────────────────────

class _PinterestOptionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PinterestOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_PinterestOptionButton> createState() => _PinterestOptionButtonState();
}

class _PinterestOptionButtonState extends State<_PinterestOptionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTapDown: (_) => _controller.animateTo(0.92, curve: Curves.easeOutCubic),
      onTapUp: (_) {
        _controller.animateTo(1.0, curve: Curves.easeOutCubic);
        widget.onTap();
      },
      onTapCancel: () => _controller.animateTo(1.0, curve: Curves.easeOutCubic),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: c.field,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDarkMode ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: c.primary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

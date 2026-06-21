import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/strings.dart';
import '../../../core/theme/colors.dart';
import '../../home/screens/home_feed_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../create/screens/create_post_screen.dart';
import '../../videos/screens/communities_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../profile/screens/my_profile_screen.dart';
import '../../tasks/screens/task_screen.dart'; // Update path as needed

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _primary     = Color(0xFF7C3AED);
  static const Color _primarySoft = Color(0xFFEDE9FF);
  static const Color _surface     = Color(0xFFFFFFFF);
  static const Color _border      = Color(0xFFE9E4FF);
  static const Color _inactive    = Color(0xFFC4B5FD);

  int _currentIndex = 0;

  // FIXED: Removed VideoFeedScreen instance node and swapped in CommunitiesScreen layout asset
  static const List<Widget> _screens = [
    HomeFeedScreen(),
    SearchScreen(),
    CreatePostScreen(),
    CommunitiesScreen(),
    HelpRequestScreen(),    // ◄── REPLACED NotificationsScreen
    MyProfileScreen(),
  ];

  // FIXED: Updated icon data blueprints and label strings to mirror a communal dashboard hub style
 static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_outlined,         activeIcon: Icons.home_rounded,         label: AppStrings.home),
    _NavItem(icon: Icons.search_rounded,        activeIcon: Icons.search_rounded,       label: AppStrings.search),
    _NavItem(icon: Icons.add_rounded,           activeIcon: Icons.add_rounded,          label: AppStrings.create),
    _NavItem(icon: Icons.group_outlined,        activeIcon: Icons.group_rounded,        label: 'Communities'),
    _NavItem(icon: Icons.task_alt_outlined,     activeIcon: Icons.task_rounded,         label: 'Tasks'), // ◄── UPDATED
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,      label: AppStrings.profile),
  ];

  // Index of the "Create" button — rendered differently (elevated square)
  static const int _createIndex = 2;

  void _onTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Respect dark mode while keeping our custom palette for light
    final bgColor     = isDark ? AppColors.darkSurface : _surface;
    final borderColor = isDark ? AppColors.darkBorder  : _border;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : _inactive;
    final pillColor   = isDark ? _primary.withOpacity(0.2) : _primarySoft;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: borderColor, width: 0.6)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: List.generate(_items.length, (i) {
                final selected = i == _currentIndex;
                final item = _items[i];

                // ── Create button: lifted violet square ──────────────────
                if (i == _createIndex) {
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Lifts above the bar
                          Transform.translate(
                            offset: const Offset(0, -10),
                            child: AnimatedScale(
                              scale: selected ? 1.06 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  item.activeIcon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          // Label sits just below the lifted button
                          Transform.translate(
                            offset: const Offset(0, -8),
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: selected ? _primary : inactiveColor,
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
                        // Icon inside a soft pill when active
                        AnimatedScale(
                          scale: selected ? 1.06 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 40,
                            height: 26,
                            decoration: BoxDecoration(
                              color: selected ? pillColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: Icon(
                                  selected ? item.activeIcon : item.icon,
                                  key: ValueKey(selected),
                                  size: 22,
                                  color: selected ? _primary : inactiveColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Label
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? _primary : inactiveColor,
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
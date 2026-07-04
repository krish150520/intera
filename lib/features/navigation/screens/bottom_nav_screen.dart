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
import '../../tasks/screens/task_screen.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeFeedScreen(),
    SearchScreen(),
    CreatePostScreen(),
    CommunitiesScreen(),
    HelpRequestScreen(),
    MyProfileScreen(),
  ];

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,          label: AppStrings.home),
    _NavItem(icon: Icons.search_rounded,         activeIcon: Icons.search_rounded,        label: AppStrings.search),
    _NavItem(icon: Icons.add_rounded,            activeIcon: Icons.add_rounded,           label: AppStrings.create),
    _NavItem(icon: Icons.group_outlined,         activeIcon: Icons.group_rounded,         label: 'Communities'),
    _NavItem(icon: Icons.task_alt_outlined,      activeIcon: Icons.task_rounded,          label: 'Tasks'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,        label: AppStrings.profile),
  ];

  static const int _createIndex = 2;

  void _onTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final c = _ThemeColors(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border, width: 0.6)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
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
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
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
                                  color: c.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(item.activeIcon, color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -8),
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
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
                          scale: selected ? 1.06 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 40,
                            height: 26,
                            decoration: BoxDecoration(
                              color: selected ? c.pill : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: Icon(
                                  selected ? item.activeIcon : item.icon,
                                  key: ValueKey(selected),
                                  size: 22,
                                  color: selected ? c.primary : c.inactive,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

// ── Theme resolver ────────────────────────────────────────────────────────────

class _ThemeColors {
  final BuildContext context;
  _ThemeColors(this.context);

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get primary  => _dark ? AppColors.primaryLight      : AppColors.primary;
  Color get surface  => _dark ? AppColors.darkSurface       : AppColors.lightSurface;
  Color get border   => _dark ? AppColors.darkBorder        : AppColors.lightBorder;
  // Pill background behind the active icon
  Color get pill     => _dark ? AppColors.darkField         : AppColors.lightField;
  // Inactive icon/label colour
  Color get inactive => _dark ? AppColors.darkTextDim       : AppColors.lightTextDim;
}
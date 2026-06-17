import 'package:flutter/material.dart';

/// A reusable themed AppBar used across INTERA screens.
///
/// Usage:
/// ```dart
/// CustomAppBar(
///   title: 'Notifications',
///   actions: [IconButton(icon: Icon(Icons.search), onPressed: () {})],
/// )
/// ```
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
    );
  }
}

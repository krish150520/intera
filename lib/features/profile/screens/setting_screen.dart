import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feedback_screen.dart';
import '../../../core/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Theme helpers ──────────────────────────────────────────────────────────
  ColorScheme get _cs  => Theme.of(context).colorScheme;
  bool get _isDark     => Theme.of(context).brightness == Brightness.dark;
  Color get _bg        => Theme.of(context).scaffoldBackgroundColor;
  Color get _surface   => _cs.surface;
  Color get _primary   => _cs.primary;
  Color get _error     => _cs.error;
  Color get _border    => _isDark ? AppColors.darkBorder    : AppColors.lightDivider;
  Color get _textDark  => _isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
  Color get _textMuted => _isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Settings',
            style: TextStyle(
                color: _textDark, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Account info card ────────────────────────────────────────────
          _AccountInfoCard(uid: _uid),
          const SizedBox(height: 20),

          // ── Content ──────────────────────────────────────────────────────
          _SectionLabel('CONTENT'),
          const SizedBox(height: 8),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.bookmark_outline_rounded,
              label: 'Saved posts',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SavedPostsScreen(uid: _uid))),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Account ──────────────────────────────────────────────────────
          _SectionLabel('ACCOUNT'),
          const SizedBox(height: 8),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit profile',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
            ),
            _SettingsTile(
              icon: Icons.swap_horiz_rounded,
              label: 'Switch account',
              onTap: () => _showSwitchAccountSheet(context),
            ),
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Log out',
              onTap: () => _confirmLogout(context),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Support ───────────────────────────────────────────────────────
          _SectionLabel('SUPPORT'),
          const SizedBox(height: 8),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.feedback_outlined,
              label: 'Send feedback',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackScreen())),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Danger zone ───────────────────────────────────────────────────
          _SectionLabel('DANGER ZONE'),
          const SizedBox(height: 8),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete account',
              labelColor: _error,
              iconColor: _error,
              onTap: () => _confirmDeleteAccount(context),
            ),
          ]),

          const SizedBox(height: 24),
          Center(
            child: Text('INTERA · v1.0.0',
                style: TextStyle(color: _textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ── Log out ────────────────────────────────────────────────────────────────
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Log out?',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: _textDark, fontSize: 16)),
        content: const Text('You can always sign back in anytime.',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _rememberAccountLocally();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login, (route) => false);
              }
            },
            child: Text('Log out',
                style: TextStyle(color: _error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Switch account ─────────────────────────────────────────────────────────
  Future<void> _rememberAccountLocally() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList('recent_accounts') ?? [];
    list.remove(user!.email);
    list.insert(0, user.email!);
    if (list.length > 5) list.removeRange(5, list.length);
    await prefs.setStringList('recent_accounts', list);
  }

  void _showSwitchAccountSheet(BuildContext context) async {
    final prefs        = await SharedPreferences.getInstance();
    final recents      = prefs.getStringList('recent_accounts') ?? [];
    final currentEmail = FirebaseAuth.instance.currentUser?.email;
    final others       = recents.where((e) => e != currentEmail).toList();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Switch account',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Signing in as another account will sign you out here first.',
                style: TextStyle(fontSize: 12, color: _textMuted),
              ),
            ),
            Divider(height: 1, color: _border),

            if (others.isNotEmpty)
              ...others.map((email) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _isDark
                          ? AppColors.darkField
                          : AppColors.lightField,
                      child: Text(email[0].toUpperCase(),
                          style: TextStyle(
                              color: _primary, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(email,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _textDark)),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: _border),
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await _rememberAccountLocally();
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.login,
                          (route) => false,
                          arguments: {'prefillEmail': email},
                        );
                      }
                    },
                  )),

            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _isDark ? AppColors.darkField : AppColors.lightField,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: _primary, size: 20),
              ),
              title: Text('Add another account',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primary)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _rememberAccountLocally();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login, (route) => false);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Delete account ─────────────────────────────────────────────────────────
  void _confirmDeleteAccount(BuildContext context) {
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isValid =
              confirmCtrl.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            title: Text('Delete your account?',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _error,
                    fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This permanently deletes your profile, posts, comments, '
                  'and karma history. This cannot be undone.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text('Type DELETE to confirm',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmCtrl,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _error)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: TextStyle(color: _textMuted)),
              ),
              TextButton(
                onPressed: isValid
                    ? () async {
                        Navigator.pop(dialogCtx);
                        await _deleteAccount(context);
                      }
                    : null,
                child: Text('Delete forever',
                    style: TextStyle(
                        color: isValid ? _error : _border,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
          child: CircularProgressIndicator(color: _error)),
    );

    try {
      final uid = user.uid;
      final db  = FirebaseFirestore.instance;

      final posts = await db.collection('posts')
          .where('authorId', isEqualTo: uid).get();
      for (final doc in posts.docs) await doc.reference.delete();

      await db.collection('users').doc(uid).delete();
      await user.delete();

      if (context.mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login, (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (e.code == 'requires-recent-login') {
        if (context.mounted) _snack(context,
            'Please log out and log back in, then try deleting again.');
      } else {
        if (context.mounted) _snack(context, 'Failed: ${e.message}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _snack(context, 'Failed: $e');
      }
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ── Account info card ──────────────────────────────────────────────────────────

class _AccountInfoCard extends StatelessWidget {
  final String uid;
  const _AccountInfoCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final surface  = Theme.of(context).colorScheme.surface;
    final border   = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final field    = isDark ? AppColors.darkField     : AppColors.lightField;
    final textDark = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted= isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final authUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data     = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name     = data['name']     ?? authUser?.displayName ?? 'User';
        final email    = authUser?.email  ?? 'No email';
        final avatar   = data['avatarUrl'] ?? data['profileImageUrl'] ?? authUser?.photoURL;
        final username = data['username'] ?? 'user';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primary, width: 2)),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: field,
                backgroundImage: (avatar != null && (avatar as String).isNotEmpty)
                    ? NetworkImage(avatar)
                    : null,
                child: (avatar == null || (avatar as String).isEmpty)
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 20))
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: textDark)),
                const SizedBox(height: 2),
                Text(username.startsWith('@') ? username : '@$username',
                    style: TextStyle(fontSize: 12, color: primary)),
                const SizedBox(height: 4),
                Text(email,
                    style: TextStyle(fontSize: 11, color: textMuted)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8)),
    );
  }
}

// ── Settings group ────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final border  = isDark ? AppColors.darkBorder  : AppColors.lightBorder;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 52, color: divider),
          ],
        ],
      ),
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final textDark = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final dimColor = isDark ? AppColors.darkBorder : AppColors.lightChipBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: iconColor ?? primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? textDark)),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: dimColor, size: 20),
        ]),
      ),
    );
  }
}

// ── Saved posts screen ─────────────────────────────────────────────────────────

class SavedPostsScreen extends StatelessWidget {
  final String uid;
  const SavedPostsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final bg       = Theme.of(context).scaffoldBackgroundColor;
    final surface  = Theme.of(context).colorScheme.surface;
    final textDark = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted= isDark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Saved posts',
            style: TextStyle(
                color: textDark, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('savedBy', arrayContains: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: primary, strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bookmark_border_rounded, color: textMuted, size: 44),
                const SizedBox(height: 12),
                Text('No saved posts yet',
                    style: TextStyle(
                        color: textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Posts you save will show up here.',
                    style: TextStyle(color: textMuted, fontSize: 12)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final post = Post.fromFirestore(docs[i], uid);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: post,
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppRoutes.postDetail, arguments: post),
                  onLike: () {
                    final dataMap = docs[i].data() as Map<String, dynamic>?;
                    final List likedBy = dataMap?['likedBy'] ?? [];
                    NotificationService.toggleLike(
                      postId: docs[i].id,
                      postAuthorId: post.authorId,
                      postTitle: post.title,
                      currentUid: uid,
                      likedBy: likedBy,
                    );
                  },
                  onSave: () => FirebaseFirestore.instance
                      .collection('posts')
                      .doc(docs[i].id)
                      .update({'savedBy': FieldValue.arrayRemove([uid])}),
                  onComment: () => Navigator.of(context)
                      .pushNamed(AppRoutes.postDetail, arguments: post),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
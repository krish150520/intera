import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

class SetupUsernameScreen extends StatefulWidget {
  const SetupUsernameScreen({super.key});

  @override
  State<SetupUsernameScreen> createState() => _SetupUsernameScreenState();
}

class _SetupUsernameScreenState extends State<SetupUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _claimUsername() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final rawUsername = _usernameController.text.trim().replaceAll('@', '');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Verify Uniqueness in Firestore
      final taken = await FirebaseFirestore.instance
          .collection('users')
          .where('usernameLower', isEqualTo: rawUsername.toLowerCase())
          .limit(1)
          .get();

      if (taken.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This handle is already claimed. Please try another one.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // 2. Set username in Firestore
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();
      final username = '@$rawUsername';
      final usernameLower = rawUsername.toLowerCase();

      final data = {
        'username': username,
        'usernameLower': usernameLower,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (docSnapshot.exists) {
        await docRef.update(data);
      } else {
        await docRef.set({
          'id': user.uid,
          'name': user.displayName ?? 'New User',
          'username': username,
          'usernameLower': usernameLower,
          'bio': 'Welcome to my INTERA workspace profile!',
          'avatarUrl': user.photoURL ?? '',
          'karmaPoints': 100,
          'followersCount': 0,
          'followingCount': 0,
          'skills': [],
          'isAnonymous': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Welcome to INTERA, $username!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.alternate_email_rounded,
                        size: 48,
                        color: c.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header Title
                  Text(
                    'Choose your handle',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      color: c.textHi,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'This is your unique handle on INTERA. Other designers and developers can search and connect with you using it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Username Input Field
                  CustomTextField(
                    label: 'Username',
                    controller: _usernameController,
                    prefixIcon: Icons.alternate_email_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username handle cannot be empty.';
                      }
                      final clean = value.trim().replaceAll('@', '');
                      if (clean.length < 3) {
                        return 'Handle must be at least 3 characters.';
                      }
                      if (clean.contains(' ')) {
                        return 'Username must not contain spacer items.';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
                        return 'Handle can only contain letters, numbers, and underscores.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  CustomButton(
                    label: 'Claim Handle & Continue',
                    isLoading: _isLoading,
                    onPressed: _claimUsername,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

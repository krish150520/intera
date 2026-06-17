import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

/// Screen 3: Login Screen
/// Authenticates users via email and password, verifying their Firestore metadata profile on success.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Verifies or provisions a corresponding Firestore database profile document
  Future<void> _ensureUserProfileExists(User firebaseUser) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
    final docSnapshot = await userDocRef.get();

    if (!docSnapshot.exists) {
      // Lazy-provision profile document if auth credentials exist but the document was skipped
      final String fallbackName = firebaseUser.displayName ?? 'New User';
      final String fallbackUsername = '@${(firebaseUser.email ?? 'user').split('@')[0]}';

      await userDocRef.set({
        'id': firebaseUser.uid,
        'name': fallbackName,
        'username': fallbackUsername,
        'bio': 'Welcome to my INTERA workspace profile!',
        'avatarUrl': firebaseUser.photoURL ?? '',
        'karmaPoints': 100, // Welcome gift points initialization
        'followersCount': 0,
        'followingCount': 0,
        'skills': [],
        'isAnonymous': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Authenticate with core Firebase engine
      final UserCredential credentials = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _identifierController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (credentials.user != null) {
        // 2. Guarantee structural document data mapping alignment
        await _ensureUserProfileExists(credentials.user!);
      }

      if (!mounted) return;

      // Reset routing history and push user directly to feed screens
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Authentication rejected.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected pipeline issue: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Implements real production password reset email sequences
  void _handleForgotPassword() async {
    final email = _identifierController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write your email address in the input field first to request a reset link.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset Link Issued'),
          content: Text('A secure link has been transmitted over to $email. Please check your inbox or spam folders to complete your configuration changes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Understood'),
            )
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset sequence failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(AppStrings.login, style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome back',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Log in to continue earning Karma.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 36),
                  
                  CustomTextField(
                    label: AppStrings.emailOrPhone,
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your registered email address.';
                      }
                      if (!value.contains('@')) {
                        return 'Please structure a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  
                  CustomTextField(
                    label: AppStrings.password,
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_open_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password string entry required.';
                      }
                      if (value.length < 6) {
                        return 'Password lengths must clear at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: const Text(
                        AppStrings.forgotPassword,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  CustomButton(
                    label: AppStrings.login,
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 20),
                  
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
                      child: const Text(
                        AppStrings.dontHaveAccount,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
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
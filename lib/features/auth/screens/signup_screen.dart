import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intera/core/theme/app_theme.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

/// Screen 4: Sign Up Screen
/// Registers a new user with email/password (or Google), uploads their profile
/// picture, provisions their Firestore profile, and gates email/password users
/// behind email verification before letting them into the main app.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePicture() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 300,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Media picker encountered an issue: $e')),
      );
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final credential = await AuthService.instance.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        // Validate username uniqueness (authorized read since we are signed in now)
        final usernameVal = _usernameController.text.trim().replaceAll('@', '');
        final taken = await FirebaseFirestore.instance
            .collection('users')
            .where('usernameLower', isEqualTo: usernameVal.toLowerCase())
            .limit(1)
            .get();

        if (taken.docs.isNotEmpty) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Your selected username is already taken. Please choose a new handle.'),
                backgroundColor: Colors.amber,
              ),
            );
            Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.setupUsername, (route) => false);
          }
          return;
        }

        String downloadUrl = '';
        if (_profileImageFile != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_pictures/${firebaseUser.uid}.jpg');
          final uploadTask = storageRef.putFile(_profileImageFile!);
          final snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();
          await firebaseUser.updatePhotoURL(downloadUrl);
        }

        await firebaseUser.updateDisplayName(_nameController.text.trim());

        await AuthService.instance.ensureUserProfileExists(
          firebaseUser,
          name: _nameController.text.trim(),
          username: '@$usernameVal',
          avatarUrl: downloadUrl,
        );

        await AuthService.instance.sendEmailVerification();

        final prefs = await SharedPreferences.getInstance();
        final emailVal = _emailController.text.trim();
        final passVal = _passwordController.text;
        await prefs.setString('pass_for_$emailVal', passVal);

        final list = prefs.getStringList('recent_accounts') ?? [];
        list.remove(emailVal);
        list.insert(0, emailVal);
        if (list.length > 5) list.removeRange(5, list.length);
        await prefs.setStringList('recent_accounts', list);
      }

      if (!mounted) return;
      // Email/password users land here unverified, not in main.
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.verifyEmail, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message ?? 'Registration rejected.'),
            backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Pipeline registration error: $e'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final credentials = await AuthService.instance.signInWithGoogle();
      if (credentials.user != null) {
        await AuthService.instance.ensureUserProfileExists(credentials.user!);
        final hasUser =
            await AuthService.instance.hasUsername(credentials.user!.uid);
        if (!mounted) return;
        if (hasUser) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.setupUsername, (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'sign-in-cancelled') return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message ?? 'Google sign-in failed.'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(AppStrings.signUp,
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: c.textHi,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickProfilePicture,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor:
                                c.primary.withValues(alpha: 0.15),
                            backgroundImage: _profileImageFile != null
                                ? FileImage(_profileImageFile!)
                                : null,
                            child: _profileImageFile == null
                                ? Icon(Icons.person_add_alt_1_outlined,
                                    size: 40, color: c.primary)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: c.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? c.surface : Colors.white,
                                    width: 2,
                                  )),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomTextField(
                    label: AppStrings.name,
                    controller: _nameController,
                    prefixIcon: Icons.badge_outlined,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter your identity label name.'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: AppStrings.username,
                    controller: _usernameController,
                    prefixIcon: Icons.alternate_email_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please define a distinct platform handle identifier.';
                      }
                      if (value.trim().contains(' ')) {
                        return 'User handles must not contain spacer items.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: AppStrings.email,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide a registration email address.';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please cross-verify email structure formatting details.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: AppStrings.password,
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Security passphrase validation configuration required.';
                      }
                      if (value.length < 6) {
                        return 'Passphrases must clear at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                      label: AppStrings.createAccount,
                      isLoading: _isLoading,
                      onPressed: _handleSignUp),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: c.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(color: c.textMuted)),
                      ),
                      Expanded(child: Divider(color: c.border)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignUp,
                    icon: Icon(Icons.g_mobiledata, size: 28, color: c.textHi),
                    label: Text('Continue with Google', style: TextStyle(color: c.textHi)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: c.border),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.login),
                      child: Text(AppStrings.alreadyHaveAccount,
                          style: TextStyle(color: c.textSecondary)),
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

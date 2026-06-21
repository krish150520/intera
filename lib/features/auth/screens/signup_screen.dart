import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/auth_service.dart';
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
      String downloadUrl = '';

      if (firebaseUser != null) {
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
          username: _usernameController.text.trim().startsWith('@')
              ? _usernameController.text.trim()
              : '@${_usernameController.text.trim()}',
          avatarUrl: downloadUrl,
        );

        await AuthService.instance.sendEmailVerification();
      }

      if (!mounted) return;
      // Email/password users land here unverified, not in main.
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.verifyEmail, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration rejected.'), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pipeline registration error: $e'), backgroundColor: Colors.redAccent),
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
      }
      if (!mounted) return;
      // Google accounts are pre-verified — straight into main.
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'sign-in-cancelled') return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed.'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(AppStrings.signUp, style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundImage: _profileImageFile != null ? FileImage(_profileImageFile!) : null,
                            child: _profileImageFile == null
                                ? const Icon(Icons.person_add_alt_1_outlined, size: 40, color: AppColors.primary)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
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
                        (value == null || value.trim().isEmpty) ? 'Please enter your identity label name.' : null,
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
                  CustomButton(label: AppStrings.createAccount, isLoading: _isLoading, onPressed: _handleSignUp),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(color: Colors.grey.shade500)),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignUp,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                      child: const Text(AppStrings.alreadyHaveAccount, style: TextStyle(color: Colors.black54)),
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
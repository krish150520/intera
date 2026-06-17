import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

/// Screen 4: Sign Up Screen
/// Registers a new user with an email and password, uploads their profile picture,
/// and provisions their custom data sheet into Cloud Firestore.
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

  /// Launches native camera or photo gallery to capture an avatar file layout locally
  Future<void> _pickProfilePicture() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Compresses image size to minimize database storage overhead
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
      // 1. Authenticate credentials inside Firebase Auth Core Services
      final UserCredential credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? firebaseUser = credential.user;
      String downloadUrl = '';

      if (firebaseUser != null) {
        // 2. Storage Pipeline: Stream media payloads up to Cloud Storage buckets if image exists
        if (_profileImageFile != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_pictures/${firebaseUser.uid}.jpg');

          final uploadTask = storageRef.putFile(_profileImageFile!);
          final snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();

          // Sync avatar link into core FirebaseAuth profile metadata node
          await firebaseUser.updatePhotoURL(downloadUrl);
        }

        // Synchronize display text name directly to auth instance records
        await firebaseUser.updateDisplayName(_nameController.text.trim());

        // 3. Database Pipeline: Provision verified profile record directly into Cloud Firestore users collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
          'id': firebaseUser.uid,
          'name': _nameController.text.trim(),
          'username': _usernameController.text.trim().startsWith('@') 
              ? _usernameController.text.trim() 
              : '@${_usernameController.text.trim()}',
          'bio': 'Hey there! I am excited to join the INTERA community. 🚀',
          'avatarUrl': downloadUrl,
          'karmaPoints': 100, // Initial balance grant incentive for registration completion
          'followersCount': 0,
          'followingCount': 0,
          'skills': [],
          'isAnonymous': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      // Pop state layout records and route the authenticated user forward directly to the main workspace layout feed
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Registration rejected.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pipeline registration error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                  // Stateful Interactive Avatar Upload View Block
                  Center(
                    child: GestureDetector(
                      onTap: _pickProfilePicture,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundImage: _profileImageFile != null 
                                ? FileImage(_profileImageFile!) 
                                : null,
                            child: _profileImageFile == null
                                ? const Icon(
                                    Icons.person_add_alt_1_outlined,
                                    size: 40,
                                    color: AppColors.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
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
                    // textCapitalization: TextCapitalization.words,
                    validator: (value) => (value == null || value.trim().isEmpty)
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
                    onPressed: _handleSignUp,
                  ),
                  const SizedBox(height: 16),
                  
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                      child: const Text(
                        AppStrings.alreadyHaveAccount,
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
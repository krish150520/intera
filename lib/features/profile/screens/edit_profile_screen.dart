import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/colors.dart';
// import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _skillInputController;
  List<String> _skills = [];
  
  bool _isLoading = true; // Block UI inputs while fetching initial data
  bool _isSaving = false;  // Show overlay loading spinner during save operations
  String? _currentAvatarUrl;
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _skillInputController = TextEditingController();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  /// Synchronizes UI controller data fields with live Firestore profile specs
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? user.displayName ?? '';
          _bioController.text = data['bio'] ?? '';
          _skills = List<String>.from(data['skills'] ?? []);
          _currentAvatarUrl = data['avatarUrl'] ?? user.photoURL;
          _isLoading = false;
        });
      } else if (mounted) {
        // Fallback initialization if a Firestore profile document does not exist yet
        setState(() {
          _nameController.text = user.displayName ?? '';
          _currentAvatarUrl = user.photoURL;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile record: $e')),
        );
      }
    }
  }

  void _addSkill() {
    final value = _skillInputController.text.trim();
    if (value.isEmpty || _skills.contains(value)) return;
    setState(() {
      _skills.add(value);
      _skillInputController.clear();
    });
  }

  void _removeSkill(String skill) {
    setState(() => _skills.remove(skill));
  }

  /// Launches local file explorer to capture and stage image data files
  Future<void> _pickProfilePicture() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75, // Compress images locally to save network data bandwidth
        maxWidth: 400,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  /// Transmits media assets and saves the updated field map into Firestore
  void _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name field cannot be left blank.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalAvatarUrl = _currentAvatarUrl;

      // 1. Storage Pipeline: Process profile photo uploads if a new file is staged
      if (_selectedImageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${user.uid}.jpg');

        final uploadTask = storageRef.putFile(_selectedImageFile!);
        final snapshot = await uploadTask;
        finalAvatarUrl = await snapshot.ref.getDownloadURL();

        // Sync with local core FirebaseAuth instance profile settings state
        await user.updatePhotoURL(finalAvatarUrl);
      }

      // Update native client displayName settings
      if (_nameController.text.trim() != user.displayName) {
        await user.updateDisplayName(_nameController.text.trim());
      }

      // 2. Database Pipeline: Merge updated key definitions back down onto the User snapshot reference
      final Map<String, dynamic> updatedProfilePayload = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'skills': _skills,
        'avatarUrl': finalAvatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updatedProfilePayload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Profile modifications synchronized successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not modify user details: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Profile Avatar Edit Interface Component
                        Center(
                          child: GestureDetector(
                            onTap: _pickProfilePicture,
                            child: Stack(
                              children: [
                                _selectedImageFile != null
                                    ? CircleAvatar(
                                        radius: 44,
                                        backgroundImage: FileImage(_selectedImageFile!),
                                      )
                                    : CustomAvatar(
                                        name: _nameController.text,
                                        imageUrl: _currentAvatarUrl,
                                        radius: 44,
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
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        CustomTextField(
                          label: 'Name',
                          controller: _nameController,
                          prefixIcon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 16),
                        
                        CustomTextField(
                          label: 'Bio',
                          controller: _bioController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        
                        const Text(
                          'Skills',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _skills
                              .map((skill) => Chip(
                                    label: Text(skill),
                                    onDeleted: () => _removeSkill(skill),
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'Add a skill',
                                controller: _skillInputController,
                                prefixIcon: Icons.add,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addSkill,
                              icon: const Icon(Icons.add),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        CustomButton(
                          label: 'Save Changes', 
                          onPressed: _isSaving ? () {} : _saveProfile,
                        ),
                      ],
                    ),
                  ),
                  
                  // Processing Modal Shield Overlay
                  if (_isSaving)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Uploading modifications...', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
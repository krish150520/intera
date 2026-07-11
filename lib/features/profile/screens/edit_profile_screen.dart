import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/colors.dart';
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
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _hobbyInputController;
  List<String> _hobbies = [];
  String _initialUsername = '';
  
  bool _isLoading = true; // Block UI inputs while fetching initial data
  bool _isSaving = false;  // Show overlay loading spinner during save operations
  String? _currentAvatarUrl;
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _hobbyInputController = TextEditingController();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _hobbyInputController.dispose();
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
        final rawUsername = (data['username'] as String? ?? '').replaceAll('@', '');
        setState(() {
          _nameController.text = data['name'] ?? user.displayName ?? '';
          _usernameController.text = rawUsername;
          _initialUsername = rawUsername;
          _bioController.text = data['bio'] ?? '';
          _hobbies = List<String>.from(data['hobbies'] ?? data['skills'] ?? []);
          _currentAvatarUrl = data['avatarUrl'] ?? user.photoURL;
          _isLoading = false;
        });
      } else if (mounted) {
        // Fallback initialization if a Firestore profile document does not exist yet
        setState(() {
          _nameController.text = user.displayName ?? '';
          _usernameController.text = '';
          _initialUsername = '';
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

  void _addHobby() {
    final value = _hobbyInputController.text.trim();
    if (value.isEmpty || _hobbies.contains(value)) return;
    setState(() {
      _hobbies.add(value);
      _hobbyInputController.clear();
    });
  }

  void _removeHobby(String hobby) {
    setState(() => _hobbies.remove(hobby));
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

  void _showAvatarOptions() {
    final hasAvatar = _selectedImageFile != null ||
        (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subColor = isDark ? Colors.white60 : Colors.black54;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Photo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: Text('Choose from Gallery', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickProfilePicture();
                },
              ),
              if (hasAvatar)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: const Text('Remove Current Photo', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePicture();
                  },
                ),
              ListTile(
                leading: Icon(Icons.close_rounded, color: subColor),
                title: Text('Cancel', style: TextStyle(color: subColor)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _removeProfilePicture() {
    setState(() {
      _selectedImageFile = null;
      _currentAvatarUrl = null;
    });
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

    final newUsername = _usernameController.text.trim().replaceAll('@', '');
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username field cannot be left blank.')),
      );
      return;
    }
    if (newUsername.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be at least 3 characters.')),
      );
      return;
    }
    if (newUsername.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must not contain spacer items.')),
      );
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(newUsername)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username can only contain letters, numbers, and underscores.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    String step = "Checking username uniqueness";
    try {
      // Check username uniqueness if changed
      if (newUsername.toLowerCase() != _initialUsername.toLowerCase()) {
        final taken = await FirebaseFirestore.instance
            .collection('users')
            .where('usernameLower', isEqualTo: newUsername.toLowerCase())
            .limit(1)
            .get();

        if (taken.docs.isNotEmpty) {
          setState(() => _isSaving = false);
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
      }

      String? finalAvatarUrl = _currentAvatarUrl;

      // 1. Storage Pipeline: Process profile photo uploads if a new file is staged
      if (_selectedImageFile != null) {
        step = "Uploading profile image to Storage";
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${user.uid}/avatar.jpg');
        final uploadTask = storageRef.putFile(_selectedImageFile!);
        final snapshot = await uploadTask;
        finalAvatarUrl = await snapshot.ref.getDownloadURL();

        // Sync with local core FirebaseAuth instance profile settings state
        step = "Syncing profile image URL to Firebase Auth";
        await user.updatePhotoURL(finalAvatarUrl);
      } else if (_currentAvatarUrl == null) {
        // The user explicitly removed / deleted the profile picture
        // Clear photo URL in Firebase Auth
        step = "Clearing profile image in Firebase Auth";
        await user.updatePhotoURL(null);

        // Delete from Storage if it exists
        step = "Deleting profile image from Storage";
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_pictures/${user.uid}/avatar.jpg');
          await storageRef.delete();
        } catch (e) {
          // If the file does not exist, ignore the exception
          debugPrint('Storage delete ignored: $e');
        }
      }

      // Update native client displayName settings
      step = "Updating display name in Firebase Auth";
      if (_nameController.text.trim() != user.displayName) {
        await user.updateDisplayName(_nameController.text.trim());
      }

      final String resolvedUsername = '@$newUsername';
      final String resolvedUsernameLower = newUsername.toLowerCase();

      // 2. Database Pipeline: Merge updated key definitions back down onto the User snapshot reference
      step = "Saving user document to Firestore";
      final Map<String, dynamic> updatedProfilePayload = {
        'name': _nameController.text.trim(),
        'username': resolvedUsername,
        'usernameLower': resolvedUsernameLower,
        'bio': _bioController.text.trim(),
        'skills': _hobbies,
        'hobbies': _hobbies,
        'avatarUrl': finalAvatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updatedProfilePayload, SetOptions(merge: true));

      // 3. Propagate updates to user's posts in Firestore
      step = "Querying user's posts";
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: user.uid)
          .get();

      // 4. Propagate updates to user's comments in Firestore (using collectionGroup)
      step = "Querying user's comments";
      final commentsQuery = await FirebaseFirestore.instance
          .collectionGroup('comments')
          .where('authorId', isEqualTo: user.uid)
          .get();

      final List<DocumentReference> refsToUpdate = [];
      final List<Map<String, dynamic>> updates = [];

      for (var doc in postsQuery.docs) {
        refsToUpdate.add(doc.reference);
        updates.add({
          'authorAvatarUrl': finalAvatarUrl,
          'authorName': _nameController.text.trim(),
          'authorUsername': resolvedUsername,
        });
      }

      for (var doc in commentsQuery.docs) {
        refsToUpdate.add(doc.reference);
        updates.add({
          'authorAvatar': finalAvatarUrl ?? '',
          'authorName': _nameController.text.trim(),
          'authorUsername': resolvedUsername,
        });
      }

      // Commit in chunks of 400 to avoid Firestore's 500 operations batch limit
      step = "Committing batch updates to posts (${postsQuery.docs.length}) and comments (${commentsQuery.docs.length})";
      for (var i = 0; i < refsToUpdate.length; i += 400) {
        final chunkBatch = FirebaseFirestore.instance.batch();
        final end = (i + 400 < refsToUpdate.length) ? i + 400 : refsToUpdate.length;
        for (var j = i; j < end; j++) {
          chunkBatch.update(refsToUpdate[j], updates[j]);
        }
        await chunkBatch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Profile modifications synchronized successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not modify user details at step [$step]: $e'), backgroundColor: Colors.red),
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
                            onTap: _showAvatarOptions,
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
                                        userId: FirebaseAuth.instance.currentUser?.uid,
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
                          label: 'Username',
                          controller: _usernameController,
                          prefixIcon: Icons.alternate_email_rounded,
                        ),
                        const SizedBox(height: 16),
                        
                        CustomTextField(
                          label: 'Bio',
                          controller: _bioController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        
                        const Text(
                          'Hobbies',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _hobbies
                              .map((hobby) => Chip(
                                    label: Text(hobby),
                                    onDeleted: () => _removeHobby(hobby),
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'Add a hobby',
                                controller: _hobbyInputController,
                                prefixIcon: Icons.add,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addHobby,
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

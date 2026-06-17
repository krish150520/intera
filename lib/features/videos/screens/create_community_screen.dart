import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _rulesController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  File? _avatarFile;
  File? _bannerFile;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isBanner) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() {
      if (isBanner) {
        _bannerFile = File(picked.path);
      } else {
        _avatarFile = File(picked.path);
      }
    });
  }

  // FIXED: Injects SettableMetadata content headers so network decoders can read the files instantly
  Future<String?> _uploadStorageAsset(File file, String communityId, String childFolder) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('communities/$communityId/$childFolder.jpg');
          
      final SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');
      
      final uploadTask = await ref.putFile(file, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Asset drop error on storage thread: $e");
      return null;
    }
  }

  void _handleCreate() async {
    final nameText = _nameController.text.trim();
    final descText = _descController.text.trim();
    final rulesText = _rulesController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (nameText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please name your community hub!')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final String cleanDocumentId = nameText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      if (cleanDocumentId.isEmpty) {
        throw Exception('Community name must contain at least one alphanumeric character.');
      }

      final DocumentReference communityDocRef = 
          FirebaseFirestore.instance.collection('communities').doc(cleanDocumentId);

      final DocumentSnapshot existingCheck = await communityDocRef.get();
      if (existingCheck.exists) {
        throw Exception('A community hub with this name already exists! Please choose another unique title.');
      }

      // Upload files sequentially with correct metadata permissions
      String? avatarUrl;
      String? bannerUrl;

      if (_avatarFile != null) {
        avatarUrl = await _uploadStorageAsset(_avatarFile!, cleanDocumentId, 'avatar');
      }
      if (_bannerFile != null) {
        bannerUrl = await _uploadStorageAsset(_bannerFile!, cleanDocumentId, 'banner');
      }

      final payload = {
        'name': nameText,
        'searchName': nameText.toLowerCase(),
        'description': descText,
        'rules': rulesText.isNotEmpty ? rulesText : 'Be respectful to other hub members.',
        'avatarUrl': avatarUrl ?? '',
        'bannerUrl': bannerUrl ?? '',
        'creatorId': user.uid,
        'admins': [user.uid],
        'moderators': [user.uid],
        'members': [user.uid],
        'memberCount': 1,
        'isPrivate': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await communityDocRef.set(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Advanced Community Hub Established!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')), 
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Community Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isCreating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading assets and generating security layers...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner Image Picker View Slot
                  GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        image: _bannerFile != null
                            ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _bannerFile == null
                          ? const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('Add Cover Banner', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Profile Avatar Selector Row Slot
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickImage(false),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.primary.withOpacity(0.08),
                            backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                            child: _avatarFile == null
                                ? Icon(Icons.groups_rounded, size: 36, color: AppColors.primary)
                                : null,
                          ),
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  CustomTextField(
                    label: 'Community Name',
                    controller: _nameController,
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Bio / Topic Description',
                    controller: _descController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Community Guidelines & Rules',
                    controller: _rulesController,
                    maxLines: 2,
                    prefixIcon: Icons.gavel_outlined,
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    label: 'Launch Community',
                    onPressed: _handleCreate,
                  ),
                ],
              ),
            ),
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

class EditCommunityScreen extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic> currentData;

  const EditCommunityScreen({
    super.key,
    required this.communityId,
    required this.currentData,
  });

  @override
  State<EditCommunityScreen> createState() => _EditCommunityScreenState();
}

class _EditCommunityScreenState extends State<EditCommunityScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _rulesController;

  final ImagePicker _picker = ImagePicker();
  File? _avatarFile;
  File? _bannerFile;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentData['name']);
    _descController = TextEditingController(text: widget.currentData['description']);
    _rulesController = TextEditingController(text: widget.currentData['rules'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isBanner) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() {
      if (isBanner) _bannerFile = File(picked.path);
      else _avatarFile = File(picked.path);
    });
  }

  Future<String?> _uploadStorageAsset(File file, String childFolder) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('communities/${widget.communityId}/$childFolder.jpg');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  void _handleUpdate() async {
    final nameText = _nameController.text.trim();
    final descText = _descController.text.trim();
    final rulesText = _rulesController.text.trim();

    if (nameText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty!')));
      return;
    }

    setState(() => _isUpdating = true);

    try {
      String? avatarUrl = widget.currentData['avatarUrl'];
      String? bannerUrl = widget.currentData['bannerUrl'];

      if (_avatarFile != null) {
        avatarUrl = await _uploadStorageAsset(_avatarFile!, 'avatar');
      }
      if (_bannerFile != null) {
        bannerUrl = await _uploadStorageAsset(_bannerFile!, 'banner');
      }

      final Map<String, dynamic> updatePayload = {
        'name': nameText,
        'description': descText,
        'rules': rulesText,
        'avatarUrl': avatarUrl ?? '',
        'bannerUrl': bannerUrl ?? '',
      };

      await FirebaseFirestore.instance.collection('communities').doc(widget.communityId).update(updatePayload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Community Hub updated successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkBanner = widget.currentData['bannerUrl'] as String?;
    final networkAvatar = widget.currentData['avatarUrl'] as String?;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Community Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner Preview
                  GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        image: _bannerFile != null
                            ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                            : (networkBanner != null && networkBanner.isNotEmpty)
                                ? DecorationImage(image: NetworkImage(networkBanner), fit: BoxFit.cover)
                                : null,
                      ),
                      child: (_bannerFile == null && (networkBanner == null || networkBanner.isEmpty))
                          ? const Center(child: Text('Tap to change Banner', style: TextStyle(color: Colors.grey)))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Avatar Preview
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickImage(false),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary.withOpacity(0.08),
                            backgroundImage: _avatarFile != null 
                                ? FileImage(_avatarFile!) 
                                : (networkAvatar != null && networkAvatar.isNotEmpty)
                                    ? NetworkImage(networkAvatar) as ImageProvider
                                    : null,
                            child: (_avatarFile == null && (networkAvatar == null || networkAvatar.isEmpty))
                                ? Icon(Icons.groups_rounded, size: 32, color: AppColors.primary)
                                : null,
                          ),
                          const CircleAvatar(radius: 12, backgroundColor: AppColors.primary, child: Icon(Icons.edit, size: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  CustomTextField(label: 'Community Name', controller: _nameController, prefixIcon: Icons.badge_outlined),
                  const SizedBox(height: 16),
                  CustomTextField(label: 'Bio / Topic Description', controller: _descController, maxLines: 3),
                  const SizedBox(height: 16),
                  CustomTextField(label: 'Community Guidelines & Rules', controller: _rulesController, maxLines: 2, prefixIcon: Icons.gavel_outlined),
                  const SizedBox(height: 32),
                  CustomButton(label: 'Save Configuration Changes', onPressed: _handleUpdate),
                ],
              ),
            ),
    );
  }
}
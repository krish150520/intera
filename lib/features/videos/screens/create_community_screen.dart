import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});
  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _nameController  = TextEditingController();
  final _descController  = TextEditingController();
  final _rulesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _avatarFile;
  File? _bannerFile;
  bool  _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isBanner) async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() {
      if (isBanner) _bannerFile = File(picked.path);
      else          _avatarFile = File(picked.path);
    });
  }

  Future<String?> _uploadStorageAsset(
      File file, String communityId, String childFolder) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('communities/$communityId/$childFolder.jpg');
      final uploadTask =
          await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Asset upload error: $e');
      return null;
    }
  }

  void _handleCreate() async {
    final nameText  = _nameController.text.trim();
    final descText  = _descController.text.trim();
    final rulesText = _rulesController.text.trim();
    final user      = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (nameText.isEmpty) {
      _snack('Please name your community!');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final id = nameText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (id.isEmpty) throw Exception('Name must contain at least one letter or number.');

      final docRef = FirebaseFirestore.instance.collection('communities').doc(id);
      if ((await docRef.get()).exists) {
        throw Exception('A community with this name already exists. Try another title.');
      }

      final avatarUrl = _avatarFile != null
          ? await _uploadStorageAsset(_avatarFile!, id, 'avatar') : null;
      final bannerUrl = _bannerFile != null
          ? await _uploadStorageAsset(_bannerFile!, id, 'banner') : null;

      await docRef.set({
        'name':        nameText,
        'searchName':  nameText.toLowerCase(),
        'description': descText,
        'rules':       rulesText.isNotEmpty ? rulesText : 'Be respectful to other members.',
        'avatarUrl':   avatarUrl ?? '',
        'bannerUrl':   bannerUrl ?? '',
        'creatorId':   user.uid,
        'admins':      [user.uid],
        'moderators':  [user.uid],
        'members':     [user.uid],
        'memberCount': 1,
        'isPrivate':   false,
        'createdAt':   FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _snack('🎉 Community created!', color: context.appColors.success);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), color: context.appColors.error);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        foregroundColor: c.textHi,
        title: Text('New community',
            style: TextStyle(fontWeight: FontWeight.w700,
                fontSize: 17, color: c.textHi)),
      ),
      body: _isCreating
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: c.primary),
                const SizedBox(height: 16),
                Text('Creating your community…',
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
              ]),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Banner picker ──────────────────────────────────────
                  GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: c.field,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border),
                        image: _bannerFile != null
                            ? DecorationImage(
                                image: FileImage(_bannerFile!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: _bannerFile == null
                          ? Center(
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: c.textMuted, size: 20),
                                const SizedBox(width: 8),
                                Text('Add cover banner',
                                    style: TextStyle(
                                        color: c.textMuted, fontSize: 13)),
                              ]),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Avatar picker ──────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickImage(false),
                      child: Stack(alignment: Alignment.bottomRight, children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: c.primary.withValues(alpha: 0.08),
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!) : null,
                          child: _avatarFile == null
                              ? Icon(Icons.groups_rounded,
                                  size: 36, color: c.primary)
                              : null,
                        ),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: c.primary,
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Fields ─────────────────────────────────────────────
                  CustomTextField(
                    label: 'Community name',
                    controller: _nameController,
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Description',
                    controller: _descController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Community rules',
                    controller: _rulesController,
                    maxLines: 2,
                    prefixIcon: Icons.gavel_outlined,
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    label: 'Launch community',
                    onPressed: _handleCreate,
                  ),
                ],
              ),
            ),
    );
  }
}
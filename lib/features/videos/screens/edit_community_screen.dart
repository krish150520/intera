import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/app_theme.dart';
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
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _rulesController;
  final ImagePicker _picker = ImagePicker();

  File? _avatarFile;
  File? _bannerFile;
  bool  _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController  = TextEditingController(text: widget.currentData['name']);
    _descController  = TextEditingController(text: widget.currentData['description']);
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
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() {
      if (isBanner) _bannerFile = File(picked.path);
      else          _avatarFile = File(picked.path);
    });
  }

  Future<String?> _uploadStorageAsset(File file, String childFolder) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('communities/${widget.communityId}/$childFolder.jpg');
      final task = await ref.putFile(
          file, SettableMetadata(contentType: 'image/jpeg'));
      return await task.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  void _handleUpdate() async {
    final nameText  = _nameController.text.trim();
    final descText  = _descController.text.trim();
    final rulesText = _rulesController.text.trim();

    if (nameText.isEmpty) {
      _snack('Name cannot be empty.');
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final avatarUrl = _avatarFile != null
          ? await _uploadStorageAsset(_avatarFile!, 'avatar')
          : widget.currentData['avatarUrl'];
      final bannerUrl = _bannerFile != null
          ? await _uploadStorageAsset(_bannerFile!, 'banner')
          : widget.currentData['bannerUrl'];

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({
        'name':        nameText,
        'description': descText,
        'rules':       rulesText,
        'avatarUrl':   avatarUrl ?? '',
        'bannerUrl':   bannerUrl ?? '',
      });

      if (!mounted) return;
      _snack('Community updated!', color: context.appColors.success);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _snack('Update failed: $e', color: context.appColors.error);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
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
    final networkBanner = widget.currentData['bannerUrl'] as String?;
    final networkAvatar = widget.currentData['avatarUrl'] as String?;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        foregroundColor: c.textHi,
        title: Text('Edit community',
            style: TextStyle(fontWeight: FontWeight.w700,
                fontSize: 17, color: c.textHi)),
      ),
      body: _isUpdating
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Banner picker ──────────────────────────────────────
                  GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: c.field,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border),
                        image: _bannerFile != null
                            ? DecorationImage(
                                image: FileImage(_bannerFile!),
                                fit: BoxFit.cover)
                            : (networkBanner != null && networkBanner.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(networkBanner),
                                    fit: BoxFit.cover)
                                : null,
                      ),
                      child: (_bannerFile == null &&
                              (networkBanner == null || networkBanner.isEmpty))
                          ? Center(
                              child: Text('Tap to change banner',
                                  style: TextStyle(
                                      color: c.textMuted, fontSize: 13)))
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
                          radius: 40,
                          backgroundColor: c.primary.withValues(alpha: 0.08),
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!) as ImageProvider
                              : (networkAvatar != null && networkAvatar.isNotEmpty)
                                  ? NetworkImage(networkAvatar)
                                  : null,
                          child: (_avatarFile == null &&
                                  (networkAvatar == null || networkAvatar.isEmpty))
                              ? Icon(Icons.groups_rounded,
                                  size: 32, color: c.primary)
                              : null,
                        ),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: c.primary,
                          child: const Icon(Icons.edit,
                              size: 12, color: Colors.white),
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
                    label: 'Save changes',
                    onPressed: _handleUpdate,
                  ),
                ],
              ),
            ),
    );
  }
}
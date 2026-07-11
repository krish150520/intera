import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();
  
  bool _isPrivate = false;
  bool _isLoading = false; // Controls loading overlay state during upload

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _createNewCommunity() async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. BACKEND SAFETY GUARD
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create a community.')),
      );
      return;
    }

    // 2. FRONTEND VALIDATION
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your community needs a name!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3. CLOUD FIRESTORE STRUCTURED DATA WRITING
      final Map<String, dynamic> communityPayload = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'rules': _rulesController.text.trim(),
        'isPrivate': _isPrivate,
        'creatorId': user.uid,
        'memberCount': 1, // Creator is counted as the initial member
        'members': [user.uid], // Helpful array for indexing user-joined feeds later
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Writing document to Cloud Firestore
      await FirebaseFirestore.instance.collection('communities').add(communityPayload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ ${_nameController.text.trim()} Hub created!'),
          backgroundColor: Colors.indigo,
        ),
      );
      
      Navigator.of(context).pop(); // Back to your original composition workflow
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create hub space: $e'), backgroundColor: Colors.red),
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
        title: const Text('Create a Community', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Establishing ecosystem files on server...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon Header Accent
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.groups_rounded, size: 40, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Inputs Form Structure
                  CustomTextField(
                    label: 'Community Namespace (e.g., Biology 101)',
                    controller: _nameController,
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Scope / Description Statement',
                    controller: _descriptionController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Community House Rules (Optional)',
                    controller: _rulesController,
                    maxLines: 3,
                    prefixIcon: Icons.gavel_outlined,
                  ),
                  const SizedBox(height: 16),
                  
                  // Privacy Toggles Container block
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SwitchListTile(
                      title: const Text('Private Space Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Approval required from mods to view or join conversations.', style: TextStyle(fontSize: 12)),
                      value: _isPrivate,
                      activeColor: AppColors.primary,
                      onChanged: (bool value) {
                        setState(() {
                          _isPrivate = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  CustomButton(
                    label: 'Establish Hub Ecosystem',
                    onPressed: _createNewCommunity,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

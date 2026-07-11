import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/app_theme.dart';

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

  // New section local states to satisfy design specifications
  String _selectedCategory = 'Technology';
  bool _isPublic = true;
  final List<String> _tags = ['#flutter', '#coding', '#students'];
  bool _allowPostContent = true;
  bool _allowInvitePeople = true;

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
        'isPrivate':   !_isPublic,
        'chatMode':    'everyone',
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
        backgroundColor: c.bg,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textHi, size: 16),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'New Community',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c.textHi),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5E7FF), Color(0xFFF8F9FF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isCreating
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: c.primary),
                    const SizedBox(height: 16),
                    Text('Creating your space...', style: TextStyle(color: c.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, animVal, child) {
                  return Opacity(
                    opacity: animVal,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - animVal)),
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Overlapping Cover Banner & Avatar Logo ──
                      SizedBox(
                        height: 220,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            // Cover Banner
                            GestureDetector(
                              onTap: () => _pickImage(true),
                              child: Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: c.field,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  image: _bannerFile != null
                                      ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(24),
                                          gradient: LinearGradient(
                                            colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_bannerFile == null)
                                      Center(
                                        child: Text(
                                          'Tap to upload cover banner',
                                          style: TextStyle(color: c.textMuted.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    // Bottom right floating edit icon
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: _ScalePressIcon(
                                        onTap: () => _pickImage(true),
                                        icon: Icons.edit_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Logo Overlapping Avatar
                            Positioned(
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () => _pickImage(false),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Colors.purpleAccent, Colors.blueAccent],
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 42,
                                        backgroundColor: c.surface,
                                        backgroundImage: _avatarFile != null
                                            ? FileImage(_avatarFile!)
                                            : null,
                                        child: _avatarFile == null
                                            ? Icon(Icons.groups_rounded, size: 36, color: c.primary)
                                            : null,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: c.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Form Input Fields ──
                      _buildModernField(
                        label: 'Community Name',
                        hint: 'Enter space name',
                        icon: Icons.badge_outlined,
                        controller: _nameController,
                      ),
                      const SizedBox(height: 16),
                      _buildModernField(
                        label: 'Description',
                        hint: 'Tell about the community...',
                        icon: Icons.chat_bubble_outline_rounded,
                        controller: _descController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _buildModernField(
                        label: 'Rules',
                        hint: 'Community rules & guidelines',
                        icon: Icons.gavel_outlined,
                        controller: _rulesController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // ── Category Dropdown ──
                      Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textHi)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            dropdownColor: c.surface,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.primary),
                            style: TextStyle(color: c.textHi, fontSize: 14, fontWeight: FontWeight.bold),
                            onChanged: (String? val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                            items: ['Technology', 'Gaming', 'Education', 'Design', 'Other']
                                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Privacy Card Selection ──
                      _buildPrivacySection(c),
                      const SizedBox(height: 24),

                      // ── Tags Section ──
                      Text('Tags', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textHi)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _tags.map((tag) {
                          return Chip(
                            backgroundColor: c.primary.withValues(alpha: 0.08),
                            side: BorderSide(color: c.primary.withValues(alpha: 0.15)),
                            label: Text(tag, style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                            onDeleted: () {
                              setState(() => _tags.remove(tag));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ── Member settings switches ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Member Settings',
                              style: TextStyle(color: c.textHi, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            _buildSwitchRow('Allow members to post content', _allowPostContent, (val) => setState(() => _allowPostContent = val), c),
                            const SizedBox(height: 8),
                            _buildSwitchRow('Allow members to invite people', _allowInvitePeople, (val) => setState(() => _allowInvitePeople = val), c),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isCreating
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (context, val, child) {
                  final hasName = val.text.trim().isNotEmpty;
                  return _FloatingLaunchButton(
                    enabled: hasName,
                    onTap: _handleCreate,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildModernField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: c.textHi,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: c.textHi, fontSize: 14),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
              prefixIcon: Icon(icon, color: c.primary, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(AppColorsExtension c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Privacy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textHi)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPublic = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isPublic ? c.primary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPublic ? c.primary : Colors.white.withValues(alpha: 0.6),
                      width: _isPublic ? 1.5 : 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🌍 Public', style: TextStyle(fontWeight: FontWeight.bold, color: c.textHi, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Anyone can discover and join', style: TextStyle(color: c.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPublic = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !_isPublic ? c.primary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !_isPublic ? c.primary : Colors.white.withValues(alpha: 0.6),
                      width: !_isPublic ? 1.5 : 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🔒 Private', style: TextStyle(fontWeight: FontWeight.bold, color: c.textHi, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Only approved members', style: TextStyle(color: c.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged, AppColorsExtension c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: c.primary,
        ),
      ],
    );
  }
}

// ── Scale Press Icon (Floating edit pen) ──

class _ScalePressIcon extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;

  const _ScalePressIcon({required this.onTap, required this.icon});

  @override
  State<_ScalePressIcon> createState() => _ScalePressIconState();
}

class _ScalePressIconState extends State<_ScalePressIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(widget.icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

// ── Floating launch changes button ──

class _FloatingLaunchButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _FloatingLaunchButton({required this.enabled, required this.onTap});

  @override
  State<_FloatingLaunchButton> createState() => _FloatingLaunchButtonState();
}

class _FloatingLaunchButtonState extends State<_FloatingLaunchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTapDown: !widget.enabled ? null : (_) => _controller.forward(),
      onTapUp: !widget.enabled ? null : (_) => _controller.reverse(),
      onTapCancel: !widget.enabled ? null : () => _controller.reverse(),
      onTap: !widget.enabled ? null : widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: widget.enabled
                ? LinearGradient(
                    colors: [c.primary, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.enabled ? null : c.border.withValues(alpha: 0.5),
            boxShadow: [
              if (widget.enabled)
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'Launch Space',
            style: TextStyle(
              color: widget.enabled ? Colors.white : c.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

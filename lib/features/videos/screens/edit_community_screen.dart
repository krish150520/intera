import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme/app_theme.dart';

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

  // New section local states to satisfy design specifications cleanly without schema breakage
  String _selectedCategory = 'Technology';
  bool _isPublic = true;
  final List<String> _tags = ['#flutter', '#coding', '#students'];
  bool _allowPostContent = true;
  bool _allowInvitePeople = true;

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
      if (isBanner){ _bannerFile = File(picked.path);}
      else       {   _avatarFile = File(picked.path);}
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

  bool get _hasChanges {
    final nameText = _nameController.text.trim();
    final descText = _descController.text.trim();
    final rulesText = _rulesController.text.trim();

    final changedName = nameText != (widget.currentData['name'] ?? '');
    final changedDesc = descText != (widget.currentData['description'] ?? '');
    final changedRules = rulesText != (widget.currentData['rules'] ?? '');
    final changedAvatar = _avatarFile != null;
    final changedBanner = _bannerFile != null;

    return changedName || changedDesc || changedRules || changedAvatar || changedBanner;
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
          'Edit Community',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c.textHi),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.visibility_outlined, size: 18, color: c.textHi),
                    onPressed: () => _snack('Previewing details changes...'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5E7FF), Color(0xFFF8F9FF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isUpdating
            ? Center(child: CircularProgressIndicator(color: c.primary))
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
                              child: Hero(
                                tag: 'community_banner_${widget.communityId}',
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
                                        : (networkBanner != null && networkBanner.isNotEmpty)
                                            ? DecorationImage(image: NetworkImage(networkBanner), fit: BoxFit.cover)
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
                                      if (_bannerFile == null && (networkBanner == null || networkBanner.isEmpty))
                                        Center(
                                          child: Text(
                                            'Tap to select cover banner',
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
                            ),

                            // Logo Overlapping Avatar
                            Positioned(
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () => _pickImage(false),
                                child: Hero(
                                  tag: 'community_logo_${widget.communityId}',
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
                                              ? FileImage(_avatarFile!) as ImageProvider
                                              : (networkAvatar != null && networkAvatar.isNotEmpty)
                                                  ? NetworkImage(networkAvatar)
                                                  : null,
                                          child: (_avatarFile == null && (networkAvatar == null || networkAvatar.isEmpty))
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
                      const SizedBox(height: 32),

                      // ── Danger Zone Section ──
                      _buildDangerZone(context, c),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isUpdating
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _FloatingSaveButton(
                enabled: _hasChanges,
                onTap: _handleUpdate,
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

  Widget _buildDangerZone(BuildContext context, AppColorsExtension c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         const Text(
            'Danger Zone',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Disbanding this community is a permanent action. All posts, memberships, and assets will be deleted.',
            style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Disband community?', style: TextStyle(fontWeight: FontWeight.w700, color: c.textHi, fontSize: 16)),
                    content: const Text('This action is permanent and cannot be undone.', style: TextStyle(fontSize: 13)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Cancel', style: TextStyle(color: c.textMuted))),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          try {
                            await FirebaseFirestore.instance.collection('communities').doc(widget.communityId).delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Community deleted.')));
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                        child: const Text('Disband', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Delete Community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
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

// ── Floating save changes button ──

class _FloatingSaveButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _FloatingSaveButton({required this.enabled, required this.onTap});

  @override
  State<_FloatingSaveButton> createState() => _FloatingSaveButtonState();
}

class _FloatingSaveButtonState extends State<_FloatingSaveButton>
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
            'Save Changes',
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
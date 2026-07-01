import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedMedia;
  bool _isVideo = false;
  bool _isUploading = false;
  int _selectedGradientIndex = 0;

  // Muted, editorial duotones — replaces the previous bright primary-color set
  final List<_GradientPreset> _gradients = const [
    _GradientPreset('noir', Color(0xFF2C2C2E), Color(0xFF050505)),
    _GradientPreset('plum', Color(0xFF4A2545), Color(0xFF1F0F1D)),
    _GradientPreset('ink',  Color(0xFF1B2845), Color(0xFF0A0F1F)),
    _GradientPreset('clay', Color(0xFF8B5A3C), Color(0xFF3D2417)),
    _GradientPreset('sage', Color(0xFF3D4F3D), Color(0xFF1A2419)),
    _GradientPreset('dune', Color(0xFF6B5D4F), Color(0xFF2B2419)),
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool pickVideo) async {
    try {
      final XFile? file = pickVideo
          ? await _picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 15))
          : await _picker.pickImage(
              source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        setState(() {
          _selectedMedia = File(file.path);
          _isVideo = pickVideo;
        });
      }
    } catch (e) {
      _showSnack('Could not open media: $e');
    }
  }

  Future<void> _publishStory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);
    String? downloadUrl;

    try {
      String authorAvatar = user.photoURL ?? '';
      String authorName   = user.displayName ?? 'Anonymous';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          authorAvatar = userDoc.data()?['avatarUrl'] ?? authorAvatar;
          authorName   = userDoc.data()?['name'] ?? authorName;
        }
      } catch (_) {}

      if (_selectedMedia != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('stories')
            .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.${_isVideo ? 'mp4' : 'jpg'}');
        final uploadTask = await storageRef.putFile(_selectedMedia!);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('stories').add({
        'authorId':       user.uid,
        'authorName':     authorName,
        'authorAvatar':   authorAvatar,
        'mediaUrl':       downloadUrl,
        'isVideo':        _isVideo,
        'caption':        _captionController.text.trim(),
        'gradientColors': downloadUrl == null
            ? [
                _gradients[_selectedGradientIndex].start.value,
                _gradients[_selectedGradientIndex].end.value,
              ]
            : null,
        'viewedBy':   [],
        'createdAt':  FieldValue.serverTimestamp(),
        'expiresAt':  Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Story posted')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack('Failed to post story: $e');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final preset = _gradients[_selectedGradientIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground(preset)),

          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildCaptionArea()),
                _buildBottomControls(),
              ],
            ),
          ),

          if (_isUploading) _buildUploadOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground(_GradientPreset preset) {
    if (_selectedMedia != null && !_isVideo) {
      return Image.file(_selectedMedia!, fit: BoxFit.cover);
    }
    if (_selectedMedia != null && _isVideo) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 28, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Text('Video selected',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      letterSpacing: 0.2)),
            ],
          ),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [preset.start, preset.end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _CircleIconBtn(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 13, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text('Visible for 24h',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      letterSpacing: 0.1)),
            ],
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _isUploading ? null : _publishStory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Share',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildCaptionArea() {
  return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => FocusScope.of(context).unfocus(),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // SingleChildScrollView + minHeight constraint: centers normally,
        // but scrolls instead of overflowing once keyboard + long caption
        // exceed the available space.
        return SingleChildScrollView(
          reverse: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 64,
                ),
                child: IntrinsicWidth(
                  // Makes the black pill hug the text width instead of
                  // stretching edge to edge — this is the actual Insta look.
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _captionController,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      maxLength: 120,
                      cursorColor: Colors.white,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a caption',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
  

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedMedia == null) ...[
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _gradients.length,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemBuilder: (context, idx) {
                  final g = _gradients[idx];
                  final selected = idx == _selectedGradientIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGradientIndex = idx),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                colors: [g.start, g.end],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: selected
                                  ? Border.all(color: AppColors.primary, width: 2)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            g.name,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.white.withOpacity(0.35),
                              fontSize: 9,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              _MediaBtn(
                icon: Icons.image_outlined,
                label: 'Photo',
                onTap: () => _pickMedia(false),
              ),
              const SizedBox(width: 8),
              _MediaBtn(
                icon: Icons.videocam_outlined,
                label: 'Video',
                onTap: () => _pickMedia(true),
              ),
              const Spacer(),
              if (_selectedMedia != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedMedia = null;
                    _isVideo = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 14, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 5),
                        Text('Remove',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
              const SizedBox(height: 16),
              Text(
                'Posting your story',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientPreset {
  final String name;
  final Color start;
  final Color end;
  const _GradientPreset(this.name, this.start, this.end);
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MediaBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white.withOpacity(0.85)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
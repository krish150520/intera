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

class _CreateStoryScreenState extends State<CreateStoryScreen>
    with SingleTickerProviderStateMixin {
  final _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedMedia;
  bool _isVideo = false;
  bool _isUploading = false;
  int _selectedGradientIndex = 0;

  late final AnimationController _shimmerController;

  // Rich gradient presets — each has a name + two stops
  final List<_GradientPreset> _gradients = const [
    _GradientPreset('Dusk',    Color(0xFF6C63D5), Color(0xFF3B2F8F)),
    _GradientPreset('Ember',   Color(0xFFFF6B6B), Color(0xFFFF8E53)),
    _GradientPreset('Forest',  Color(0xFF11998E), Color(0xFF38EF7D)),
    _GradientPreset('Slate',   Color(0xFF2C3E50), Color(0xFF4CA1AF)),
    _GradientPreset('Rose',    Color(0xFFFC5C7D), Color(0xFF6A82FB)),
    _GradientPreset('Gold',    Color(0xFFF7971E), Color(0xFFFFD200)),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _shimmerController.dispose();
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
      if (_selectedMedia != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('stories')
            .child(
                '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.${_isVideo ? 'mp4' : 'jpg'}');
        final uploadTask = await storageRef.putFile(_selectedMedia!);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

      final storyPayload = {
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Anonymous',
        'authorAvatar': user.photoURL ?? '',
        'mediaUrl': downloadUrl,
        'isVideo': _isVideo,
        'caption': _captionController.text.trim(),
        'gradientColors': downloadUrl == null
            ? [
                _gradients[_selectedGradientIndex].start.value,
                _gradients[_selectedGradientIndex].end.value,
              ]
            : null,
        'viewedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24))),
      };

      await FirebaseFirestore.instance.collection('stories').add(storyPayload);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story posted! 🔥')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack('Failed to post story: $e');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final preset = _gradients[_selectedGradientIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────────
          Positioned.fill(child: _buildBackground(preset)),

          // ── Gradient fade at bottom for readability ──────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.75),
                  ],
                ),
              ),
            ),
          ),

          // ── Safe area content ────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildCaptionArea()),
                _buildBottomControls(preset),
              ],
            ),
          ),

          // ── Upload overlay ───────────────────────────────────
          if (_isUploading) _buildUploadOverlay(),
        ],
      ),
    );
  }

  // ── Background Layer ────────────────────────────────────────
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle_outline_rounded,
                    size: 56, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text('Video selected',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 13)),
            ],
          ),
        ),
      );
    }
    // Text-only gradient background
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

  // ── Top Bar ─────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Close button
          _CircleIconBtn(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          // 24-hour label
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined,
                    size: 13, color: Colors.white70),
                const SizedBox(width: 4),
                Text('24h',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Share button
          GestureDetector(
            onTap: _isUploading ? null : _publishStory,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Text(
                'Share',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Caption Input Area ───────────────────────────────────────
  Widget _buildCaptionArea() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: TextField(
            controller: _captionController,
            maxLines: null,
            textAlign: TextAlign.center,
            maxLength: 120,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.35,
              shadows: [
                Shadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            decoration: InputDecoration(
              hintText: 'Say something…',
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 26,
                  fontWeight: FontWeight.w600),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom Controls ──────────────────────────────────────────
  Widget _buildBottomControls(_GradientPreset preset) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient swatches (text-only mode)
          if (_selectedMedia == null) ...[
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _gradients.length,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, idx) {
                  final g = _gradients[idx];
                  final selected = idx == _selectedGradientIndex;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedGradientIndex = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: selected ? 38 : 32,
                      height: selected ? 38 : 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            LinearGradient(colors: [g.start, g.end]),
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          width: selected ? 2.5 : 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: g.start.withOpacity(0.5),
                                    blurRadius: 8)
                              ]
                            : [],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action row
          Row(
            children: [
              // Media buttons
              _MediaBtn(
                icon: Icons.image_outlined,
                label: 'Photo',
                onTap: () => _pickMedia(false),
              ),
              const SizedBox(width: 10),
              _MediaBtn(
                icon: Icons.videocam_outlined,
                label: 'Video',
                onTap: () => _pickMedia(true),
              ),

              const Spacer(),

              // Remove media
              if (_selectedMedia != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedMedia = null;
                    _isVideo = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: Colors.redAccent),
                        SizedBox(width: 5),
                        Text('Remove',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
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

  // ── Upload Overlay ───────────────────────────────────────────
  Widget _buildUploadOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 28),
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Posting your story…',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'This will only take a moment',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Supporting widgets & data classes
// ─────────────────────────────────────────────────────────────────

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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MediaBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
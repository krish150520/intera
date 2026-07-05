import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/nsfw_detection_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  CREATE SPARK SCREEN — Instagram-style
// ═══════════════════════════════════════════════════════════════════════════════

enum _SparkMode { text, photo, video }

class CreateSparkScreen extends StatefulWidget {
  const CreateSparkScreen({super.key});

  @override
  State<CreateSparkScreen> createState() => _CreateSparkScreenState();
}

class _CreateSparkScreenState extends State<CreateSparkScreen>
    with TickerProviderStateMixin {
  final _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  _SparkMode _mode = _SparkMode.text;
  File? _selectedMedia;
  bool _isVideo = false;
  bool _isUploading = false;
  int _selectedGradientIndex = 0;
  int _fontSizeIndex = 1; // 0=small, 1=medium, 2=large

  late AnimationController _modeAnimCtrl;
  late Animation<double> _modeFade;

  // ── Instagram-inspired gradient presets ────────────────────────────────────
  static const List<_GradientPreset> _gradients = [
    _GradientPreset('rainbow',  Color(0xFFFF6B6B), Color(0xFF794AEF)),
    _GradientPreset('sunset',   Color(0xFFFF9A56), Color(0xFFFF355E)),
    _GradientPreset('midnight', Color(0xFF0F2027), Color(0xFF2C5364)),
    _GradientPreset('forest',   Color(0xFF134E5E), Color(0xFF71B280)),
    _GradientPreset('ocean',    Color(0xFF2E3192), Color(0xFF1BFFFF)),
    _GradientPreset('blush',    Color(0xFFDA4453), Color(0xFF89216B)),
    _GradientPreset('neon',     Color(0xFF00F260), Color(0xFF0575E6)),
    _GradientPreset('slate',    Color(0xFF2C2C2E), Color(0xFF050505)),
  ];

  static const List<double> _fontSizes = [16, 22, 32];

  @override
  void initState() {
    super.initState();
    _modeAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _modeFade = CurvedAnimation(parent: _modeAnimCtrl, curve: Curves.easeOut);
    _modeAnimCtrl.forward();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _modeAnimCtrl.dispose();
    super.dispose();
  }

  // ── Mode switching ────────────────────────────────────────────────────────
  void _switchMode(_SparkMode mode) {
    if (mode == _mode) return;
    _modeAnimCtrl.reverse().then((_) {
      setState(() {
        _mode = mode;
        if (mode == _SparkMode.text) {
          _selectedMedia = null;
          _isVideo = false;
        }
      });
      _modeAnimCtrl.forward();
    });

    // Auto-open picker for photo/video modes
    if (mode == _SparkMode.photo) {
      _pickMedia(false);
    } else if (mode == _SparkMode.video) {
      _pickMedia(true);
    }
  }

  // ── Media picker ──────────────────────────────────────────────────────────
  Future<void> _pickMedia(bool pickVideo) async {
    final cameraStatus = await Permission.camera.status;
    final photosStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;

    if (cameraStatus.isDenied || photosStatus.isDenied || storageStatus.isDenied) {
      final statuses = await [Permission.camera, Permission.photos, Permission.storage].request();
      final isGranted = statuses[Permission.camera]?.isGranted == true ||
                        statuses[Permission.photos]?.isGranted == true ||
                        statuses[Permission.storage]?.isGranted == true;
      if (!isGranted) {
        _showSnack('Camera & photo library permissions are required to post photo/video sparks.');
        return;
      }
    }

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
          _mode = pickVideo ? _SparkMode.video : _SparkMode.photo;
        });
      }
    } catch (e) {
      _showSnack('Could not open media: $e');
    }
  }

  // ── Publish ───────────────────────────────────────────────────────────────
  Future<void> _publishSpark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final caption = _captionController.text.trim();
    if (_mode == _SparkMode.text && caption.isEmpty) {
      _showSnack('Please write something for your spark!');
      return;
    }

    setState(() => _isUploading = true);

    // ── NSFW Check ────────────────────────────────────────────────────────
    final hasNsfwText = await NsfwDetectionService.isTextNsfw(caption);
    final hasNsfwMedia = _selectedMedia != null &&
        await NsfwDetectionService.isMediaNsfw(_selectedMedia);

    if (hasNsfwText || hasNsfwMedia) {
      setState(() => _isUploading = false);
      _showNsfwWarningDialog();
      return;
    }

    String? downloadUrl;

    try {
      String authorAvatar = user.photoURL ?? '';
      String authorName = user.displayName ?? 'Anonymous';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          authorAvatar = userDoc.data()?['avatarUrl'] ?? authorAvatar;
          authorName = userDoc.data()?['name'] ?? authorName;
        }
      } catch (_) {}

      if (_selectedMedia != null) {
        final storageRef = FirebaseStorage.instance.ref().child('stories').child(
            '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.${_isVideo ? 'mp4' : 'jpg'}');
        final uploadTask = await storageRef.putFile(_selectedMedia!);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('stories').add({
        'authorId': user.uid,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'mediaUrl': downloadUrl,
        'isVideo': _isVideo,
        'caption': caption,
        'gradientColors': downloadUrl == null
            ? [
                _gradients[_selectedGradientIndex].start.value,
                _gradients[_selectedGradientIndex].end.value,
              ]
            : null,
        'viewedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack('Failed to post spark: $e');
      }
    }
  }

  void _showSuccessDialog() {
    final c = context.appColors;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1B2E).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [c.primary, c.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Spark Shared! ✨',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your followers can now view your new spark.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showNsfwWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Content Flagged',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Our safety systems detected potentially sensitive or NSFW content. '
          'Posting of this content is restricted.',
          style: TextStyle(height: 1.4, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final preset = _gradients[_selectedGradientIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────────────────────
          Positioned.fill(child: _buildBackground(preset)),

          // ── Bottom scrim ────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _modeFade,
                    child: _buildCaptionArea(),
                  ),
                ),
                _buildBottomControls(),
              ],
            ),
          ),

          // ── Upload overlay ──────────────────────────────────────────────
          if (_isUploading) _buildUploadOverlay(),
        ],
      ),
    );
  }

  // ── Background ──────────────────────────────────────────────────────────────
  Widget _buildBackground(_GradientPreset preset) {
    if (_selectedMedia != null && !_isVideo) {
      return Image.file(_selectedMedia!, fit: BoxFit.cover);
    }
    if (_selectedMedia != null && _isVideo) {
      return Container(
        color: const Color(0xFF0A0A0A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15), width: 2),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 40, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              Text('Video ready',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [preset.start, preset.end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          // Close
          _GlassCircle(
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 20),
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),

          // 24h badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded,
                    size: 12, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text('24h',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Share button
          GestureDetector(
            onTap: _isUploading ? null : _publishSpark,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isUploading
                      ? [Colors.grey.shade700, Colors.grey.shade800]
                      : [
                          context.appColors.primary,
                          context.appColors.primaryDark,
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isUploading
                    ? []
                    : [
                        BoxShadow(
                          color:
                              context.appColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Share',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white.withValues(alpha: 0.9), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Caption area ────────────────────────────────────────────────────────────
  Widget _buildCaptionArea() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            reverse: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: IntrinsicWidth(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: TextField(
                        controller: _captionController,
                        maxLines: null,
                        textAlign: TextAlign.center,
                        maxLength: 150,
                        cursorColor: Colors.white,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _fontSizes[_fontSizeIndex],
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                        decoration: InputDecoration(
                          hintText: _mode == _SparkMode.text
                              ? 'Type something...'
                              : 'Add a caption',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: _fontSizes[_fontSizeIndex],
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

  // ── Bottom controls ─────────────────────────────────────────────────────────
  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Font size selector (text mode only) ───────────────────────
          if (_mode == _SparkMode.text) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final labels = ['Aa', 'Aa', 'Aa'];
                final sizes = [12.0, 16.0, 22.0];
                final selected = _fontSizeIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _fontSizeIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      border: selected
                          ? Border.all(color: Colors.white54, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(labels[i],
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: sizes[i],
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
          ],

          // ── Gradient palette (text mode or no media) ─────────────────
          if (_mode == _SparkMode.text || _selectedMedia == null) ...[
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
                      margin: const EdgeInsets.only(right: 10),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [g.start, g.end],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: selected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: g.start.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
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

          // ── Media action row ─────────────────────────────────────────
          if (_selectedMedia != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedMedia = null;
                  _isVideo = false;
                  _mode = _SparkMode.text;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text('Remove media',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Mode switcher ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                _ModeTab(
                  icon: Icons.text_fields_rounded,
                  label: 'TEXT',
                  active: _mode == _SparkMode.text,
                  onTap: () => _switchMode(_SparkMode.text),
                ),
                _ModeTab(
                  icon: Icons.image_rounded,
                  label: 'PHOTO',
                  active: _mode == _SparkMode.photo,
                  onTap: () => _switchMode(_SparkMode.photo),
                ),
                _ModeTab(
                  icon: Icons.videocam_rounded,
                  label: 'VIDEO',
                  active: _mode == _SparkMode.video,
                  onTap: () => _switchMode(_SparkMode.video),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Upload overlay ──────────────────────────────────────────────────────────
  Widget _buildUploadOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: context.appColors.primary,
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Sharing your spark...',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('This may take a moment',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _GradientPreset {
  final String name;
  final Color start;
  final Color end;
  const _GradientPreset(this.name, this.start, this.end);
}

class _GlassCircle extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassCircle({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
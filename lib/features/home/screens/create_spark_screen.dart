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
  final List<File> _selectedFiles = [];
  final List<bool> _isVideos = [];
  bool _isUploading = false;
  int _selectedGradientIndex = 0;
  int _fontSizeIndex = 1; // 0=small, 1=medium, 2=large

  late AnimationController _modeAnimCtrl;
  late Animation<double> _modeFade;

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

  void _switchMode(_SparkMode mode) {
    if (mode == _mode) return;
    _modeAnimCtrl.reverse().then((_) {
      setState(() {
        _mode = mode;
        if (mode == _SparkMode.text) {
          _selectedFiles.clear();
          _isVideos.clear();
        }
      });
      _modeAnimCtrl.forward();
    });

    if (mode == _SparkMode.photo) {
      _pickMedia(false);
    } else if (mode == _SparkMode.video) {
      _pickMedia(true);
    }
  }

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
        _showSnack('Permissions are required to post photo/video sparks.');
        return;
      }
    }

    try {
      if (pickVideo) {
        final XFile? file = await _picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 15));
        if (file != null) {
          setState(() {
            _selectedFiles.add(File(file.path));
            _isVideos.add(true);
            _mode = _SparkMode.video;
          });
        }
      } else {
        final List<XFile> files = await _picker.pickMultiImage(imageQuality: 85);
        if (files.isNotEmpty) {
          setState(() {
            for (final f in files) {
              _selectedFiles.add(File(f.path));
              _isVideos.add(false);
            }
            _mode = _SparkMode.photo;
          });
        }
      }
    } catch (e) {
      _showSnack('Could not open media: $e');
    }
  }

  Future<void> _publishSpark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final caption = _captionController.text.trim();
    if (_selectedFiles.isEmpty && caption.isEmpty) {
      _showSnack('Please write something or select media for your spark!');
      return;
    }

    setState(() => _isUploading = true);

    final hasNsfwText = await NsfwDetectionService.isTextNsfw(caption);
    bool hasNsfwMedia = false;
    for (final file in _selectedFiles) {
      if (await NsfwDetectionService.isMediaNsfw(file)) {
        hasNsfwMedia = true;
        break;
      }
    }

    if (hasNsfwText || hasNsfwMedia) {
      setState(() => _isUploading = false);
      _showNsfwWarningDialog();
      return;
    }

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

      if (_selectedFiles.isEmpty) {
        // Text spark
        await FirebaseFirestore.instance.collection('stories').add({
          'authorId': user.uid,
          'authorName': authorName,
          'authorAvatar': authorAvatar,
          'mediaUrl': null,
          'isVideo': false,
          'caption': caption,
          'gradientColors': [
            _gradients[_selectedGradientIndex].start.value,
            _gradients[_selectedGradientIndex].end.value,
          ],
          'viewedBy': [],
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        });
      } else {
        // Multiple media sparks
        for (int i = 0; i < _selectedFiles.length; i++) {
          final file = _selectedFiles[i];
          final isVideo = _isVideos[i];

          final storageRef = FirebaseStorage.instance.ref().child('stories').child(
              '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.${isVideo ? 'mp4' : 'jpg'}');
          final uploadTask = await storageRef.putFile(file);
          final downloadUrl = await uploadTask.ref.getDownloadURL();

          await FirebaseFirestore.instance.collection('stories').add({
            'authorId': user.uid,
            'authorName': authorName,
            'authorAvatar': authorAvatar,
            'mediaUrl': downloadUrl,
            'isVideo': isVideo,
            'caption': i == 0 && caption.isNotEmpty ? caption : null,
            'gradientColors': null,
            'viewedBy': [],
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
          });
        }
      }

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
        title: const Text('Sensitive Content Detected',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Your spark contains sensitive or inappropriate content and cannot be shared.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Spark Published!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Your spark is now live for 24 hours.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // pop dialog
              Navigator.pop(context); // pop screen
            },
            child: const Text('Great',
                style: TextStyle(
                    color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preset = _gradients[_selectedGradientIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground(preset)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 340,
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
                _buildMediaCarousel(),
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
    if (_selectedFiles.isNotEmpty && !_isVideos.first) {
      return Image.file(_selectedFiles.first, fit: BoxFit.cover);
    }
    if (_selectedFiles.isNotEmpty && _isVideos.first) {
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _GlassCircle(
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 20),
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
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

  Widget _buildMediaCarousel() {
    if (_selectedFiles.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _selectedFiles.length,
        itemBuilder: (context, idx) {
          final file = _selectedFiles[idx];
          final isVid = _isVideos[idx];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 70,
                height: 70,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30, width: 1.5),
                  image: isVid
                      ? null
                      : DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                ),
                child: isVid
                    ? const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 24))
                    : null,
              ),
              Positioned(
                top: -6,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFiles.removeAt(idx);
                      _isVideos.removeAt(idx);
                      if (_selectedFiles.isEmpty) {
                        _mode = _SparkMode.text;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          if (_mode == _SparkMode.text || _selectedFiles.isEmpty) ...[
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
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedFiles.clear();
                  _isVideos.clear();
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
                      Text('Remove all media',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
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
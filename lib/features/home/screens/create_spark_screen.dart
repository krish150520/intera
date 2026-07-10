import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/nsfw_detection_service.dart';
import '../../../core/services/permission_service.dart';




enum _SparkMode { text, photo, video }
enum _TextBgStyle { none, capsule }
enum _TextAlign { left, center, right }

class CreateSparkScreen extends StatefulWidget {
  const CreateSparkScreen({super.key});

  @override
  State<CreateSparkScreen> createState() => _CreateSparkScreenState();
}

class _CreateSparkScreenState extends State<CreateSparkScreen>
    with TickerProviderStateMixin {
  final _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _textFocusNode = FocusNode();

  _SparkMode _mode = _SparkMode.text;
  final List<File> _selectedFiles = [];
  final List<bool> _isVideos = [];
  bool _isUploading = false;
  int _selectedGradientIndex = 0;
  int _fontSizeIndex = 1; // 0=small, 1=medium, 2=large
  _TextBgStyle _textBgStyle = _TextBgStyle.none;
  _TextAlign _textAlignment = _TextAlign.center;
  bool _isTextEditing = false;

  // Drag state for floating text
  Offset _textPosition = const Offset(0, 0);
  bool _textPositioned = false;
  bool _isDraggingText = false;
  bool _isNearTrash = false;

  // Toolbar
  bool _showGradientPicker = false;

  // Video preview
  VideoPlayerController? _videoPreviewController;
  final Map<String, File> _videoThumbnails = {};

  // Animations
  late AnimationController _entryCtrl;
  late Animation<double> _entryScale;
  late Animation<double> _entryFade;

  late AnimationController _modeAnimCtrl;
  late Animation<double> _modeFade;

  late AnimationController _toolbarCtrl;
  late Animation<Offset> _toolbarSlide;

  late AnimationController _bottomCtrl;
  late Animation<Offset> _bottomSlide;

  late AnimationController _gradientCtrl;
  late Animation<double> _gradientFade;

  static const List<_GradientPreset> _gradients = [
    _GradientPreset('aurora',   Color(0xFF7F00FF), Color(0xFFE100FF)),
    _GradientPreset('sunset',   Color(0xFFFF9A56), Color(0xFFFF355E)),
    _GradientPreset('midnight', Color(0xFF0F2027), Color(0xFF2C5364)),
    _GradientPreset('forest',   Color(0xFF134E5E), Color(0xFF71B280)),
    _GradientPreset('ocean',    Color(0xFF2E3192), Color(0xFF1BFFFF)),
    _GradientPreset('blush',    Color(0xFFDA4453), Color(0xFF89216B)),
    _GradientPreset('neon',     Color(0xFF00F260), Color(0xFF0575E6)),
    _GradientPreset('slate',    Color(0xFF1A1A2E), Color(0xFF16213E)),
    _GradientPreset('gold',     Color(0xFFf7971e), Color(0xFFffd200)),
    _GradientPreset('rose',     Color(0xFFf953c6), Color(0xFFb91d73)),
  ];

  static const List<double> _fontSizes = [18, 26, 38];
  static const List<String> _fontFamilies = ['Default', 'Serif', 'Mono'];
  int _fontFamilyIndex = 0;

  // ── Emoji grid data ─────────────────────────────────────────────────────────
  static const List<String> _emojiCategories = [
    'Smileys', 'Gestures', 'Hearts', 'Animals', 'Food', 'Activities', 'Objects',
  ];

  static const Map<String, List<String>> _emojis = {
    'Smileys': [
      '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','😊',
      '😇','🥰','😍','🤩','😘','😗','😋','😛','😜','🤪',
      '😎','🤓','🧐','😏','😒','😞','😔','😟','😕','🙁',
      '😣','😖','😫','😩','🥺','😢','😭','😤','😠','😡',
      '🤯','😳','🥵','🥶','😱','😨','😰','😥','🤗','🤔',
      '🫡','🤭','🫢','🫣','🤫','🤥','😶','🫠','😐','🫤',
    ],
    'Gestures': [
      '👋','🤚','🖐','✋','🖖','👌','🤌','🤏','✌️','🤞',
      '🤟','🤘','🤙','👈','👉','👆','🖕','👇','☝️','👍',
      '👎','✊','👊','🤛','🤜','👏','🙌','🫶','👐','🤲',
      '🤝','🙏','💪','🦾','🦿','🦵','🦶','👀','👁','👅',
    ],
    'Hearts': [
      '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔',
      '❤️‍🔥','❤️‍🩹','💕','💞','💓','💗','💖','💘','💝','💟',
      '♥️','💌','🫀','🫶','✨','💫','⭐','🌟','💥','🔥',
    ],
    'Animals': [
      '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐻‍❄️','🐨',
      '🐯','🦁','🐮','🐷','🐸','🐵','🙈','🙉','🙊','🐒',
      '🦄','🐝','🦋','🐌','🐞','🐜','🪲','🐢','🐍','🦎',
    ],
    'Food': [
      '🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍈',
      '🍒','🍑','🥭','🍍','🥥','🥝','🍅','🍕','🍔','🍟',
      '🌭','🌮','🌯','🥗','🍿','🧁','🍩','🍪','🎂','🍰',
    ],
    'Activities': [
      '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱',
      '🎮','🕹','🎯','🎲','🧩','🎪','🎨','🎬','🎤','🎧',
      '🎼','🎹','🥁','🎷','🎺','🎸','🪗','🎻','🎵','🎶',
    ],
    'Objects': [
      '💡','🔦','🕯','📱','💻','⌨️','🖥','🖨','📷','📸',
      '📹','🎥','📽','📀','💿','📼','🔮','🧿','🪬','🎁',
      '🎀','🎊','🎉','🎈','🏆','🥇','🥈','🥉','🏅','🎖',
    ],
  };

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _entryScale = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    _modeAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _modeFade =
        CurvedAnimation(parent: _modeAnimCtrl, curve: Curves.easeInOut);

    _toolbarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _toolbarSlide = Tween<Offset>(
            begin: const Offset(1.5, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _toolbarCtrl, curve: Curves.easeOutCubic));

    _bottomCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _bottomSlide = Tween<Offset>(
            begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _bottomCtrl, curve: Curves.easeOutCubic));

    // FIX #7: Use _gradientCtrl for gradient picker fade animation
    _gradientCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _gradientFade =
        CurvedAnimation(parent: _gradientCtrl, curve: Curves.easeInOut);

    _textFocusNode.addListener(() {
      setState(() => _isTextEditing = _textFocusNode.hasFocus);
    });

    // Staggered entry
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _toolbarCtrl.forward();
        _bottomCtrl.forward();
        _modeAnimCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _textFocusNode.dispose();
    _entryCtrl.dispose();
    _modeAnimCtrl.dispose();
    _toolbarCtrl.dispose();
    _bottomCtrl.dispose();
    _gradientCtrl.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  // ── FIX #4: Discard confirmation ─────────────────────────────────────────

  bool get _hasContent =>
      _captionController.text.trim().isNotEmpty || _selectedFiles.isNotEmpty;

  void _handleClose() {
    if (_hasContent) {
      _showDiscardDialog();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _PremiumDialog(
        icon: '🗑️',
        title: 'Discard Spark?',
        body: 'You have unsaved content. Are you sure you want to discard it?',
        action: 'Discard',
        actionColor: Colors.redAccent,
        onAction: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
        secondaryAction: 'Keep Editing',
        onSecondaryAction: () => Navigator.pop(ctx),
      ),
    );
  }

  void _switchMode(_SparkMode mode) {
    if (mode == _mode) return;
    HapticFeedback.selectionClick();
    _modeAnimCtrl.reverse().then((_) {
      setState(() {
        _mode = mode;
        if (mode == _SparkMode.text) {
          _selectedFiles.clear();
          _isVideos.clear();
          _videoPreviewController?.dispose();
          _videoPreviewController = null;
        }
      });
      _modeAnimCtrl.forward();
    });

    // FIX #5: Show camera/gallery picker
    if (mode == _SparkMode.photo) _showMediaSourcePicker(false);
    if (mode == _SparkMode.video) _showMediaSourcePicker(true);
  }

  // ── FIX #5: Camera / Gallery source picker ───────────────────────────────

  void _showMediaSourcePicker(bool isVideo) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1828).withOpacity(0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  isVideo ? 'Add Video' : 'Add Photo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MediaSourceCard(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        gradient: const [Color(0xFF9B59F5), Color(0xFF6C27C8)],
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickMedia(isVideo, fromCamera: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MediaSourceCard(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        gradient: const [Color(0xFFE100FF), Color(0xFF7F00FF)],
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickMedia(isVideo, fromCamera: false);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── MEDIA PICKING ────────────────────────────────────────────────────────

  Future<void> _pickMedia(bool pickVideo, {bool fromCamera = false}) async {
    final isGranted = fromCamera
        ? await PermissionService.requestCameraPermission(context)
        : await PermissionService.requestGalleryPermission(context);

    if (!isGranted) return;

    try {
      if (pickVideo) {
        final XFile? file = await _picker.pickVideo(
            source: fromCamera ? ImageSource.camera : ImageSource.gallery,
            maxDuration: const Duration(seconds: 15));
        if (file != null) {
          // FIX #9: Limit video to 1 file
          setState(() {
            _selectedFiles.clear();
            _isVideos.clear();
            _selectedFiles.add(File(file.path));
            _isVideos.add(true);
            _mode = _SparkMode.video;
          });
          // FIX #3: Generate video thumbnail
          await _generateVideoThumbnail(File(file.path));
          _initVideoPreview(File(file.path));
        }
      } else {
        if (fromCamera) {
          final XFile? file = await _picker.pickImage(
              source: ImageSource.camera, imageQuality: 85);
          if (file != null) {
            setState(() {
              _selectedFiles.add(File(file.path));
              _isVideos.add(false);
              _mode = _SparkMode.photo;
            });
          }
        } else {
          final List<XFile> files =
              await _picker.pickMultiImage(imageQuality: 85);
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
      }
    } catch (e) {
      _showSnack('Could not open media: $e');
    }
  }

  // ── FIX #3: Video thumbnail & preview ──────────────────────────────────

  Future<void> _generateVideoThumbnail(File videoFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );
      if (thumbnailPath != null && mounted) {
        setState(() {
          _videoThumbnails[videoFile.path] = File(thumbnailPath);
        });
      }
    } catch (e) {
      debugPrint('Could not generate video thumbnail: $e');
    }
  }

  void _initVideoPreview(File videoFile) {
    _videoPreviewController?.dispose();
    _videoPreviewController = VideoPlayerController.file(videoFile)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      })
      ..setLooping(true)
      ..setVolume(0);
  }

  void _toggleVideoPlayback() {
    if (_videoPreviewController == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (_videoPreviewController!.value.isPlaying) {
        _videoPreviewController!.pause();
      } else {
        _videoPreviewController!.play();
      }
    });
  }

  // ── PUBLISH ──────────────────────────────────────────────────────────────

  Future<void> _publishSpark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final caption = _captionController.text.trim();
    if (_selectedFiles.isEmpty && caption.isEmpty) {
      _showSnack('Write something or select media for your spark!');
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
          'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 24))),
        });
      } else {
        for (int i = 0; i < _selectedFiles.length; i++) {
          final file = _selectedFiles[i];
          final isVideo = _isVideos[i];
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('stories')
              .child(
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
            'expiresAt': Timestamp.fromDate(
                DateTime.now().add(const Duration(hours: 24))),
          });
        }
      }

      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack('Failed to post spark: $e');
      }
    }
  }

  // ── DIALOGS / SNACK ────────────────────────────────────────────────────────

  void _showSnack(String msg, {String? undoLabel, VoidCallback? onUndo}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1C1B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      action: undoLabel != null
          ? SnackBarAction(
              label: undoLabel,
              textColor: const Color(0xFF9B59F5),
              onPressed: onUndo ?? () {},
            )
          : null,
    ));
  }

  void _showNsfwWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _PremiumDialog(
        icon: '🚫',
        title: 'Sensitive Content',
        body:
            'Your spark contains content that can\'t be shared on this platform.',
        action: 'Got it',
        actionColor: Colors.redAccent,
        onAction: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PremiumDialog(
        icon: '✨',
        title: 'Spark Published!',
        body: 'Your spark is live for the next 24 hours.',
        action: 'Awesome',
        actionColor: const Color(0xFF9B59F5),
        onAction: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── FIX #2: Emoji picker ───────────────────────────────────────────────

  void _showEmojiPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _EmojiPickerSheet(
        onEmojiSelected: (emoji) {
          final text = _captionController.text;
          final selection = _captionController.selection;
          final cursorPos = selection.isValid
              ? selection.baseOffset
              : text.length;
          final newText =
              text.substring(0, cursorPos) + emoji + text.substring(cursorPos);
          _captionController.text = newText;
          _captionController.selection = TextSelection.collapsed(
            offset: cursorPos + emoji.length,
          );
          HapticFeedback.selectionClick();
          setState(() {});
        },
      ),
    );
  }

  // ── TEXT STYLE ─────────────────────────────────────────────────────────────

  TextStyle get _activeTextStyle {
    final families = [null, 'Georgia', 'Courier New'];
    return TextStyle(
      color: Colors.white,
      fontSize: _fontSizes[_fontSizeIndex],
      fontWeight: FontWeight.w700,
      fontFamily: families[_fontFamilyIndex],
      height: 1.3,
      letterSpacing: 0.2,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
      ],
    );
  }

  TextAlign get _activeTextAlign {
    switch (_textAlignment) {
      case _TextAlign.left:
        return TextAlign.left;
      case _TextAlign.center:
        return TextAlign.center;
      case _TextAlign.right:
        return TextAlign.right;
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final preset = _gradients[_selectedGradientIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: FadeTransition(
        opacity: _entryFade,
        child: ScaleTransition(
          scale: _entryScale,
          child: Stack(
            children: [
              // Background (with transition animation on mode switch)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _modeFade,
                  child: _buildBackground(preset),
                ),
              ),

              // Bottom vignette
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
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Top vignette
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 160,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating draggable text (all modes, not editing)
              if (!_isTextEditing)
                _buildFloatingText(size),

              // Text editor (when focused, all modes)
              if (_isTextEditing)
                _buildFullscreenTextEditor(size),

              // Trash Can overlay (visible when dragging text overlay)
              if (_isDraggingText && !_isTextEditing)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isNearTrash
                            ? Colors.redAccent.withOpacity(0.3)
                            : Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isNearTrash ? Colors.redAccent : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: _isNearTrash ? Colors.redAccent : Colors.white70,
                        size: _isNearTrash ? 32 : 26,
                      ),
                    ),
                  ),
                ),

              SafeArea(
                child: Stack(
                  children: [
                    // Default Top bar (only when not editing)
                    if (!_isTextEditing)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildTopBar(),
                      ),

                    // Default Right toolbar (only when not editing)
                    if (!_isTextEditing)
                      Positioned(
                        right: 12,
                        top: 80,
                        child: SlideTransition(
                          position: _toolbarSlide,
                          child: _buildRightToolbar(),
                        ),
                      ),

                    // Default Bottom controls (only when not editing)
                    if (!_isTextEditing)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SlideTransition(
                          position: _bottomSlide,
                          child: _buildBottomSection(),
                        ),
                      ),

                    // Gradient picker overlay (only when not editing)
                    if (_showGradientPicker && !_isTextEditing)
                      Positioned(
                        right: 64,
                        top: 80,
                        child: FadeTransition(
                          opacity: _gradientFade,
                          child: _buildGradientPicker(),
                        ),
                      ),

                    // Editor Top bar (only when editing)
                    if (_isTextEditing)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildEditorTopBar(),
                      ),

                    // Editor Bottom controls (only when editing, sits above keyboard)
                    if (_isTextEditing)
                      Positioned(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                        left: 0,
                        right: 0,
                        child: _buildEditorBottomBar(),
                      ),
                  ],
                ),
              ),

              // Upload overlay
              if (_isUploading) _buildUploadOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ── BACKGROUND ─────────────────────────────────────────────────────────────

  Widget _buildBackground(_GradientPreset preset) {
    // FIX #3: Show photo background
    if (_selectedFiles.isNotEmpty && !_isVideos.first) {
      return GestureDetector(
        onTap: () {
          if (!_isTextEditing) {
            _textFocusNode.requestFocus();
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Image.file(
            _selectedFiles.first,
            key: ValueKey(_selectedFiles.first.path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }

    // FIX #3: Show video thumbnail or player as background
    if (_selectedFiles.isNotEmpty && _isVideos.first) {
      final thumbnail = _videoThumbnails[_selectedFiles.first.path];
      final hasInitialized =
          _videoPreviewController?.value.isInitialized ?? false;

      return GestureDetector(
        onTap: () {
          if (!_isTextEditing) {
            _toggleVideoPlayback();
          }
        },
        onDoubleTap: () {
          if (!_isTextEditing) {
            _textFocusNode.requestFocus();
          }
        },
        child: Container(
          color: const Color(0xFF080810),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Show video player if initialized, otherwise thumbnail
              if (hasInitialized &&
                  _videoPreviewController!.value.isPlaying)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoPreviewController!.value.size.width,
                    height: _videoPreviewController!.value.size.height,
                    child: VideoPlayer(_videoPreviewController!),
                  ),
                )
              else if (thumbnail != null)
                Image.file(
                  thumbnail,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              else
                const SizedBox.shrink(),

              // Play/pause overlay
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (_videoPreviewController?.value.isPlaying ?? false)
                      ? 0.0
                      : 1.0,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7F00FF).withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 38, color: Colors.white),
                  ),
                ),
              ),

              // Video duration chip
              if (hasInitialized)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded,
                            size: 12, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(
                              _videoPreviewController!.value.duration),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Animated gradient for text mode
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ── FIX #10: FLOATING TEXT ─────────────────────────────────────────────────

  Widget _buildFloatingText(Size size) {
    final caption = _captionController.text;
    if (caption.isEmpty) {
      // In media mode, don't show "Tap to type" on top of photo/video so they stay clean
      if (_mode != _SparkMode.text) {
        return const SizedBox.shrink();
      }
      // Tap to type placeholder (text mode only)
      return Positioned(
        top: size.height * 0.35,
        left: 0,
        right: 0,
        child: GestureDetector(
          onTap: () {
            setState(() => _textPositioned = false);
            _textFocusNode.requestFocus();
          },
          child: Center(
            child: Text(
              'Tap to type…',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: _fontSizes[_fontSizeIndex],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                shadows: const [
                  Shadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Use center-aligned Positioned + Transform for proper centering
    final dy =
        _textPositioned ? _textPosition.dy : size.height * 0.35;
    final dx =
        _textPositioned ? _textPosition.dx : size.width / 2;

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDraggingText = true;
          });
        },
        onPanUpdate: (details) {
          final trashCenter = Offset(size.width / 2, size.height - 150);
          final currentPos = Offset(
            (_textPositioned ? _textPosition.dx : size.width / 2) + details.delta.dx,
            (_textPositioned ? _textPosition.dy : size.height * 0.35) + details.delta.dy,
          );
          final distance = (currentPos - trashCenter).distance;

          setState(() {
            _textPositioned = true;
            _textPosition = currentPos.clamp(
              const Offset(20, 60),
              Offset(size.width - 20, size.height - 100),
            );
            _isNearTrash = distance < 90;
          });
        },
        onPanEnd: (details) {
          if (_isNearTrash) {
            HapticFeedback.heavyImpact();
            setState(() {
              _captionController.clear();
              _textPositioned = false;
            });
            _showSnack('Text deleted');
          }
          setState(() {
            _isDraggingText = false;
            _isNearTrash = false;
          });
        },
        onTap: () => _textFocusNode.requestFocus(),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: dy - 30,
              child: _textPositioned
                  ? Transform.translate(
                      offset: Offset(dx - size.width / 2, 0),
                      child: Center(child: _buildTextBubble(caption)),
                    )
                  : Center(child: _buildTextBubble(caption)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBubble(String text) {
    final textWidget = Text(
      text,
      textAlign: _activeTextAlign,
      style: _activeTextStyle,
    );

    if (_textBgStyle == _TextBgStyle.capsule) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(32),
        ),
        child: textWidget,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: textWidget,
    );
  }

  // ── FULLSCREEN TEXT EDITOR (all modes) ─────────────────────────────────────

  Widget _buildFullscreenTextEditor(Size size) {
    return Container(
      color: Colors.black.withOpacity(0.55), // Dim the image/video/gradient
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _textFocusNode.unfocus(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: IntrinsicWidth(
              child: TextField(
                controller: _captionController,
                focusNode: _textFocusNode,
                maxLines: null,
                maxLength: 150,
                textAlign: _activeTextAlign,
                cursorColor: Colors.white,
                style: _activeTextStyle,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Type something…',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: _fontSizes[_fontSizeIndex],
                    fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildEditorTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Emoji button (insert emoji directly while typing!)
          _GlassBtn(
            onTap: _showEmojiPicker,
            child: const Icon(Icons.emoji_emotions_outlined,
                color: Colors.white, size: 20),
          ),
          
          // Center: Quick styling icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Font family toggle
              _GlassBtn(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _fontFamilyIndex =
                        (_fontFamilyIndex + 1) % _fontFamilies.length;
                  });
                },
                child: Text(
                  _fontFamilies[_fontFamilyIndex].substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Align toggle
              _GlassBtn(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    final idx = _TextAlign.values.indexOf(_textAlignment);
                    _textAlignment =
                        _TextAlign.values[(idx + 1) % _TextAlign.values.length];
                  });
                },
                child: Icon(
                  _textAlignment == _TextAlign.left
                      ? Icons.format_align_left_rounded
                      : _textAlignment == _TextAlign.center
                          ? Icons.format_align_center_rounded
                          : Icons.format_align_right_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),

              // Background capsule toggle
              _GlassBtn(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _textBgStyle = _textBgStyle == _TextBgStyle.none
                        ? _TextBgStyle.capsule
                        : _TextBgStyle.none;
                  });
                },
                child: Icon(
                  _textBgStyle == _TextBgStyle.none
                      ? Icons.text_fields_rounded
                      : Icons.label_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),

          // Right: Done button
          GestureDetector(
            onTap: () => _textFocusNode.unfocus(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFontSizeRow(),
      ],
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          // FIX #4: Use _handleClose instead of direct pop
          _GlassBtn(
            onTap: _handleClose,
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 20),
          ),
          const Spacer(),

          // 24h pill — subtle
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded,
                    size: 11,
                    color: Colors.white.withOpacity(0.45)),
                const SizedBox(width: 3),
                Text('24h',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Share button
          GestureDetector(
            onTapDown: (_) => HapticFeedback.lightImpact(),
            onTap: _isUploading ? null : _publishSpark,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                gradient: _isUploading
                    ? const LinearGradient(
                        colors: [Color(0xFF444444), Color(0xFF333333)])
                    : const LinearGradient(
                        colors: [Color(0xFF9B59F5), Color(0xFF6C27C8)],
                      ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: _isUploading
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF9B59F5).withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Share',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      )),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── RIGHT TOOLBAR ──────────────────────────────────────────────────────────

  Widget _buildRightToolbar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolbarBtn(
          label: 'Aa',
          isText: true,
          onTap: () {
            HapticFeedback.selectionClick();
            _textFocusNode.requestFocus();
          },
        ),
        const SizedBox(height: 14),

        // Gradient picker (only in text mode)
        if (_mode == _SparkMode.text) ...[
          _ToolbarBtn(
            icon: Icons.palette_outlined,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showGradientPicker = !_showGradientPicker);
              // FIX #7: Animate gradient picker
              if (_showGradientPicker) {
                _gradientCtrl.forward();
              } else {
                _gradientCtrl.reverse();
              }
            },
            active: _showGradientPicker,
          ),
          const SizedBox(height: 14),
        ],

        _ToolbarBtn(
          icon: Icons.format_align_center_rounded,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              final idx = _TextAlign.values.indexOf(_textAlignment);
              _textAlignment =
                  _TextAlign.values[(idx + 1) % _TextAlign.values.length];
            });
          },
        ),
        const SizedBox(height: 14),
        _ToolbarBtn(
          icon: _textBgStyle == _TextBgStyle.none
              ? Icons.text_fields_rounded
              : Icons.label_rounded,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _textBgStyle = _textBgStyle == _TextBgStyle.none
                  ? _TextBgStyle.capsule
                  : _TextBgStyle.none;
            });
          },
          active: _textBgStyle == _TextBgStyle.capsule,
        ),
        const SizedBox(height: 14),
        // FIX #2: Emoji picker button
        _ToolbarBtn(
          icon: Icons.emoji_emotions_outlined,
          onTap: _showEmojiPicker,
        ),

        // Add more media (photo mode only)
        if (_mode == _SparkMode.photo) ...[
          const SizedBox(height: 14),
          _ToolbarBtn(
            icon: Icons.add_photo_alternate_outlined,
            onTap: () => _showMediaSourcePicker(false),
          ),
        ],
      ],
    );
  }

  // ── GRADIENT PICKER ────────────────────────────────────────────────────────

  Widget _buildGradientPicker() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_gradients.length, (idx) {
              final g = _gradients[idx];
              final selected = idx == _selectedGradientIndex;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedGradientIndex = idx;
                    _showGradientPicker = false;
                  });
                  _gradientCtrl.reverse();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [g.start, g.end],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color:
                          selected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: g.start.withOpacity(0.6),
                              blurRadius: 10,
                            )
                          ]
                        : [],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── BOTTOM SECTION ─────────────────────────────────────────────────────────

  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Media carousel (when files selected)
        if (_selectedFiles.isNotEmpty) _buildMediaCarousel(),

        const SizedBox(height: 16),

        // Mode switcher
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: _buildModeSwitcher(),
        ),
      ],
    );
  }

  Widget _buildFontSizeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final sizes = [12.0, 16.0, 22.0];
          final selected = _fontSizeIndex == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _fontSizeIndex = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.07),
                border: selected
                    ? Border.all(
                        color: Colors.white.withOpacity(0.6), width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text('Aa',
                    style: TextStyle(
                      color:
                          selected ? Colors.white : Colors.white54,
                      fontSize: sizes[i],
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMediaCarousel() {
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
        // FIX #9: No "add more" for video mode (limit 1 video)
        itemCount: _mode == _SparkMode.video
            ? _selectedFiles.length
            : _selectedFiles.length + 1,
        itemBuilder: (context, idx) {
          // "Add more" button (photo mode only)
          if (_mode != _SparkMode.video && idx == _selectedFiles.length) {
            return GestureDetector(
              onTap: () => _showMediaSourcePicker(false),
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                      style: BorderStyle.solid),
                  color: Colors.white.withOpacity(0.06),
                ),
                child: Icon(Icons.add_rounded,
                    color: Colors.white.withOpacity(0.6), size: 26),
              ),
            );
          }

          final file = _selectedFiles[idx];
          final isVid = _isVideos[idx];
          final thumbnail = isVid ? _videoThumbnails[file.path] : null;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.25), width: 1.5),
                  // FIX #3: Show video thumbnail in carousel
                  image: isVid
                      ? (thumbnail != null
                          ? DecorationImage(
                              image: FileImage(thumbnail), fit: BoxFit.cover)
                          : null)
                      : DecorationImage(
                          image: FileImage(file), fit: BoxFit.cover),
                  color: isVid && thumbnail == null ? Colors.black54 : null,
                ),
                child: isVid
                    ? Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 16),
                        ),
                      )
                    : null,
              ),
              Positioned(
                top: -5,
                right: 2,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // Save removed item for undo
                    final removedFile = _selectedFiles[idx];
                    final removedIsVideo = _isVideos[idx];
                    setState(() {
                      _selectedFiles.removeAt(idx);
                      _isVideos.removeAt(idx);
                      if (_selectedFiles.isEmpty) {
                        _mode = _SparkMode.text;
                        _videoPreviewController?.dispose();
                        _videoPreviewController = null;
                      }
                    });
                    // Show undo snackbar
                    _showSnack(
                      'Media removed',
                      undoLabel: 'Undo',
                      onUndo: () {
                        setState(() {
                          _selectedFiles.insert(
                              idx.clamp(0, _selectedFiles.length), removedFile);
                          _isVideos.insert(
                              idx.clamp(0, _isVideos.length), removedIsVideo);
                          if (removedIsVideo) {
                            _mode = _SparkMode.video;
                            _initVideoPreview(removedFile);
                          } else {
                            _mode = _SparkMode.photo;
                          }
                        });
                      },
                    );
                  },
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 11, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              _ModeTab2(
                label: 'TEXT',
                active: _mode == _SparkMode.text,
                onTap: () => _switchMode(_SparkMode.text),
              ),
              _ModeTab2(
                label: 'PHOTO',
                active: _mode == _SparkMode.photo,
                onTap: () => _switchMode(_SparkMode.photo),
              ),
              _ModeTab2(
                label: 'VIDEO',
                active: _mode == _SparkMode.video,
                onTap: () => _switchMode(_SparkMode.video),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UPLOAD OVERLAY ─────────────────────────────────────────────────────────

  Widget _buildUploadOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      color: const Color(0xFF9B59F5),
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Sharing your spark…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 6),
                  Text('Just a moment',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── HELPER WIDGETS ─────────────────────────────────────────────────────────

// Extension to clamp Offset values
extension _OffsetClamp on Offset {
  Offset clamp(Offset min, Offset max) {
    return Offset(
      dx.clamp(min.dx, max.dx),
      dy.clamp(min.dy, max.dy),
    );
  }
}

class _PremiumDialog extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final String action;
  final Color actionColor;
  final VoidCallback onAction;
  final String? secondaryAction;
  final VoidCallback? onSecondaryAction;

  const _PremiumDialog({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.actionColor,
    required this.onAction,
    this.secondaryAction,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1828).withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 14),
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    )),
                const SizedBox(height: 10),
                Text(body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 14,
                      height: 1.5,
                    )),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: actionColor.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text(action,
                          style: TextStyle(
                            color: actionColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          )),
                    ),
                  ),
                ),
                if (secondaryAction != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onSecondaryAction,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Center(
                        child: Text(secondaryAction!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            )),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border:
                  Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool isText;
  final bool active;
  final VoidCallback onTap;

  const _ToolbarBtn({
    this.icon,
    this.label,
    this.isText = false,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withOpacity(0.22)
                  : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: active
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white.withOpacity(0.12),
              ),
            ),
            child: Center(
              child: isText
                  ? Text(label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ))
                  : Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTab2 extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeTab2({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF9B59F5), Color(0xFF6C27C8)],
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF9B59F5).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
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

// ── FIX #5: Media source card widget ──────────────────────────────────────

class _MediaSourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _MediaSourceCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.map((c) => c.withOpacity(0.2)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gradient.first.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: gradient),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FIX #2: Emoji picker bottom sheet ──────────────────────────────────────

class _EmojiPickerSheet extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;

  const _EmojiPickerSheet({required this.onEmojiSelected});

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final categoryName =
        _CreateSparkScreenState._emojiCategories[_selectedCategoryIndex];
    final emojis =
        _CreateSparkScreenState._emojis[categoryName] ?? [];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.45,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1828).withOpacity(0.95),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Category tabs
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount:
                      _CreateSparkScreenState._emojiCategories.length,
                  itemBuilder: (context, idx) {
                    final selected = idx == _selectedCategoryIndex;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategoryIndex = idx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF9B59F5).withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF9B59F5).withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          _CreateSparkScreenState
                              ._emojiCategories[idx],
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Emoji grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, idx) {
                    return GestureDetector(
                      onTap: () => widget.onEmojiSelected(emojis[idx]),
                      child: Center(
                        child: Text(
                          emojis[idx],
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/nsfw_detection_service.dart';
import '../../navigation/screens/bottom_nav_screen.dart';
import 'create_audio_screen.dart';

class CreateEchoScreen extends StatefulWidget {
  final String? audioId;
  final String? audioTitle;
  final String? audioAuthorId;

  const CreateEchoScreen({
    super.key,
    this.audioId,
    this.audioTitle,
    this.audioAuthorId,
  });

  @override
  State<CreateEchoScreen> createState() => _CreateEchoScreenState();
}

class _CreateEchoScreenState extends State<CreateEchoScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedVideoFile;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  File? _autoThumbnailFile;
  File? _customThumbnailFile;
  File? _customAudioFile;
  String? _customAudioFileName;
  File? _customAudioCoverFile;
  String? _customAudioTitle;
  String? _selectedExistingAudioId;
  String? _selectedExistingAudioTitle;
  String? _selectedExistingAudioAuthorId;
  String? _selectedExistingAudioUrl;

  void _removeExistingAudio() {
    setState(() {
      _selectedExistingAudioId = null;
      _selectedExistingAudioTitle = null;
      _selectedExistingAudioAuthorId = null;
      _selectedExistingAudioUrl = null;
    });
  }

  final Set<String> _selectedTags = {};
  String? _selectedCategory; // 'beauty', 'art', 'funny'

  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animCtrl.forward();

    // Auto trigger picker if no video is selected yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickVideo();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    _videoController?.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      await _videoController?.dispose();
      setState(() {
        _selectedVideoFile = File(file.path);
        _autoThumbnailFile = null;
        _customThumbnailFile = null;
      });

      _videoController = VideoPlayerController.file(_selectedVideoFile!)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        });

      _generateAutoThumbnail();
    }
  }

  Future<void> _pickCustomThumbnail() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _customThumbnailFile = File(file.path);
      });
    }
  }

  Future<void> _pickCustomAudio() async {
    try {
      final result = await Navigator.of(context).pushNamed(AppRoutes.createAudio);
      if (result is AudioCreationResult) {
        setState(() {
          _customAudioFile = result.audioFile;
          _customAudioFileName = result.audioFile.path.split('/').last.split('\\').last;
          _customAudioCoverFile = result.coverFile;
          _customAudioTitle = result.title;

          // Clear selected existing audio if any
          _selectedExistingAudioId = null;
          _selectedExistingAudioTitle = null;
          _selectedExistingAudioAuthorId = null;
          _selectedExistingAudioUrl = null;
        });
      }
    } catch (e) {
      _snack('Error opening audio creator: $e');
    }
  }

  void _removeCustomAudio() {
    setState(() {
      _customAudioFile = null;
      _customAudioFileName = null;
      _customAudioCoverFile = null;
      _customAudioTitle = null;
    });
  }

  Future<void> _generateAutoThumbnail() async {
    if (_selectedVideoFile == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final path = await VideoThumbnail.thumbnailFile(
        video: _selectedVideoFile!.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 360,
        quality: 75,
      );
      if (path != null) {
        setState(() {
          _autoThumbnailFile = File(path);
        });
      }
    } catch (e) {
      debugPrint('Error generating auto thumbnail: $e');
    }
  }

  void _addTag(String tag) {
    final clean = tag.trim().toLowerCase().replaceAll('#', '');
    if (clean.isNotEmpty && _selectedTags.length < 5) {
      setState(() {
        _selectedTags.add(clean);
        _tagController.clear();
      });
    }
  }

  void _submitEcho() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('You must be logged in.');
      return;
    }

    if (_selectedVideoFile == null) {
      _snack('Please select a video for your Echo!');
      return;
    }

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      _snack('Please add a title for your Echo.');
      return;
    }

    setState(() => _isLoading = true);

    // ── NSFW Check ──────────────────────────────────────────────────────
    final hasNsfwText = await NsfwDetectionService.isTextNsfw(title) ||
        await NsfwDetectionService.isTextNsfw(body);
    final hasNsfwMedia =
        await NsfwDetectionService.isMediaNsfw(_selectedVideoFile);

    if (hasNsfwText || hasNsfwMedia) {
      setState(() => _isLoading = false);
      _showNsfwWarning();
      return;
    }

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;

      // Upload Video
      final videoRef =
          FirebaseStorage.instance.ref('posts/videos/${user.uid}_$ts.mp4');
      final videoTask =
          await videoRef.putFile(_selectedVideoFile!).whenComplete(() {});
      if (videoTask.state != TaskState.success)
        throw Exception('Video upload failed');
      final videoUrl = await videoRef.getDownloadURL();

      // Upload Thumbnail (Custom or Auto)
      String? thumbnailUrl;
      final thumbnailToUpload = _customThumbnailFile ?? _autoThumbnailFile;
      if (thumbnailToUpload != null) {
        final thumbRef = FirebaseStorage.instance
            .ref('posts/thumbnails/${user.uid}_$ts.jpg');
        final thumbTask =
            await thumbRef.putFile(thumbnailToUpload).whenComplete(() {});
        if (thumbTask.state == TaskState.success) {
          thumbnailUrl = await thumbRef.getDownloadURL();
        }
      }

      // Fetch user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final ud = userDoc.data() ?? {};
      final displayName = ud['name'] ?? user.displayName ?? 'Anonymous';
      final rawUsername = ud['username'] ?? user.email?.split('@')[0] ?? 'user';
      final username =
          rawUsername.startsWith('@') ? rawUsername : '@$rawUsername';
      final avatarUrl =
          ud['profileImageUrl'] ?? ud['photoURL'] ?? user.photoURL ?? '';

      // Prepare Audio info
      String? audioId = widget.audioId ?? _selectedExistingAudioId;
      String? audioTitle = widget.audioTitle ?? _selectedExistingAudioTitle;
      String? audioAuthorId = widget.audioAuthorId ?? _selectedExistingAudioAuthorId;
      String? resolvedAudioUrl = _selectedExistingAudioUrl;

      final postRef = FirebaseFirestore.instance.collection('posts').doc();

      if (audioId == null) {
        final newAudioRef = FirebaseFirestore.instance.collection('audios').doc();
        audioId = newAudioRef.id;
        audioAuthorId = user.uid;
        String? audioCoverUrl;

        if (_customAudioFile != null) {
          final audioExt = _customAudioFile!.path.split('.').last;
          final audioStorageRef = FirebaseStorage.instance.ref('posts/audios/${user.uid}_$ts.$audioExt');
          final audioUploadTask = await audioStorageRef.putFile(_customAudioFile!).whenComplete(() {});
          if (audioUploadTask.state != TaskState.success) throw Exception('Audio upload failed');
          resolvedAudioUrl = await audioStorageRef.getDownloadURL();
          
          audioTitle = _customAudioTitle ?? (title.isNotEmpty ? title : 'Original audio · $username');

          if (_customAudioCoverFile != null) {
            final coverRef = FirebaseStorage.instance.ref('posts/audio_covers/${user.uid}_$ts.jpg');
            final coverTask = await coverRef.putFile(_customAudioCoverFile!).whenComplete(() {});
            if (coverTask.state == TaskState.success) {
              audioCoverUrl = await coverRef.getDownloadURL();
            }
          }
          audioCoverUrl ??= thumbnailUrl;
        } else {
          resolvedAudioUrl = videoUrl;
          audioTitle = title.isNotEmpty ? 'Original audio · $title' : 'Original audio · $username';
          audioCoverUrl = thumbnailUrl;
        }

        await newAudioRef.set({
          'title': audioTitle,
          'audioUrl': resolvedAudioUrl,
          'authorId': audioAuthorId,
          'authorUsername': username,
          'originalPostId': postRef.id,
          'echoCount': 1,
          'coverUrl': audioCoverUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Reuse audio, increment use count
        final audioDoc = await FirebaseFirestore.instance.collection('audios').doc(audioId).get();
        final audioData = audioDoc.data() ?? {};
        resolvedAudioUrl = audioData['audioUrl'] as String? ?? resolvedAudioUrl;
        audioTitle = audioData['title'] as String? ?? audioTitle;
        audioAuthorId = audioData['authorId'] as String? ?? audioAuthorId;

        await FirebaseFirestore.instance
            .collection('audios')
            .doc(audioId)
            .update({
          'echoCount': FieldValue.increment(1),
        });
      }

      final tagsList = _selectedTags.toList();
      if (_selectedCategory != null) {
        tagsList.add(_selectedCategory!);
      }

      final post = Post(
        id: postRef.id,
        authorId: user.uid,
        authorName: displayName,
        authorUsername: username,
        authorAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        type: PostType.video,
        title: title,
        body: body,
        content: '$title\n$body',
        imageUrl: videoUrl,
        videoThumbnailUrl: thumbnailUrl,
        audioId: audioId,
        audioTitle: audioTitle,
        audioAuthorId: audioAuthorId,
        audioUrl: resolvedAudioUrl,
        likeCount: 0,
        commentCount: 0,
        shareCount: 0,
        tags: tagsList,
        createdAt: DateTime.now(),
      );

      final payload = post.toFirestore();
      // Remove placeholder ID key from doc payload since Firestore generates ID
      payload.remove('id');

      await postRef.set(payload);

      // Save tags globally
      for (final tag in _selectedTags) {
        final cleanTag = tag.toLowerCase().trim();
        if (cleanTag.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('tags')
              .doc(cleanTag)
              .set({
            'name': cleanTag,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (!mounted) return;
      _snack('🎉 Echo posted successfully!', color: const Color(0xFF388E3C));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        _snack('Failed to create Echo: $e', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  void _showNsfwWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 10),
            const Text('Content Flagged'),
          ],
        ),
        content: const Text(
          'Our safety systems have detected potentially sensitive or NSFW content in your Echo text or video. '
          'Please ensure your post follows community guidelines.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new_rounded, color: c.textHi, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create Echo',
          style: TextStyle(
            color: c.textHi,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _PublishButton(
              onTap: _isLoading ? null : _submitEcho,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoader()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Video & Thumbnail Picker Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video Preview
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video File',
                              style: TextStyle(
                                color: c.textHi,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildVideoCard(c),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Thumbnail
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cover Thumbnail',
                              style: TextStyle(
                                color: c.textHi,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildThumbnailCard(c),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Audio Track Info Badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.border.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.music_note_rounded, color: c.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Audio Track',
                                    style: TextStyle(
                                      color: c.textHi,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.audioId == null
                                        ? (_selectedExistingAudioId != null
                                            ? 'Existing Audio: ${_selectedExistingAudioTitle}'
                                            : (_customAudioFile != null
                                                ? 'Custom Audio: ${_customAudioFileName}'
                                                : 'Original audio (generated from your video)'))
                                        : widget.audioTitle ?? 'Using selected audio track',
                                    style: TextStyle(
                                      color: (_customAudioFile != null || _selectedExistingAudioId != null) ? c.primary : c.textMuted,
                                      fontSize: 12,
                                      fontWeight: (_customAudioFile != null || _selectedExistingAudioId != null) ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.audioId == null && (_customAudioFile != null || _selectedExistingAudioId != null))
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
                                onPressed: () {
                                  _removeCustomAudio();
                                  _removeExistingAudio();
                                },
                                tooltip: 'Remove custom audio',
                              ),
                          ],
                        ),
                        if (widget.audioId == null && _customAudioFile == null && _selectedExistingAudioId == null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _pickCustomAudio,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: c.field,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: c.border.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.upload_file_rounded, color: c.primary, size: 14),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Upload File',
                                          style: TextStyle(
                                            color: Color(0xFF8870EE),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showAudioSearchSheet,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: c.field,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: c.border.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_rounded, color: c.primary, size: 14),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Search Audio',
                                          style: TextStyle(
                                            color: Color(0xFF8870EE),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Caption
                  Card(
                    color: c.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: c.border.withValues(alpha: 0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleController,
                            style: TextStyle(
                                color: c.textHi,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Give your Echo a catchy title...',
                              hintStyle:
                                  TextStyle(color: c.textMuted, fontSize: 15),
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(height: 20),
                          TextField(
                            controller: _bodyController,
                            maxLines: 4,
                            style: TextStyle(color: c.textHi, fontSize: 13),
                            decoration: InputDecoration(
                              hintText:
                                  'Add a description or caption (optional)...',
                              hintStyle:
                                  TextStyle(color: c.textMuted, fontSize: 13),
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Leaderboard Categories Selection
                  _buildExpansionCard(
                    title: 'Leaderboard Category (Optional)',
                    icon: Icons.emoji_events_outlined,
                    c: c,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCategoryChip('beauty', '💅 Beauty', c),
                        _buildCategoryChip('art', '🎨 Art', c),
                        _buildCategoryChip('funny', '😂 Funny', c),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tag input
                  _buildExpansionCard(
                    title: 'Tags (Max 5)',
                    icon: Icons.tag_rounded,
                    c: c,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _tagController,
                          style: TextStyle(color: c.textHi, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type tag and press enter...',
                            hintStyle:
                                TextStyle(color: c.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: c.field,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.add_circle_outline_rounded,
                                  color: c.primary),
                              onPressed: () => _addTag(_tagController.text),
                            ),
                          ),
                          onSubmitted: _addTag,
                        ),
                        if (_selectedTags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedTags.map((tag) {
                              return Chip(
                                label: Text('#$tag'),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () {
                                  setState(() => _selectedTags.remove(tag));
                                },
                                backgroundColor:
                                    c.primary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                    color: c.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              );
                            }).toList(),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildVideoCard(AppColorsExtension c) {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: c.border.withValues(alpha: 0.5), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: _selectedVideoFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  if (_videoController != null &&
                      _videoController!.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(Icons.replay_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_camera_back_outlined,
                      size: 32, color: c.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to select video',
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildThumbnailCard(AppColorsExtension c) {
    final imageFile = _customThumbnailFile ?? _autoThumbnailFile;

    return GestureDetector(
      onTap: _pickCustomThumbnail,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: c.border.withValues(alpha: 0.5), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(imageFile, fit: BoxFit.cover),
                  if (_customThumbnailFile != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Custom',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  Container(
                    color: Colors.black12,
                    child: const Center(
                      child: Icon(Icons.edit_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_outlined, size: 32, color: c.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'No Thumbnail yet',
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCategoryChip(String catId, String label, AppColorsExtension c) {
    final isSelected = _selectedCategory == catId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = isSelected ? null : catId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.primary.withValues(alpha: 0.15) : c.field,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? c.primary : c.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? c.primary : c.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionCard({
    required String title,
    required IconData icon,
    required AppColorsExtension c,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: c.textHi,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildLoader() {
    final c = context.appColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: c.primary),
          const SizedBox(height: 16),
          Text(
            'Uploading Echo post safely...',
            style: TextStyle(
                color: c.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showAudioSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AudioSearchSheet(
          onSelect: (audioId, title, authorId, url) {
            setState(() {
              _selectedExistingAudioId = audioId;
              _selectedExistingAudioTitle = title;
              _selectedExistingAudioAuthorId = authorId;
              _selectedExistingAudioUrl = url;

              // Clear custom audio if any
              _customAudioFile = null;
              _customAudioFileName = null;
            });
          },
        );
      },
    );
  }
}

class _PublishButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _PublishButton({required this.onTap});

  @override
  State<_PublishButton> createState() => _PublishButtonState();
}

class _PublishButtonState extends State<_PublishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    const buttonColor = Color(0xFF8870EE);

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => _controller.animateTo(0.94, curve: Curves.easeInOut)
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _controller.animateTo(1.0, curve: Curves.easeInOut);
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null
          ? () => _controller.animateTo(1.0, curve: Curves.easeInOut)
          : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.onTap == null ? c.field : buttonColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.onTap == null
                ? []
                : [
                    BoxShadow(
                      color: buttonColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Text(
            'Publish',
            style: TextStyle(
              color: widget.onTap == null ? c.textMuted : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioSearchSheet extends StatefulWidget {
  final Function(String audioId, String title, String authorId, String url) onSelect;

  const _AudioSearchSheet({required this.onSelect});

  @override
  State<_AudioSearchSheet> createState() => _AudioSearchSheetState();
}

class _AudioSearchSheetState extends State<_AudioSearchSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  VideoPlayerController? _previewPlayer;
  String? _currentlyPlayingUrl;

  @override
  void dispose() {
    _searchController.dispose();
    _previewPlayer?.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(String url) async {
    if (_currentlyPlayingUrl == url) {
      // Pause
      await _previewPlayer?.pause();
      setState(() {
        _currentlyPlayingUrl = null;
      });
    } else {
      // Play new
      await _previewPlayer?.dispose();
      setState(() {
        _currentlyPlayingUrl = url;
      });
      _previewPlayer = VideoPlayerController.networkUrl(Uri.parse(url));
      await _previewPlayer!.initialize();
      _previewPlayer!.setLooping(true);
      await _previewPlayer!.play();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Audio Tracks',
                style: TextStyle(
                  color: c.textHi,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: TextStyle(color: c.textHi, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search audio title or creator...',
              prefixIcon: Icon(Icons.search_rounded, color: c.primary),
              filled: true,
              fillColor: c.field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('audios')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: c.primary));
                }

                final docs = snapshot.data?.docs ?? [];
                // Filter client side
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final author = (data['authorUsername'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) || author.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching audios found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, idx) {
                    final doc = filteredDocs[idx];
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final id = doc.id;
                    final title = data['title'] as String? ?? 'Original Audio';
                    final authorId = data['authorId'] as String? ?? '';
                    final authorUser = data['authorUsername'] as String? ?? '';
                    final audioUrl = data['audioUrl'] as String? ?? '';
                    final echoCount = data['echoCount'] as int? ?? 1;

                    final isPlayingThis = _currentlyPlayingUrl == audioUrl;

                    return Card(
                      color: c.field.withValues(alpha: 0.5),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: IconButton(
                          icon: Icon(
                            isPlayingThis ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: c.primary,
                            size: 32,
                          ),
                          onPressed: () => _togglePreview(audioUrl),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            color: c.textHi,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '$authorUser • $echoCount echos',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            _previewPlayer?.pause();
                            widget.onSelect(id, title, authorId, audioUrl);
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Select',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

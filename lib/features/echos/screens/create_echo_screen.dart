import 'dart:io';
import 'dart:ui';
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
  String? _selectedCategory;

  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animCtrl.forward();

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

      final videoRef =
          FirebaseStorage.instance.ref('posts/videos/${user.uid}_$ts.mp4');
      final videoTask =
          await videoRef.putFile(_selectedVideoFile!).whenComplete(() {});
      if (videoTask.state != TaskState.success)
        throw Exception('Video upload failed');
      final videoUrl = await videoRef.getDownloadURL();

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
          final audioStorageRef = FirebaseStorage.instance
              .ref('posts/audios/${user.uid}_$ts.$audioExt');
          final audioUploadTask =
              await audioStorageRef.putFile(_customAudioFile!).whenComplete(() {});
          if (audioUploadTask.state != TaskState.success)
            throw Exception('Audio upload failed');
          resolvedAudioUrl = await audioStorageRef.getDownloadURL();

          audioTitle = _customAudioTitle ??
              (title.isNotEmpty ? title : 'Original audio · $username');

          if (_customAudioCoverFile != null) {
            final coverRef = FirebaseStorage.instance
                .ref('posts/audio_covers/${user.uid}_$ts.jpg');
            final coverTask =
                await coverRef.putFile(_customAudioCoverFile!).whenComplete(() {});
            if (coverTask.state == TaskState.success) {
              audioCoverUrl = await coverRef.getDownloadURL();
            }
          }
          audioCoverUrl ??= thumbnailUrl;
        } else {
          resolvedAudioUrl = videoUrl;
          audioTitle =
              title.isNotEmpty ? 'Original audio · $title' : 'Original audio · $username';
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
        final audioDoc = await FirebaseFirestore.instance
            .collection('audios')
            .doc(audioId)
            .get();
        final audioData = audioDoc.data() ?? {};
        resolvedAudioUrl = audioData['audioUrl'] as String? ?? resolvedAudioUrl;
        audioTitle = audioData['title'] as String? ?? audioTitle;
        audioAuthorId = audioData['authorId'] as String? ?? audioAuthorId;

        await FirebaseFirestore.instance
            .collection('audios')
            .doc(audioId)
            .update({'echoCount': FieldValue.increment(1)});
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
      payload.remove('id');
      await postRef.set(payload);

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
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
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

  // ── Glass helper ─────────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child, EdgeInsets? padding, double radius = 20}) {
    final c = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: c.border.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Duration formatter ───────────────────────────────────────────────────────
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _buildAppBar(c),
      body: _isLoading
          ? _buildLoader(c)
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Video & Thumbnail row ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Video File', c),
                            const SizedBox(height: 8),
                            _buildVideoCard(c),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Cover Thumbnail', c),
                            const SizedBox(height: 8),
                            _buildThumbnailCard(c),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Audio Track ──
                  _glassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: c.primary.withValues(alpha: 0.22),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(Icons.music_note_rounded,
                                  color: c.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Audio Track',
                                      style: TextStyle(
                                          color: c.textHi,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.audioId == null
                                        ? (_selectedExistingAudioId != null
                                            ? 'Existing: ${_selectedExistingAudioTitle}'
                                            : (_customAudioFile != null
                                                ? 'Custom: $_customAudioFileName'
                                                : 'Original audio from your video'))
                                        : widget.audioTitle ?? 'Using selected audio',
                                    style: TextStyle(
                                      color: (_customAudioFile != null ||
                                              _selectedExistingAudioId != null)
                                          ? c.primary
                                          : c.textMuted,
                                      fontSize: 11,
                                      fontWeight: (_customAudioFile != null ||
                                              _selectedExistingAudioId != null)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.audioId == null &&
                                (_customAudioFile != null ||
                                    _selectedExistingAudioId != null))
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined,
                                    size: 20, color: Colors.red),
                                onPressed: () {
                                  _removeCustomAudio();
                                  _removeExistingAudio();
                                },
                              ),
                          ],
                        ),
                        if (widget.audioId == null &&
                            _customAudioFile == null &&
                            _selectedExistingAudioId == null) ...[
                          const SizedBox(height: 14),
                          Divider(
                              height: 1,
                              color: c.border.withValues(alpha: 0.18)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _audioActionButton(
                                  icon: Icons.upload_file_rounded,
                                  label: 'Upload File',
                                  onTap: _pickCustomAudio,
                                  c: c,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _audioActionButton(
                                  icon: Icons.search_rounded,
                                  label: 'Search Audio',
                                  onTap: _showAudioSearchSheet,
                                  c: c,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Title & Caption ──
                  _glassCard(
                    padding: const EdgeInsets.all(20),
                    radius: 24,
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
                        Divider(
                            height: 20,
                            color: c.border.withValues(alpha: 0.18)),
                        TextField(
                          controller: _bodyController,
                          maxLines: 4,
                          style: TextStyle(color: c.textHi, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Add a description or caption (optional)...',
                            hintStyle:
                                TextStyle(color: c.textMuted, fontSize: 13),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Leaderboard Category ──
                  _glassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader(Icons.emoji_events_outlined,
                            'Leaderboard Category (Optional)', c),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCategoryChip('beauty', '💅 Beauty', c),
                            _buildCategoryChip('art', '🎨 Art', c),
                            _buildCategoryChip('funny', '😂 Funny', c),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Tags ──
                  _glassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _cardHeader(Icons.tag_rounded, 'Tags (Max 5)', c),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: TextField(
                              controller: _tagController,
                              style: TextStyle(color: c.textHi, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Type tag and press enter...',
                                hintStyle:
                                    TextStyle(color: c.textMuted, fontSize: 13),
                                filled: true,
                                fillColor: c.field.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: c.border.withValues(alpha: 0.18),
                                    width: 0.8,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: c.border.withValues(alpha: 0.18),
                                    width: 0.8,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: c.primary.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.add_circle_outline_rounded,
                                      color: c.primary),
                                  onPressed: () => _addTag(_tagController.text),
                                ),
                              ),
                              onSubmitted: _addTag,
                            ),
                          ),
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
                                onDeleted: () =>
                                    setState(() => _selectedTags.remove(tag)),
                                backgroundColor:
                                    c.primary.withValues(alpha: 0.12),
                                side: BorderSide(
                                  color: c.primary.withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColorsExtension c) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: c.surface.withValues(alpha: 0.6),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: c.textHi, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Create Echo',
              style: TextStyle(
                  color: c.textHi,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: c.border.withValues(alpha: 0.18)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _PublishButton(
                    onTap: _isLoading ? null : _submitEcho),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Video card (redesigned) ─────────────────────────────────────────────────
  Widget _buildVideoCard(AppColorsExtension c) {
    final hasVideo = _selectedVideoFile != null;
    final isReady = _videoController != null && _videoController!.value.isInitialized;

    return GestureDetector(
      onTap: hasVideo ? null : _pickVideo,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: hasVideo ? Colors.black : null,
            gradient: hasVideo
                ? null
                : LinearGradient(
                    colors: [
                      c.primary.withValues(alpha: 0.08),
                      c.field.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasVideo
                  ? c.border.withValues(alpha: 0.25)
                  : c.primary.withValues(alpha: 0.25),
              width: hasVideo ? 0.8 : 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasVideo
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isReady)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    else
                      Center(
                        child: CircularProgressIndicator(
                            color: c.primary, strokeWidth: 2),
                      ),

                    // bottom gradient for legibility of badges
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // duration badge
                    if (isReady)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_rounded,
                                  color: Colors.white, size: 11),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(_videoController!.value.duration),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // change button
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: _pickVideo,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.autorenew_rounded,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              const Text('Change',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.primary.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.video_camera_back_rounded,
                                size: 20, color: c.primary),
                          ),
                          const SizedBox(height: 8),
                          Text('Tap to select video',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: c.textHi,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 1),
                          Text('MP4, MOV supported',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: c.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ── Thumbnail card (redesigned) ─────────────────────────────────────────────
  Widget _buildThumbnailCard(AppColorsExtension c) {
    final imageFile = _customThumbnailFile ?? _autoThumbnailFile;
    final isCustom = _customThumbnailFile != null;

    return GestureDetector(
      onTap: _pickCustomThumbnail,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: imageFile == null
                ? LinearGradient(
                    colors: [
                      c.primary.withValues(alpha: 0.08),
                      c.field.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: imageFile == null
                  ? c.primary.withValues(alpha: 0.25)
                  : c.border.withValues(alpha: 0.25),
              width: imageFile == null ? 1.2 : 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageFile != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(imageFile, fit: BoxFit.cover),

                    // subtle bottom gradient so badges read well
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (isCustom)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Custom',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),

                    // edit pencil, corner only — image stays clean
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: _pickCustomThumbnail,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 0.8),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.primary.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.photo_rounded,
                                size: 20, color: c.primary),
                          ),
                          const SizedBox(height: 8),
                          Text('No thumbnail yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: c.textHi,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 1),
                          Text('Auto-generated after video',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: c.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
      String catId, String label, AppColorsExtension c) {
    final isSelected = _selectedCategory == catId;
    return GestureDetector(
      onTap: () => setState(
          () => _selectedCategory = isSelected ? null : catId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? c.primary.withValues(alpha: 0.15)
              : c.field.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? c.primary.withValues(alpha: 0.5)
                : c.border.withValues(alpha: 0.18),
            width: isSelected ? 1 : 0.8,
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

  Widget _audioActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppColorsExtension c,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: c.field.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: c.border.withValues(alpha: 0.18),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: c.primary, size: 14),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: c.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, AppColorsExtension c) {
    return Text(text,
        style: TextStyle(
            color: c.textHi, fontSize: 13, fontWeight: FontWeight.bold));
  }

  Widget _cardHeader(IconData icon, String title, AppColorsExtension c) {
    return Row(
      children: [
        Icon(icon, color: c.primary, size: 20),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: c.textHi, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLoader(AppColorsExtension c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: c.primary),
          const SizedBox(height: 16),
          Text('Uploading Echo post safely...',
              style: TextStyle(
                  color: c.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
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
              _customAudioFile = null;
              _customAudioFileName = null;
            });
          },
        );
      },
    );
  }
}

// ── Publish Button ────────────────────────────────────────────────────────────

class _PublishButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _PublishButton({required this.onTap});

  @override
  State<_PublishButton> createState() => _PublishButtonState();
}

class _PublishButtonState extends State<_PublishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
        scale: _controller,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.onTap == null
                    ? c.field.withValues(alpha: 0.5)
                    : c.primary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.onTap == null
                      ? c.border.withValues(alpha: 0.18)
                      : c.primary.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                'Publish',
                style: TextStyle(
                  color: widget.onTap == null
                      ? c.textMuted
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Audio Search Sheet ────────────────────────────────────────────────────────

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
      await _previewPlayer?.pause();
      setState(() => _currentlyPlayingUrl = null);
    } else {
      await _previewPlayer?.dispose();
      setState(() => _currentlyPlayingUrl = url);
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                  color: c.border.withValues(alpha: 0.18), width: 0.8),
            ),
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
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: c.border.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Search Audio Tracks',
                      style: TextStyle(
                          color: c.textHi,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close, color: c.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: c.textHi, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search audio title or creator...',
                      prefixIcon: Icon(Icons.search_rounded, color: c.primary),
                      filled: true,
                      fillColor: c.field.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: c.border.withValues(alpha: 0.18),
                            width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: c.border.withValues(alpha: 0.18),
                            width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: c.primary.withValues(alpha: 0.5), width: 1),
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
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
                      return Center(
                          child: CircularProgressIndicator(color: c.primary));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final title =
                          (data['title'] ?? '').toString().toLowerCase();
                      final author =
                          (data['authorUsername'] ?? '').toString().toLowerCase();
                      return title.contains(_searchQuery) ||
                          author.contains(_searchQuery);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text('No matching audios found.',
                            style: TextStyle(color: c.textMuted)),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, idx) {
                        final doc = filteredDocs[idx];
                        final data =
                            doc.data() as Map<String, dynamic>? ?? {};
                        final id = doc.id;
                        final title =
                            data['title'] as String? ?? 'Original Audio';
                        final authorId = data['authorId'] as String? ?? '';
                        final authorUser =
                            data['authorUsername'] as String? ?? '';
                        final audioUrl = data['audioUrl'] as String? ?? '';
                        final echoCount = data['echoCount'] as int? ?? 1;
                        final isPlayingThis = _currentlyPlayingUrl == audioUrl;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: c.field.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: c.border.withValues(alpha: 0.18),
                                    width: 0.8,
                                  ),
                                ),
                                child: ListTile(
                                  leading: IconButton(
                                    icon: Icon(
                                      isPlayingThis
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_fill_rounded,
                                      color: c.primary,
                                      size: 32,
                                    ),
                                    onPressed: () => _togglePreview(audioUrl),
                                  ),
                                  title: Text(title,
                                      style: TextStyle(
                                          color: c.textHi,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text('$authorUser · $echoCount echos',
                                      style: TextStyle(
                                          color: c.textMuted, fontSize: 11)),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          c.primary.withValues(alpha: 0.9),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      _previewPlayer?.pause();
                                      widget.onSelect(
                                          id, title, authorId, audioUrl);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Select',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
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
        ),
      ),
    );
  }
}
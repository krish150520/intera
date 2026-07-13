import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/karma/karma_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/nsfw_detection_service.dart';

class CreateHelpPostScreen extends StatefulWidget {
  final String? initialCommunityId;
  const CreateHelpPostScreen({super.key, this.initialCommunityId});

  @override
  State<CreateHelpPostScreen> createState() => _CreateHelpPostScreenState();
}

class _CreateHelpPostScreenState extends State<CreateHelpPostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedMediaFile;
  bool _isVideoMedia = false;
  VideoPlayerController? _videoPreviewController;
  File? _videoThumbnailFile;

  bool _isLoading = false;
  int _karmaBalance = 0;
  double _rewardKarma = 10.0; // Default reward bounty
  bool _isAnonymous = false;
  String _imageAlignment = 'center';
  bool _allowComments = true;
  String? _selectedCommunityId;

  final Set<String> _selectedTags = {};
  List<Map<String, dynamic>> _communities = [];
  bool _loadingCommunities = false;

  @override
  void initState() {
    super.initState();
    _selectedCommunityId = widget.initialCommunityId;
    _fetchKarmaBalance();
    _fetchCommunities();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  Future<void> _fetchKarmaBalance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final balance = await KarmaService.getBalance(uid);
      if (mounted) {
        setState(() {
          _karmaBalance = balance;
          // Clamp initial default reward to user's balance
          if (_karmaBalance < 10) {
            _rewardKarma = _karmaBalance.toDouble();
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching karma balance: $e');
    }
  }

  Future<void> _fetchCommunities() async {
    setState(() => _loadingCommunities = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('communities').get();
      if (mounted) {
        setState(() {
          _communities = snap.docs.map((doc) => {
            'id': doc.id,
            'name': doc.data()['name'] ?? 'Unnamed',
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching communities: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingCommunities = false);
      }
    }
  }

  Future<void> _generateAutoThumbnail() async {
    if (_selectedMediaFile == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final path = await VideoThumbnail.thumbnailFile(
        video: _selectedMediaFile!.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 360,
        quality: 75,
      );
      if (path != null) {
        setState(() {
          _videoThumbnailFile = File(path);
        });
      }
    } catch (e) {
      debugPrint('Error generating automatic thumbnail: $e');
    }
  }

  Future<void> _pickMedia(XFile? pickedFile, bool isVideo) async {
    if (pickedFile == null) return;
    await _videoPreviewController?.dispose();
    _videoPreviewController = null;
    setState(() {
      _selectedMediaFile = File(pickedFile.path);
      _isVideoMedia = isVideo;
      _videoThumbnailFile = null;
    });
    if (isVideo) {
      _videoPreviewController = VideoPlayerController.file(_selectedMediaFile!)
        ..initialize().then((_) {
          setState(() {});
          _videoPreviewController!.setLooping(true);
          _videoPreviewController!.play();
        });
      _generateAutoThumbnail();
    }
  }

  void _selectMediaSource(bool isVideo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final c = context.appColors;
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library_rounded, color: c.primary),
                  title: Text(isVideo ? 'Choose Video from Gallery' : 'Choose Image from Gallery', style: TextStyle(color: c.textHi)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final file = isVideo
                        ? await _picker.pickVideo(source: ImageSource.gallery)
                        : await _picker.pickImage(source: ImageSource.gallery);
                    _pickMedia(file, isVideo);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt_rounded, color: c.primary),
                  title: Text(isVideo ? 'Record Video with Camera' : 'Take Photo with Camera', style: TextStyle(color: c.textHi)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final file = isVideo
                        ? await _picker.pickVideo(source: ImageSource.camera)
                        : await _picker.pickImage(source: ImageSource.camera);
                    _pickMedia(file, isVideo);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addTag(String tag) {
    final clean = tag.trim().replaceAll('#', '').toLowerCase();
    if (clean.isNotEmpty && !_selectedTags.contains(clean)) {
      setState(() {
        _selectedTags.add(clean);
        _tagController.clear();
      });
    }
  }

  void _submitHelpPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('You must be logged in.');
      return;
    }

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final reward = _rewardKarma.toInt();

    if (title.isEmpty) {
      _snack('Please add a descriptive title for your help request.');
      return;
    }
    if (body.isEmpty) {
      _snack('Please explain your request in the body text.');
      return;
    }
    if (reward > 100) {
      _snack('Karma bounty cannot exceed 100.');
      return;
    }
    if (reward > _karmaBalance) {
      _snack('You only have $_karmaBalance karma points available.');
      return;
    }

    setState(() => _isLoading = true);

    // ── NSFW Check ──────────────────────────────────────────────────────
    final hasNsfwText = await NsfwDetectionService.isTextNsfw(title) ||
        await NsfwDetectionService.isTextNsfw(body);
    final hasNsfwMedia = _selectedMediaFile != null &&
        await NsfwDetectionService.isMediaNsfw(_selectedMediaFile);

    if (hasNsfwText || hasNsfwMedia) {
      setState(() => _isLoading = false);
      _showNsfwWarningDialog();
      return;
    }

    try {
      // ── Upload media ───────────────────────────────────────────────────
      String? mediaUrl;
      String? videoThumbnailUrl;
      final ts = DateTime.now().millisecondsSinceEpoch;

      if (_selectedMediaFile != null) {
        final isVid = _isVideoMedia ||
            _selectedMediaFile!.path.toLowerCase().endsWith('.mp4');
        final folder = isVid ? 'posts/videos' : 'posts/images';
        final ext = isVid ? 'mp4' : 'jpg';
        final ref =
            FirebaseStorage.instance.ref('$folder/${user.uid}_$ts.$ext');
        final task = await ref.putFile(_selectedMediaFile!).whenComplete(() {});
        if (task.state != TaskState.success) throw Exception('Upload failed');
        mediaUrl = await ref.getDownloadURL();

        if (isVid && _videoThumbnailFile != null) {
          final thumbRef = FirebaseStorage.instance
              .ref('posts/thumbnails/${user.uid}_$ts.jpg');
          final thumbTask = await thumbRef.putFile(_videoThumbnailFile!).whenComplete(() {});
          if (thumbTask.state == TaskState.success) {
            videoThumbnailUrl = await thumbRef.getDownloadURL();
          }
        }
      }

      // ── Resolve User Data ──────────────────────────────────────────────
      String displayName = 'Anonymous';
      String username = '@anonymous';
      String avatarUrl = '';

      if (!_isAnonymous) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final ud = userDoc.data() ?? {};
        displayName = ud['name'] ?? user.displayName ?? 'Anonymous';
        final rawUsername = ud['username'] ?? user.email?.split('@')[0] ?? 'user';
        username = rawUsername.startsWith('@') ? rawUsername : '@$rawUsername';
        avatarUrl = ud['profileImageUrl'] ?? ud['photoURL'] ?? user.photoURL ?? '';
      }

      // ── Assemble Post Payload ──────────────────────────────────────────
      final post = Post(
        id: '',
        authorId: _isAnonymous ? 'anonymous' : user.uid,
        realAuthorId: user.uid,
        authorName: displayName,
        authorUsername: username,
        authorAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        type: PostType.helpRequest,
        title: title,
        body: body,
        content: '$title\n$body',
        imageUrl: mediaUrl,
        videoThumbnailUrl: videoThumbnailUrl,
        imageAlignment: _imageAlignment,
        tags: _selectedTags.toList(),
        createdAt: DateTime.now(),
        rewardKarma: reward,
        communityId: _selectedCommunityId,
      );

      final payload = post.toFirestore();
      payload['isCompleted'] = false;
      payload['assignedTo'] = null;
      payload['allowComments'] = _allowComments;
      if (reward > 0) payload['karmaReserved'] = true;

      // ── Write post and tags to Firestore ────────────────────────────────
      final docRef = await FirebaseFirestore.instance.collection('posts').add(payload);

      // Save tags to 'tags' collection
      for (final tag in _selectedTags) {
        await FirebaseFirestore.instance.collection('tags').doc(tag).set({
          'name': tag,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Reserve karma bounty if set
      if (reward > 0) {
        await KarmaService.reserveForHelpPost(
          postId: docRef.id,
          amount: reward,
        );
      }

      if (mounted) {
        _snack('🎉 Help Request published!', color: const Color(0xFF388E3C));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _snack('Failed to publish: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showNsfwWarningDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final c = context.appColors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Content Warning', style: TextStyle(color: c.textHi)),
            ],
          ),
          content: Text(
            'Your help request text has been flagged by our safety guidelines as containing potentially inappropriate content. Please clean up the description and try again.',
            style: TextStyle(color: c.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Okay'),
            ),
          ],
        );
      },
    );
  }

  void _snack(String text, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color ?? const Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Ask for Help',
          style: TextStyle(
            color: c.textHi,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: c.textHi),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: c.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Help post instruction card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [c.primary.withValues(alpha: 0.15), Colors.transparent]
                            : [c.primary.withValues(alpha: 0.08), Colors.transparent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: c.primary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.help_outline_rounded, color: c.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Describe your problem, select the tag terms, and offer a Karma Bounty. Other members can claim it when they solve your issue!',
                            style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title Field
                  Text(
                    'Title',
                    style: TextStyle(color: c.textHi, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: c.textHi),
                    decoration: InputDecoration(
                      hintText: 'What do you need help with?',
                      hintStyle: TextStyle(color: c.textMuted.withValues(alpha: 0.7)),
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Body Description Field
                  Text(
                    'Details',
                    style: TextStyle(color: c.textHi, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyController,
                    maxLines: 6,
                    style: TextStyle(color: c.textHi),
                    decoration: InputDecoration(
                      hintText: 'Provide details, context, parameters, or codes...',
                      hintStyle: TextStyle(color: c.textMuted.withValues(alpha: 0.7)),
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Optional Media Attachment
                  Text(
                    'Attach Media (Optional)',
                    style: TextStyle(color: c.textHi, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedMediaFile == null)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectMediaSource(false),
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.border, width: 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_library_rounded, color: c.primary, size: 24),
                                  const SizedBox(height: 6),
                                  Text('Add Image', style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectMediaSource(true),
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.border, width: 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_library_rounded, color: c.primary, size: 24),
                                  const SizedBox(height: 6),
                                  Text('Add Video', style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _isVideoMedia && _videoPreviewController != null
                                ? AspectRatio(
                                    aspectRatio: _videoPreviewController!.value.aspectRatio,
                                    child: VideoPlayer(_videoPreviewController!),
                                  )
                                : Image.file(_selectedMediaFile!, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMediaFile = null;
                                _videoPreviewController?.dispose();
                                _videoPreviewController = null;
                                _videoThumbnailFile = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (_selectedMediaFile != null && !_isVideoMedia) ...[
                    _buildSquareCropFocusCard(),
                    const SizedBox(height: 24),
                  ],

                  // Interactive Bounty Selector Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Karma Bounty',
                              style: TextStyle(color: c.textHi, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Available: $_karmaBalance Karma',
                                style: TextStyle(color: c.primary, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_karmaBalance == 0)
                          Text(
                            'You do not have any karma. You can still post for 0 karma, or help others to earn points!',
                            style: TextStyle(color: Colors.orange[400], fontSize: 12, height: 1.4),
                          )
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0', style: TextStyle(color: c.textMuted, fontSize: 12)),
                              Text(
                                '${_rewardKarma.toInt()} Karma Points',
                                style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              Text(
                                _karmaBalance > 100 ? '100' : '$_karmaBalance',
                                style: TextStyle(color: c.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                          Slider(
                            value: _rewardKarma,
                            min: 0.0,
                            max: _karmaBalance > 100 ? 100.0 : _karmaBalance.toDouble(),
                            divisions: _karmaBalance > 100 ? 100 : (_karmaBalance == 0 ? 1 : _karmaBalance),
                            activeColor: c.primary,
                            inactiveColor: c.border,
                            onChanged: (val) {
                              setState(() {
                                _rewardKarma = val;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tag input & chips
                  Text(
                    'Tags',
                    style: TextStyle(color: c.textHi, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tagController,
                    style: TextStyle(color: c.textHi),
                    onSubmitted: (val) => _addTag(val),
                    decoration: InputDecoration(
                      hintText: 'Type tag and press enter...',
                      hintStyle: TextStyle(color: c.textMuted.withValues(alpha: 0.7)),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add_rounded, color: c.primary),
                        onPressed: () => _addTag(_tagController.text),
                      ),
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.primary, width: 1.5),
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
                          backgroundColor: c.primary.withValues(alpha: 0.1),
                          label: Text('#$tag', style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                          deleteIcon: Icon(Icons.close_rounded, color: c.primary, size: 14),
                          onDeleted: () {
                            setState(() {
                              _selectedTags.remove(tag);
                            });
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Community selector
                  if (!_loadingCommunities && _communities.isNotEmpty) ...[
                    Text(
                      'Post to Community (Optional)',
                      style: TextStyle(color: c.textHi, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCommunityId,
                      dropdownColor: c.surface,
                      style: TextStyle(color: c.textHi),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      ),
                      hint: Text('Select community...', style: TextStyle(color: c.textMuted)),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('None (General Feed)', style: TextStyle(color: c.textHi)),
                        ),
                        ..._communities.map((comm) {
                          return DropdownMenuItem<String>(
                            value: comm['id'],
                            child: Text(comm['name'], style: TextStyle(color: c.textHi)),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCommunityId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Anonymous & comments toggles
                  SwitchListTile(
                    title: Text('Post Anonymously', style: TextStyle(color: c.textHi, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Your name & username won\'t be shown.', style: TextStyle(color: c.textMuted, fontSize: 11)),
                    value: _isAnonymous,
                    activeColor: c.primary,
                    onChanged: (val) {
                      setState(() {
                        _isAnonymous = val;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text('Allow Comments', style: TextStyle(color: c.textHi, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Allow other users to leave comments.', style: TextStyle(color: c.textMuted, fontSize: 11)),
                    value: _allowComments,
                    activeColor: c.primary,
                    onChanged: (val) {
                      setState(() {
                        _allowComments = val;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 36),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _submitHelpPost,
                      child: const Text(
                        'Publish Help Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSquareCropFocusCard() {
    final c = context.appColors;
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
              Icon(Icons.crop_free_rounded, color: c.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Square Grid Crop Position',
                style: TextStyle(color: c.textHi, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Choose which area of the image to focus on in square card/profile feeds:',
            style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAlignmentChip('top', '⬆️ Top'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAlignmentChip('center', '↔️ Center'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAlignmentChip('bottom', '⬇️ Bottom'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentChip(String value, String label) {
    final c = context.appColors;
    final isSelected = _imageAlignment == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _imageAlignment = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? c.primary.withValues(alpha: 0.15) : c.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? c.primary : c.border.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? c.primary : c.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../shared/models/post_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/karma/karma_service.dart';


import '../../../core/theme/app_theme.dart';
import '../../../core/services/nsfw_detection_service.dart';

import '../../navigation/screens/bottom_nav_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;
  final File? initialMediaFile;
  final bool? isVideo;
  final bool? isHelpRequest;
  final String? postType;

  const CreatePostScreen({
    super.key,
    this.communityId,
    this.initialMediaFile,
    this.isVideo,
    this.isHelpRequest,
    this.postType,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  PostType _selectedType = PostType.text;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _rewardController = TextEditingController();
  final _tagController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedMediaFile;
  VideoPlayerController? _videoPreviewController;
  bool _isLoading = false;
  bool _isVideoMedia = false;
  File? _videoThumbnailFile;

  final Set<String> _selectedTags = {};

  // Intera Additions (Optional UI fields)
  String? _selectedMood;
  bool _isAnonymous = false;
  String _imageAlignment = 'center';
  String _selectedVisibility = 'Public';
  bool _allowComments = true;
  String? _selectedCommunityId;
  DateTime? _scheduledDateTime;
  bool _hasPoll = false;
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  List<Map<String, dynamic>> _communities = [];
  bool _loadingCommunities = false;

  late final AnimationController _animCtrl;


  final List<String> _moods = ['😊 Chill', '🔥 Focused', '🚀 Excited', '😴 Tired', '🤔 Curious'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    
    if (widget.postType == 'video' || widget.isVideo == true) {
      _selectedType = PostType.video;
      _isVideoMedia = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickInitialVideo();
      });
    } else if (widget.postType == 'text') {
      _selectedType = PostType.text;
    } else if (widget.postType == 'photo') {
      _selectedType = PostType.image;
    } else if (widget.postType == 'question') {
      _selectedType = PostType.helpRequest;
    } else if (widget.postType == 'poll') {
      _selectedType = PostType.text;
      _hasPoll = true;
    } else if (widget.isHelpRequest == true) {
      _selectedType = PostType.helpRequest;
    } else if (widget.initialMediaFile != null) {
      _selectedMediaFile = widget.initialMediaFile;
      _isVideoMedia = widget.isVideo ?? false;
      _selectedType = _isVideoMedia ? PostType.video : PostType.image;
      if (_isVideoMedia) {
        _videoPreviewController = VideoPlayerController.file(_selectedMediaFile!)
          ..initialize().then((_) {
            setState(() {});
            _videoPreviewController!.setLooping(true);
            _videoPreviewController!.play();
          });
        _generateAutoThumbnail();
      }
    }

    _selectedCommunityId = widget.communityId;
    _fetchCommunities();
    _animCtrl.forward();
  }

  Future<void> _pickInitialVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      _pickMedia(file, true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _rewardController.dispose();
    _tagController.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    _videoPreviewController?.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCommunities() async {
    setState(() => _loadingCommunities = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('communities').get();
      setState(() {
        _communities = snap.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Unnamed',
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching communities: $e');
    } finally {
      setState(() => _loadingCommunities = false);
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

      _selectedType = isVideo ? PostType.video : PostType.image;
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



  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('You must be logged in.');
      return;
    }

    final isHelp = _selectedType == PostType.helpRequest;
    final title = _titleController.text.trim();
    var body = _bodyController.text.trim();
    final reward = int.tryParse(_rewardController.text.trim()) ?? 0;

    if (isHelp && title.isEmpty) {
      _snack('Please add a title for your help request.');
      return;
    }
    if (isHelp && reward > 100) {
      _snack('Karma reward cannot exceed 100.');
      return;
    }
    if (!isHelp && body.isEmpty && _selectedMediaFile == null) {
      _snack('Please add some content or media!');
      return;
    }
    if (isHelp && reward > 0) {
      final balance = await KarmaService.getBalance(user.uid);
      if (balance < reward) {
        _snack('You only have $balance karma — reduce the reward.');
        return;
      }
    }

    setState(() => _isLoading = true);

    // Formulate poll inside body if configured
    if (_hasPoll) {
      final options = _pollOptionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (options.isNotEmpty) {
        body += '\n\n📊 Poll:\n' + options.asMap().entries.map((e) => '${e.key + 1}️⃣ ${e.value}').join('\n');
      }
    }

    // Add mood tags if configured
    final tagsList = _selectedTags.toList();
    if (_selectedMood != null) {
      tagsList.add('mood_${_selectedMood!.replaceAll(' ', '_')}');
    }

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
            _selectedType == PostType.video ||
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

      // ── Fetch verified user data ───────────────────────────────────────
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

      // ── Build payload ──────────────────────────────────────────────────
      final post = Post(
        id: '',
        authorId: _isAnonymous ? 'anonymous' : user.uid,
        authorName: displayName,
        authorUsername: username,
        authorAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        type: _selectedType,
        title: isHelp
            ? title
            : title.isNotEmpty
                ? title
                : body.split('\n').first,
        body: body,
        content: isHelp ? '$title\n$body' : body,
        imageUrl: mediaUrl,
        videoThumbnailUrl: videoThumbnailUrl,
        imageAlignment: _imageAlignment,
        likeCount: 0,
        commentCount: 0,
        shareCount: 0,
        tags: tagsList,
        createdAt: DateTime.now(),
        rewardKarma: isHelp ? reward : null,
      );

      final payload = post.toFirestore();
      payload['communityId'] = widget.communityId ?? _selectedCommunityId;
      payload['visibility'] = _selectedVisibility;
      payload['allowComments'] = _allowComments;
      
      if (isHelp) {
        payload['isCompleted'] = false;
        payload['assignedTo'] = null;
        if (reward > 0) payload['karmaReserved'] = true;
      }

      if (_scheduledDateTime != null) {
        payload['scheduledAt'] = Timestamp.fromDate(_scheduledDateTime!);
      }

      // ── Write to Firestore ─────────────────────────────────────────────
      final docRef =
          await FirebaseFirestore.instance.collection('posts').add(payload);

      // Save tags to the global database collection 'tags'
      for (final tag in _selectedTags) {
        final cleanTag = tag.toLowerCase().trim().replaceAll('#', '');
        if (cleanTag.isNotEmpty) {
          await FirebaseFirestore.instance.collection('tags').doc(cleanTag).set({
            'name': cleanTag,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (isHelp && reward > 0) {
        await KarmaService.reserveForHelpPost(
          postId: docRef.id,
          amount: reward,
        );
      }

      if (!mounted) return;
      _snack('🎉 Post published!', color: const Color(0xFF388E3C));
      Navigator.of(context).canPop()
          ? Navigator.of(context).pop()
          : Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to post: $e', color: Colors.red);
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

  void _showNsfwWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: context.appColors.error, size: 28),
            const SizedBox(width: 10),
            const Text('Content Flagged'),
          ],
        ),
        content: const Text(
          'Our safety systems have detected potentially sensitive or NSFW content in your text or media. '
          'To maintain community guidelines, posting of this content is restricted.',
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textHi, size: 20),
          onPressed: () async {
            if (Navigator.of(context).canPop()) {
              await Navigator.of(context).maybePop();
            } else {
              BottomNavScreen.switchToTab(0);
            }
          },
        ),
        title: Text(
          'Create Post',
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
              onTap: _isLoading ? null : _submitPost,
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
                  // 1. Preview Card & Replacement (Staggered Delay: 50ms)
                  _buildStaggeredEntrance(
                    delayMs: 50,
                    child: Center(
                      child: _PreviewCard(
                        mediaFile: _selectedMediaFile,
                        isVideo: _isVideoMedia,
                        videoController: _videoPreviewController,
                        onReplace: () async {
                          final file = _isVideoMedia
                              ? await _picker.pickVideo(source: ImageSource.gallery)
                              : await _picker.pickImage(source: ImageSource.gallery);
                          _pickMedia(file, _isVideoMedia);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_selectedMediaFile != null && !_isVideoMedia) ...[
                    _buildStaggeredEntrance(
                      delayMs: 75,
                      child: _buildSquareCropFocusCard(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Title & Caption Card (Staggered Delay: 100ms)
                  _buildStaggeredEntrance(
                    delayMs: 100,
                    child: _buildInputFieldsCard(),
                  ),
                  const SizedBox(height: 16),

                  // 3. Optionals / Intera Improvements (Staggered Delay: 150ms)
                  _buildStaggeredEntrance(
                    delayMs: 150,
                    child: _buildInteraImprovementsSection(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
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
            'Uploading content safely...',
            style: TextStyle(color: c.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStaggeredEntrance({required int delayMs, required Widget child}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 250 + delayMs),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, childWidget) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildInputFieldsCard() {
    final c = context.appColors;
    final isHelp = _selectedType == PostType.helpRequest;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title (Visible if Help Request, or optionally toggleable)
          TextField(
            controller: _titleController,
            style: TextStyle(color: c.textHi, fontSize: 16, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: isHelp ? 'Task title *' : 'Add a title (optional)',
              hintStyle: TextStyle(color: c.textMuted, fontSize: 16, fontWeight: FontWeight.w600),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Divider(color: c.border.withValues(alpha: 0.5), height: 24),

          // Caption / Description
          TextField(
            controller: _bodyController,
            maxLines: null,
            style: TextStyle(color: c.textHi, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: "What's happening?",
              hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteraImprovementsSection() {
    final c = context.appColors;
    final isHelp = _selectedType == PostType.helpRequest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tags Selection Card ──
        _buildExpansionCard(
          title: 'Tags & Topics',
          icon: Icons.tag_rounded,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tags')
                .orderBy('createdAt', descending: true)
                .limit(40)
                .snapshots(),
            builder: (context, snapshot) {
              final defaultTags = ['design', 'college', 'tech', 'lifestyle', 'help', 'question'];
              final dbTags = snapshot.hasData
                  ? snapshot.data!.docs
                      .map((doc) => doc.id.toLowerCase().trim())
                      .where((t) => t.isNotEmpty)
                      .toList()
                  : <String>[];

              // Union of standard tags and database tags while keeping order
              final allTags = <String>[];
              allTags.addAll(defaultTags);
              for (final t in dbTags) {
                if (!allTags.contains(t)) {
                  allTags.add(t);
                }
              }

              // Also make sure currently selected tags are visible in the pool
              for (final t in _selectedTags) {
                if (!allTags.contains(t)) {
                  allTags.add(t);
                }
              }

              final searchQuery = _tagController.text.toLowerCase().trim().replaceAll('#', '');
              final filteredTags = searchQuery.isEmpty
                  ? allTags
                  : allTags.where((t) => t.contains(searchQuery)).toList();

              final isNewTag = searchQuery.isNotEmpty && !allTags.contains(searchQuery);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search & Create input field
                  Container(
                    decoration: BoxDecoration(
                      color: c.field,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border.withValues(alpha: 0.3)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: c.textMuted, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            style: TextStyle(color: c.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search or type custom tag...',
                              hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (val) {
                              final clean = val.toLowerCase().trim().replaceAll('#', '');
                              if (clean.isNotEmpty) {
                                setState(() {
                                  _selectedTags.add(clean);
                                  _tagController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        if (_tagController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _tagController.clear()),
                            child: Icon(Icons.close_rounded, color: c.textMuted, size: 16),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // If user is typing a new tag, offer to create it
                  if (isNewTag) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTags.add(searchQuery);
                          _tagController.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.primary, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: c.primary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Create "#$searchQuery"',
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Wrap list of tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filteredTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTags.remove(tag);
                            } else {
                              _selectedTags.add(tag);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? c.primary.withValues(alpha: 0.15) : c.field,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? c.primary : c.border.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              color: isSelected ? c.primary : c.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── Mood Selection Card ──
        _buildExpansionCard(
          title: 'How is your Mood?',
          icon: Icons.emoji_emotions_outlined,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(mood),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedMood = val ? mood : null;
                      });
                    },
                    selectedColor: c.primary.withValues(alpha: 0.15),
                    backgroundColor: c.field,
                    labelStyle: TextStyle(
                      color: isSelected ? c.primary : c.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Community Selector Card ──
        if (widget.communityId == null) ...[
          _buildExpansionCard(
            title: 'Publish to Community',
            icon: Icons.groups_outlined,
            child: _loadingCommunities
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedCommunityId,
                    hint: Text('Select Community (Optional)', style: TextStyle(color: c.textMuted, fontSize: 13)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: c.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _communities.map((comm) {
                      return DropdownMenuItem<String>(
                        value: comm['id'] as String,
                        child: Text(comm['name'] as String, style: TextStyle(color: c.textHi, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCommunityId = val;
                      });
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Visibility & Interaction Controls Card ──
        _buildExpansionCard(
          title: 'Visibility & Comments',
          icon: Icons.lock_outline_rounded,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Who can see this?', style: TextStyle(color: c.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  DropdownButton<String>(
                    value: _selectedVisibility,
                    underline: const SizedBox(),
                    items: ['Public', 'Followers', 'Only Me'].map((item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, style: TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedVisibility = val);
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Allow Comments', style: TextStyle(color: c.textHi, fontSize: 13, fontWeight: FontWeight.w600)),
                value: _allowComments,
                activeColor: c.primary,
                onChanged: (val) => setState(() => _allowComments = val),
              ),
              const Divider(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Anonymous Post', style: TextStyle(color: c.textHi, fontSize: 13, fontWeight: FontWeight.w600)),
                value: _isAnonymous,
                activeColor: c.primary,
                onChanged: (val) => setState(() => _isAnonymous = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Scheduling Card ──
        _buildExpansionCard(
          title: 'Schedule Post',
          icon: Icons.calendar_month_outlined,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _scheduledDateTime == null
                    ? 'Publish Instantly'
                    : 'Scheduled: ${_scheduledDateTime.toString().substring(0, 16)}',
                style: TextStyle(color: c.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null && mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
                child: Text(_scheduledDateTime == null ? 'Schedule' : 'Clear', style: TextStyle(color: c.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Task/Karma Card Toggle (Help Requests) ──
        _buildExpansionCard(
          title: 'Request Help from Community',
          icon: Icons.handshake_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Mark as Help Request', style: TextStyle(color: c.textHi, fontSize: 13, fontWeight: FontWeight.w600)),
                value: isHelp,
                activeColor: c.primary,
                onChanged: (val) {
                  setState(() {
                    _selectedType = val ? PostType.helpRequest : (_selectedMediaFile != null ? (_isVideoMedia ? PostType.video : PostType.image) : PostType.text);
                  });
                },
              ),
              if (isHelp) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _rewardController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: c.textHi, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Karma Reward Amount',
                    hintText: 'Enter karma points to reserve...',
                    filled: true,
                    fillColor: c.field,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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

// ── Publish Button Widget with physical touch animation ───────────────────────

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

// ── Media Preview Card ────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final File? mediaFile;
  final bool isVideo;
  final VideoPlayerController? videoController;
  final VoidCallback onReplace;

  const _PreviewCard({
    required this.mediaFile,
    required this.isVideo,
    required this.videoController,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        key: ValueKey(mediaFile?.path),
        onTap: onReplace,
        child: Container(
          width: 140,
          height: 190,
          decoration: BoxDecoration(
            color: c.field,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media Content
              if (mediaFile != null) ...[
                if (isVideo && videoController != null && videoController!.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: videoController!.value.size.width,
                      height: videoController!.value.size.height,
                      child: VideoPlayer(videoController!),
                    ),
                  )
                else
                  Image.file(mediaFile!, fit: BoxFit.cover),
              ] else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_outlined, size: 28, color: c.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'No Media',
                      style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

              // Edit overlay button
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

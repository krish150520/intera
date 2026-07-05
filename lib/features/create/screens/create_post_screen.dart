import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../shared/models/post_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/karma/karma_service.dart';
import '../../../core/karma/karma_badge.dart';
import '../../../shared/widgets/custom_avatar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/nsfw_detection_service.dart';
import '../../../core/services/feed_algorithm.dart';
import '../../navigation/screens/bottom_nav_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;
  const CreatePostScreen({super.key, this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  PostType _selectedType = PostType.text;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _rewardController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedMediaFile;
  VideoPlayerController? _videoPreviewController;
  bool _isLoading = false;
  bool _isVideoMedia = false; // tracks whether picked media is video
  final Set<String> _selectedTags = {};

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _rewardController.dispose();
    _videoPreviewController?.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<void> _pickMedia(XFile? pickedFile, bool isVideo) async {
    if (pickedFile == null) return;
    await _videoPreviewController?.dispose();
    _videoPreviewController = null;
    setState(() {
      _selectedMediaFile = File(pickedFile.path);
      _isVideoMedia = isVideo;
    });
    if (isVideo) {
      _videoPreviewController = VideoPlayerController.file(_selectedMediaFile!)
        ..initialize().then((_) {
          setState(() {});
          _videoPreviewController!.setLooping(true);
          _videoPreviewController!.play();
        });
    }
  }

  void _removeMedia() {
    _videoPreviewController?.pause();
    _videoPreviewController?.dispose();
    _videoPreviewController = null;
    setState(() {
      _selectedMediaFile = null;
      _isVideoMedia = false;
    });
  }

  String _labelFor(PostType t) => switch (t) {
        PostType.text => 'Text',
        PostType.question => 'Question',
        PostType.helpRequest => 'Help',
        PostType.achievement => 'Achievement',
        PostType.image => 'Image',
        PostType.video => 'Video',
      };

  IconData _iconFor(PostType t) => switch (t) {
        PostType.text => Icons.chat_bubble_outline_rounded,
        PostType.question => Icons.help_outline_rounded,
        PostType.helpRequest => Icons.handshake_outlined,
        PostType.achievement => Icons.emoji_events_outlined,
        PostType.image => Icons.photo_outlined,
        PostType.video => Icons.videocam_outlined,
      };

  String _descriptionFor(PostType t) => switch (t) {
        PostType.text => 'Share thoughts',
        PostType.question => 'Ask the community',
        PostType.helpRequest => 'Request assistance',
        PostType.achievement => 'Celebrate a win',
        PostType.image => 'Share a photo',
        PostType.video => 'Share a clip',
      };

  void _selectType(PostType type) {
    if (type == _selectedType) return;
    _animCtrl.reverse().then((_) {
      setState(() {
        _selectedType = type;
        _removeMedia();
      });
      _animCtrl.forward();
    });
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
    final body = _bodyController.text.trim();
    final reward = int.tryParse(_rewardController.text.trim()) ?? 0;

    if (isHelp && title.isEmpty) {
      _snack('Please add a title for your help request.');
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
      if (_selectedMediaFile != null) {
        final ts = DateTime.now().millisecondsSinceEpoch;
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
      }

      // ── Fetch verified user data ───────────────────────────────────────
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

      // ── Build payload ──────────────────────────────────────────────────
      final post = Post(
        id: '',
        authorId: user.uid,
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
        likeCount: 0,
        commentCount: 0,
        shareCount: 0,
        tags: _selectedTags.toList(),
        createdAt: DateTime.now(),
        rewardKarma: isHelp ? reward : null,
      );

      final payload = post.toFirestore();
      if (isHelp) {
        payload['isCompleted'] = false;
        payload['assignedTo'] = null;
        payload['communityId'] = widget.communityId;
        if (reward > 0) payload['karmaReserved'] = true;
      } else {
        payload['communityId'] = widget.communityId;
      }

      // ── Write to Firestore ─────────────────────────────────────────────
      final docRef =
          await FirebaseFirestore.instance.collection('posts').add(payload);

      if (isHelp && reward > 0) {
        await KarmaService.reserveForHelpPost(
          postId: docRef.id,
          amount: reward,
        );
      }

      if (!mounted) return;
      _snack('🎉 ${_labelFor(_selectedType)} post published!',
          color: const Color(0xFF388E3C));
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: c.bg,
      body: _isLoading
          ? _buildLoader(context)
          : CustomScrollView(
              slivers: [
                // ── App bar with author ─────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  backgroundColor: c.surface,
                  elevation: 0,
                  leading: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration:
                          BoxDecoration(color: c.field, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: c.primary),
                    ),
                  ),
                  title: Text('Create post',
                      style: TextStyle(
                          color: c.textHi,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  actions: [
                    if (uid.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Center(
                          child:
                              KarmaBadge(uid: uid, size: KarmaBadgeSize.small),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _PostButton(
                        onTap: _isLoading ? null : _submitPost,
                        gradient: c.primaryGradient,
                      ),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(56),
                    child: _AuthorStrip(user: user, uid: uid),
                  ),
                ),

                // ── Body content ────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Post type grid ──────────────────────────────────
                      _SectionHeader(
                        icon: Icons.category_rounded,
                        label: 'Choose post type',
                      ),
                      const SizedBox(height: 12),
                      _PostTypeGrid(
                        selectedType: _selectedType,
                        onSelect: _selectType,
                        labelFor: _labelFor,
                        iconFor: _iconFor,
                        descriptionFor: _descriptionFor,
                      ),

                      const SizedBox(height: 24),

                      // ── Content fields (animated) ───────────────────────
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: _buildContentSection(context),
                      ),

                      const SizedBox(height: 28),

                      // ── Tag picker ──────────────────────────────────────
                      _TagPickerSection(
                        selectedTags: _selectedTags,
                        onToggle: (tag) => setState(() {
                          if (_selectedTags.contains(tag)) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        }),
                      ),

                      const SizedBox(height: 28),

                      // ── Submit button ───────────────────────────────────
                      _GradientSubmitButton(
                        label: _selectedType == PostType.helpRequest
                            ? '🚀  Launch help request'
                            : 'Share ${_labelFor(_selectedType).toLowerCase()} post',
                        gradient: c.primaryGradient,
                        onTap: _submitPost,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Visible to everyone in the community',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Content section builder ─────────────────────────────────────────────

  Widget _buildContentSection(BuildContext context) {
    final isHelp = _selectedType == PostType.helpRequest;
    final isImage = _selectedType == PostType.image;
    final isVideo = _selectedType == PostType.video;

    return _ContentCard(
      children: [
        // ── Media post fields ────────────────────────────────────────────
        if (isImage || isVideo) ...[
          _SectionHeader(
            icon: isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
            label: isVideo ? 'Select video' : 'Select image',
          ),
          const SizedBox(height: 10),
          _buildMediaPicker(context, isVideo: isVideo),
          const SizedBox(height: 16),
          _FieldLabel(label: 'Caption'),
          const SizedBox(height: 6),
          _StyledTextArea(
            controller: _bodyController,
            placeholder: 'Write a caption for your media...',
            maxLines: 2,
          ),
        ]

        // ── Help request fields ──────────────────────────────────────────
        else if (isHelp) ...[
          _SectionHeader(
            icon: Icons.edit_rounded,
            label: 'Task details',
          ),
          const SizedBox(height: 10),
          _FieldLabel(label: 'Task title *'),
          const SizedBox(height: 6),
          _StyledInputWithIcon(
            controller: _titleController,
            placeholder: 'Describe the task briefly...',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),
          _ContentDivider(),
          const SizedBox(height: 16),
          _FieldLabel(label: 'Details'),
          const SizedBox(height: 6),
          _StyledTextArea(
            controller: _bodyController,
            placeholder: 'Explain what needs to be done...',
            maxLines: 4,
          ),

          // ── Media attachment for help posts (NEW) ─────────────────────
          const SizedBox(height: 16),
          _ContentDivider(),
          const SizedBox(height: 16),
          _SectionHeader(
            icon: Icons.attach_file_rounded,
            label: 'Attach media (optional)',
          ),
          const SizedBox(height: 10),
          _HelpMediaAttachment(
            mediaFile: _selectedMediaFile,
            isVideo: _isVideoMedia,
            videoController: _videoPreviewController,
            onPickImage: () async {
              final file = await _picker.pickImage(source: ImageSource.gallery);
              _pickMedia(file, false);
            },
            onPickVideo: () async {
              final file = await _picker.pickVideo(source: ImageSource.gallery);
              _pickMedia(file, true);
            },
            onRemove: _removeMedia,
          ),

          const SizedBox(height: 16),
          _ContentDivider(),
          const SizedBox(height: 16),
          _KarmaRewardRow(
            controller: _rewardController,
            userUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
        ]

        // ── Normal text / question / achievement fields ──────────────────
        else ...[
          _SectionHeader(
            icon: Icons.edit_rounded,
            label: 'Write your post',
          ),
          const SizedBox(height: 10),
          _FieldLabel(label: 'Title (optional)'),
          const SizedBox(height: 6),
          _StyledInputWithIcon(
            controller: _titleController,
            placeholder: 'Give your post a title...',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),
          _ContentDivider(),
          const SizedBox(height: 16),
          _FieldLabel(label: "What's on your mind?"),
          const SizedBox(height: 6),
          _StyledTextArea(
            controller: _bodyController,
            placeholder: 'Share something with the community...',
            maxLines: 5,
          ),
        ],
      ],
    );
  }

  // ── Loader ──────────────────────────────────────────────────────────────

  Widget _buildLoader(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: c.primary),
        const SizedBox(height: 16),
        Text('Publishing your post...',
            style: TextStyle(color: c.textMuted, fontSize: 14)),
      ]),
    );
  }

  // ── Media picker (for Image/Video post types) ───────────────────────────

  Widget _buildMediaPicker(BuildContext context, {required bool isVideo}) {
    final c = context.appColors;
    if (_selectedMediaFile != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: isVideo &&
                    _videoPreviewController != null &&
                    _videoPreviewController!.value.isInitialized
                ? SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: AspectRatio(
                      aspectRatio: _videoPreviewController!.value.aspectRatio,
                      child: VideoPlayer(_videoPreviewController!),
                    ),
                  )
                : Image.file(_selectedMediaFile!,
                    height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: _removeMedia,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () async {
        final file = isVideo
            ? await _picker.pickVideo(source: ImageSource.gallery)
            : await _picker.pickImage(source: ImageSource.gallery);
        _pickMedia(file, isVideo);
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: c.border, width: 1.5, style: BorderStyle.solid),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVideo
                  ? Icons.video_collection_outlined
                  : Icons.add_photo_alternate_outlined,
              size: 26,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isVideo ? 'Tap to select video' : 'Tap to select image',
            style: TextStyle(
                fontSize: 13, color: c.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            isVideo ? 'MP4, MOV up to 50MB' : 'JPG, PNG up to 10MB',
            style: TextStyle(fontSize: 11, color: c.textDim),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Sub-widgets ─────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// ── Author strip (in app bar bottom) ──────────────────────────────────────────

class _AuthorStrip extends StatelessWidget {
  final User? user;
  final String uid;
  const _AuthorStrip({required this.user, required this.uid});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        final ud = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = ud['name'] ?? user!.displayName ?? 'You';
        final raw = ud['username'] ?? user!.email?.split('@')[0] ?? 'user';
        final username = raw.startsWith('@') ? raw : '@$raw';
        final avatar =
            ud['profileImageUrl'] ?? ud['photoURL'] ?? user!.photoURL;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
          ),
          child: Row(children: [
            CustomAvatar(name: name, radius: 16, imageUrl: avatar),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.textHi)),
                  Text(username,
                      style: TextStyle(fontSize: 11, color: c.textMuted)),
                ],
              ),
            ),
            // Audience indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.field,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.chipBorder, width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.public_rounded, size: 12, color: c.primary),
                const SizedBox(width: 4),
                Text('Everyone',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.primary)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ── Post type grid ────────────────────────────────────────────────────────────

class _PostTypeGrid extends StatelessWidget {
  final PostType selectedType;
  final void Function(PostType) onSelect;
  final String Function(PostType) labelFor;
  final IconData Function(PostType) iconFor;
  final String Function(PostType) descriptionFor;

  const _PostTypeGrid({
    required this.selectedType,
    required this.onSelect,
    required this.labelFor,
    required this.iconFor,
    required this.descriptionFor,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: PostType.values.map((type) {
        return _PostTypeCard(
          type: type,
          selected: type == selectedType,
          label: labelFor(type),
          icon: iconFor(type),
          description: descriptionFor(type),
          onTap: () => onSelect(type),
        );
      }).toList(),
    );
  }
}

class _PostTypeCard extends StatelessWidget {
  final PostType type;
  final bool selected;
  final String label;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const _PostTypeCard({
    required this.type,
    required this.selected,
    required this.label,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? c.primary.withValues(alpha: 0.1) : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? c.primary : c.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 18, color: selected ? Colors.white : c.primary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? c.primary : c.textHi,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: c.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Help media attachment widget ──────────────────────────────────────────────

class _HelpMediaAttachment extends StatelessWidget {
  final File? mediaFile;
  final bool isVideo;
  final VideoPlayerController? videoController;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onRemove;

  const _HelpMediaAttachment({
    required this.mediaFile,
    required this.isVideo,
    required this.videoController,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Show preview if media selected
    if (mediaFile != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: isVideo &&
                    videoController != null &&
                    videoController!.value.isInitialized
                ? SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: AspectRatio(
                      aspectRatio: videoController!.value.aspectRatio,
                      child: VideoPlayer(videoController!),
                    ),
                  )
                : Image.file(mediaFile!,
                    height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          // Type badge
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  isVideo ? 'Video' : 'Image',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ),
        ],
      );
    }

    // Show dual pick buttons
    return Row(
      children: [
        Expanded(
          child: _MediaPickButton(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Image',
            subtitle: 'JPG, PNG',
            onTap: onPickImage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MediaPickButton(
            icon: Icons.video_collection_outlined,
            label: 'Video',
            subtitle: 'MP4, MOV',
            onTap: onPickVideo,
          ),
        ),
      ],
    );
  }
}

class _MediaPickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MediaPickButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: c.primary),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c.textHi)),
          Text(subtitle, style: TextStyle(fontSize: 9, color: c.textMuted)),
        ]),
      ),
    );
  }
}

// ── Content card ──────────────────────────────────────────────────────────────

class _ContentCard extends StatelessWidget {
  final List<Widget> children;
  const _ContentCard({required this.children});
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _ContentDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(color: context.appColors.divider, thickness: 0.5, height: 1);
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 14, color: c.primary),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textHi,
            letterSpacing: 0.2),
      ),
    ]);
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: context.appColors.textMuted));
}

// ── Styled text area ──────────────────────────────────────────────────────────

class _StyledTextArea extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final int maxLines;
  const _StyledTextArea({
    required this.controller,
    required this.placeholder,
    this.maxLines = 4,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14, color: c.textHi),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
        filled: true,
        fillColor: c.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.primary, width: 1.5)),
      ),
    );
  }
}

// ── Styled input with icon ────────────────────────────────────────────────────

class _StyledInputWithIcon extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  const _StyledInputWithIcon({
    required this.controller,
    required this.placeholder,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 14, color: c.textHi),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: c.textMuted, size: 18),
        filled: true,
        fillColor: c.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.primary, width: 1.5)),
      ),
    );
  }
}

// ── Karma reward row ──────────────────────────────────────────────────────────

class _KarmaRewardRow extends StatelessWidget {
  final TextEditingController controller;
  final String userUid;
  const _KarmaRewardRow({required this.controller, required this.userUid});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return StreamBuilder<int>(
      stream: KarmaService.balanceStream(userUid),
      builder: (context, snap) {
        final balance = snap.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.warningKarmaBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.warningKarmaBorder, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.bolt_rounded, color: c.warningKarma, size: 22),
                const SizedBox(width: 10),
                Text('Karma reward',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.warningKarma)),
                const Spacer(),
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.warningKarma),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                          color: c.warningKarma.withValues(alpha: 0.6)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'Your balance: $balance ⚡  · Deducted immediately on post',
                style: TextStyle(
                    fontSize: 10, color: c.warningKarma.withValues(alpha: 0.7)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Post button (app bar) ─────────────────────────────────────────────────────

class _PostButton extends StatelessWidget {
  final VoidCallback? onTap;
  final LinearGradient gradient;
  const _PostButton({required this.onTap, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: onTap != null ? gradient : null,
          color: onTap == null ? Colors.grey : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Post',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ),
    );
  }
}

// ── Gradient submit button ────────────────────────────────────────────────────

class _GradientSubmitButton extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final bool isLoading;

  const _GradientSubmitButton({
    required this.label,
    required this.gradient,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            else ...[
              const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Tag Picker Section ───────────────────────────────────────────────────────

class _TagPickerSection extends StatelessWidget {
  final Set<String> selectedTags;
  final void Function(String tag) onToggle;

  const _TagPickerSection({
    required this.selectedTags,
    required this.onToggle,
  });

  static const _tagIcons = <String, IconData>{
    'tech': Icons.computer_rounded,
    'art': Icons.palette_rounded,
    'gaming': Icons.videogame_asset_rounded,
    'health': Icons.favorite_rounded,
    'education': Icons.school_rounded,
    'music': Icons.music_note_rounded,
    'food': Icons.restaurant_rounded,
    'travel': Icons.flight_rounded,
    'sports': Icons.sports_soccer_rounded,
    'science': Icons.science_rounded,
    'fashion': Icons.checkroom_rounded,
    'business': Icons.business_center_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label_rounded, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text(
              'Add topic tags',
              style: TextStyle(
                color: c.textHi,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(optional)',
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Helps the right people discover your post.',
          style: TextStyle(color: c.textDim, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAllInterestTags.map((tag) {
            final selected = selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => onToggle(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? c.primary.withValues(alpha: 0.08) : c.field,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? c.primary : c.border,
                    width: selected ? 1.2 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tagIcons[tag] ?? Icons.tag_rounded,
                      size: 13,
                      color: selected ? c.primary : c.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tag[0].toUpperCase() + tag.substring(1),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? c.primary : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

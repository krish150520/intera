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

class CreatePostScreen extends StatefulWidget {
  final String? communityId;
  const CreatePostScreen({super.key, this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  PostType _selectedType  = PostType.text;
  final _titleController  = TextEditingController();
  final _bodyController   = TextEditingController();
  final _rewardController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedMediaFile;
  VideoPlayerController? _videoPreviewController;
  bool _isLoading = false;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF6C63D5);
  static const Color _primaryBg  = Color(0xFFEEF0FB);
  static const Color _fieldBg    = Color(0xFFF5F4FF);
  static const Color _fieldBorder= Color(0xFFE4E2F8);
  static const Color _textDark   = Color(0xFF2D2A6E);
  static const Color _textMuted  = Color(0xFF9E9BD0);
  static const Color _chipBorder = Color(0xFFD8D5F8);

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _rewardController.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _pickMedia(XFile? pickedFile, bool isVideo) async {
    if (pickedFile == null) return;
    await _videoPreviewController?.dispose();
    _videoPreviewController = null;
    setState(() => _selectedMediaFile = File(pickedFile.path));
    if (isVideo) {
      _videoPreviewController =
          VideoPlayerController.file(_selectedMediaFile!)
            ..initialize().then((_) {
              setState(() {});
              _videoPreviewController!.setLooping(true);
              _videoPreviewController!.play();
            });
    }
  }

  String _labelFor(PostType t) => switch (t) {
    PostType.text        => 'Text',
    PostType.question    => 'Question',
    PostType.helpRequest => 'Help',
    PostType.achievement => 'Achievement',
    PostType.image       => 'Image',
    PostType.video       => 'Video',
  };

  IconData _iconFor(PostType t) => switch (t) {
    PostType.text        => Icons.chat_bubble_outline_rounded,
    PostType.question    => Icons.help_outline_rounded,
    PostType.helpRequest => Icons.handshake_outlined,
    PostType.achievement => Icons.emoji_events_outlined,
    PostType.image       => Icons.photo_outlined,
    PostType.video       => Icons.videocam_outlined,
  };

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _snack('You must be logged in.'); return; }

    final isHelp = _selectedType == PostType.helpRequest;
    final title  = _titleController.text.trim();
    final body   = _bodyController.text.trim();
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
    try {
      // ── Upload media ───────────────────────────────────────────────────
      String? mediaUrl;
      if (_selectedMediaFile != null) {
        final ts     = DateTime.now().millisecondsSinceEpoch;
        final isVid  = _selectedType == PostType.video ||
            _selectedMediaFile!.path.toLowerCase().endsWith('.mp4');
        final folder = isVid ? 'posts/videos' : 'posts/images';
        final ext    = isVid ? 'mp4' : 'jpg';
        final ref    = FirebaseStorage.instance
            .ref('$folder/${user.uid}_$ts.$ext');
        final task   = await ref.putFile(_selectedMediaFile!).whenComplete(() {});
        if (task.state != TaskState.success) throw Exception('Upload failed');
        mediaUrl = await ref.getDownloadURL();
      }

      // ── Fetch verified user data ───────────────────────────────────────
      final userDoc     = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final ud          = userDoc.data() ?? {};
      final displayName = ud['name']     ?? user.displayName ?? 'Anonymous';
      final rawUsername = ud['username'] ?? user.email?.split('@')[0] ?? 'user';
      final username    = rawUsername.startsWith('@') ? rawUsername : '@$rawUsername';
      final avatarUrl   = ud['profileImageUrl'] ?? ud['photoURL'] ?? user.photoURL ?? '';

      // ── Build payload ──────────────────────────────────────────────────
      final post = Post(
        id:              '',
        authorId:        user.uid,
        authorName:      displayName,
        authorUsername:  username,
        authorAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        type:            _selectedType,
        title:           isHelp
            ? title
            : title.isNotEmpty
                ? title
                : body.split('\n').first,
        body:            body,
        content:         isHelp ? '$title\n$body' : body,
        imageUrl:        mediaUrl,
        likeCount:       0,
        commentCount:    0,
        shareCount:      0,
        createdAt:       DateTime.now(),
        rewardKarma:     isHelp ? reward : null,
      );

      final payload = post.toFirestore();
      if (isHelp) {
        payload['isCompleted'] = false;
        payload['assignedTo']  = null;
        payload['communityId'] = widget.communityId;
        if (reward > 0) payload['karmaReserved'] = true;
      } else {
        payload['communityId'] = widget.communityId;
      }

      // ── Write to Firestore ─────────────────────────────────────────────
      final docRef = await FirebaseFirestore.instance
          .collection('posts').add(payload);

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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isHelp  = _selectedType == PostType.helpRequest;
    final isImage = _selectedType == PostType.image;
    final isVideo = _selectedType == PostType.video;
    final uid     = FirebaseAuth.instance.currentUser?.uid ?? '';
    final user    = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration:
                BoxDecoration(color: _fieldBg, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: _primary),
          ),
        ),
        title: const Text('New post',
            style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        actions: [
          if (uid.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: KarmaBadge(uid: uid, size: KarmaBadgeSize.small),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isLoading ? null : _submitPost,
              style: TextButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Post',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoader()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Post type chips ────────────────────────────────────
                    const _SectionLabel(label: 'Post type'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: PostType.values.map((type) {
                          final selected = type == _selectedType;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedType = type;
                                _selectedMediaFile = null;
                              }),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? _primary
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? _primary
                                        : _chipBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_iconFor(type),
                                        size: 15,
                                        color: selected
                                            ? Colors.white
                                            : _primary),
                                    const SizedBox(width: 6),
                                    Text(_labelFor(type),
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: selected
                                                ? Colors.white
                                                : _primary)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Post card ──────────────────────────────────────────
                    _PostCard(
                      children: [
                        // Author preview row
                        _AuthorPreviewRow(user: user, uid: uid),
                        const _PostCardDivider(),
                        const SizedBox(height: 14),

                        // ── Media post fields ────────────────────────────
                        if (isImage || isVideo) ...[
                          _buildMediaPicker(isVideo: isVideo),
                          const SizedBox(height: 14),
                          const _FieldLabel(label: 'Caption'),
                          const SizedBox(height: 6),
                          _StyledTextArea(
                            controller: _bodyController,
                            placeholder:
                                'Write a caption for your media...',
                            maxLines: 2,
                          ),
                        ]

                        // ── Help request fields ──────────────────────────
                        else if (isHelp) ...[
                          const _FieldLabel(label: 'Task title *'),
                          const SizedBox(height: 6),
                          _StyledInputWithIcon(
                            controller: _titleController,
                            placeholder: 'Describe the task briefly...',
                            icon: Icons.title_rounded,
                          ),
                          const SizedBox(height: 14),
                          const _PostCardDivider(),
                          const SizedBox(height: 14),
                          const _FieldLabel(label: 'Details'),
                          const SizedBox(height: 6),
                          _StyledTextArea(
                            controller: _bodyController,
                            placeholder:
                                'Explain what needs to be done...',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 14),
                          const _PostCardDivider(),
                          const SizedBox(height: 14),
                          _KarmaRewardRow(
                            controller: _rewardController,
                            userUid: uid,
                          ),
                        ]

                        // ── Normal text / question / achievement fields ───
                        else ...[
                          const _FieldLabel(label: 'Title (optional)'),
                          const SizedBox(height: 6),
                          _StyledInputWithIcon(
                            controller: _titleController,
                            placeholder: 'Give your post a title...',
                            icon: Icons.title_rounded,
                          ),
                          const SizedBox(height: 14),
                          const _PostCardDivider(),
                          const SizedBox(height: 14),
                          const _FieldLabel(
                              label: "What's on your mind?"),
                          const SizedBox(height: 6),
                          _StyledTextArea(
                            controller: _bodyController,
                            placeholder:
                                'Share something with the community...',
                            maxLines: 5,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),

                    _PrimaryButton(
                      label: isHelp
                          ? '🚀  Launch task request'
                          : 'Share post',
                      icon: isHelp ? null : Icons.send_rounded,
                      onTap: _submitPost,
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Visible to everyone in the community',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: _textMuted),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoader() => const Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primary),
              SizedBox(height: 16),
              Text('Publishing your post...',
                  style: TextStyle(color: _textMuted, fontSize: 14)),
            ]),
      );

  Widget _buildMediaPicker({required bool isVideo}) {
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
                      aspectRatio:
                          _videoPreviewController!.value.aspectRatio,
                      child: VideoPlayer(_videoPreviewController!),
                    ),
                  )
                : Image.file(_selectedMediaFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover),
          ),
          GestureDetector(
            onTap: () {
              _videoPreviewController?.pause();
              setState(() => _selectedMediaFile = null);
            },
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.black54,
              child:
                  Icon(Icons.close, color: Colors.white, size: 16),
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
          color: const Color(0xFFF5F4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFC4C1F0),
              width: 1.5,
              style: BorderStyle.solid),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF0FB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo
                      ? Icons.video_collection_outlined
                      : Icons.add_photo_alternate_outlined,
                  size: 26,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isVideo ? 'Tap to select video' : 'Tap to select image',
                style: const TextStyle(
                    fontSize: 13,
                    color: _textMuted,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                isVideo ? 'MP4, MOV up to 50MB' : 'JPG, PNG up to 10MB',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFC4C1F0)),
              ),
            ]),
      ),
    );
  }
}

// ── Author preview row ────────────────────────────────────────────────────────

class _AuthorPreviewRow extends StatelessWidget {
  final User? user;
  final String uid;
  const _AuthorPreviewRow({required this.user, required this.uid});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        final ud       = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name     = ud['name'] ?? user!.displayName ?? 'You';
        final raw      = ud['username'] ?? user!.email?.split('@')[0] ?? 'user';
        final username = raw.startsWith('@') ? raw : '@$raw';
        final avatar   = ud['profileImageUrl'] ?? ud['photoURL'] ?? user!.photoURL;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            CustomAvatar(
              name: name,
              radius: 18,
              imageUrl: avatar,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D2A6E))),
                  Text(username,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9E9BD0))),
                ],
              ),
            ),
            // Audience indicator
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFD8D5F8), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.public_rounded,
                    size: 12, color: Color(0xFF6C63D5)),
                SizedBox(width: 4),
                Text('Everyone',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C63D5))),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8884BB),
          letterSpacing: 0.8));
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF8884BB)));
}

class _PostCard extends StatelessWidget {
  final List<Widget> children;
  const _PostCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E2F8)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children),
      );
}

class _PostCardDivider extends StatelessWidget {
  const _PostCardDivider();
  @override
  Widget build(BuildContext context) => const Divider(
      color: Color(0xFFEAE8FB), thickness: 0.5, height: 1);
}

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
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF2D2A6E)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
              color: Color(0xFFB0ADDE), fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF5F4FF),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFE4E2F8), width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFE4E2F8), width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF6C63D5), width: 1.5)),
        ),
      );
}

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
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF2D2A6E)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
              color: Color(0xFFB0ADDE), fontSize: 14),
          prefixIcon:
              Icon(icon, color: const Color(0xFF9E9BD0), size: 18),
          filled: true,
          fillColor: const Color(0xFFF5F4FF),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFE4E2F8), width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFE4E2F8), width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF6C63D5), width: 1.5)),
        ),
      );
}

class _KarmaRewardRow extends StatelessWidget {
  final TextEditingController controller;
  final String userUid;
  const _KarmaRewardRow(
      {required this.controller, required this.userUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: KarmaService.balanceStream(userUid),
      builder: (context, snap) {
        final balance = snap.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFF5DCAA), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFFC9830A), size: 22),
                const SizedBox(width: 10),
                const Text('Karma reward',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A5010))),
                const Spacer(),
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A5010)),
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle:
                          TextStyle(color: Color(0xFFD4A85C)),
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
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFFA06820)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.label, this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: const Color(0xFF6C63D5),
              borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}
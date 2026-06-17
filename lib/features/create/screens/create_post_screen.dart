import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;
  const CreatePostScreen({super.key, this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  PostType _selectedType = PostType.text;
  final _contentController = TextEditingController();
  final _titleController = TextEditingController();
  final _rewardController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedMediaFile;
  VideoPlayerController? _videoPreviewController;

  bool _isLoading = false;

  // ─── Theme colours ────────────────────────────────────────────────────────
  static const Color _primary     = Color(0xFF6C63D5);
  static const Color _primaryBg   = Color(0xFFEEF0FB);
  static const Color _fieldBg     = Color(0xFFF5F4FF);
  static const Color _fieldBorder = Color(0xFFE4E2F8);
  static const Color _textDark    = Color(0xFF2D2A6E);
  static const Color _textMuted   = Color(0xFF9E9BD0);
  static const Color _chipBorder  = Color(0xFFD8D5F8);
  static const Color _cardBorder  = Color(0xFFE4E2F8);

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _rewardController.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _pickMedia(XFile? pickedFile, bool isVideo) async {
    if (pickedFile == null) return;
    if (_videoPreviewController != null) {
      await _videoPreviewController!.dispose();
      _videoPreviewController = null;
    }
    setState(() => _selectedMediaFile = File(pickedFile.path));
    if (isVideo) {
      _videoPreviewController = VideoPlayerController.file(_selectedMediaFile!)
        ..initialize().then((_) {
          setState(() {});
          _videoPreviewController!.setLooping(true);
          _videoPreviewController!.play();
        });
    }
  }

  String _labelFor(PostType type) {
    switch (type) {
      case PostType.text:        return 'Text';
      case PostType.question:    return 'Question';
      case PostType.helpRequest: return 'Help';
      case PostType.achievement: return 'Achievement';
      case PostType.image:       return 'Image';
      case PostType.video:       return 'Video';
    }
  }

  IconData _iconFor(PostType type) {
    switch (type) {
      case PostType.text:        return Icons.chat_bubble_outline_rounded;
      case PostType.question:    return Icons.help_outline_rounded;
      case PostType.helpRequest: return Icons.handshake_outlined;
      case PostType.achievement: return Icons.emoji_events_outlined;
      case PostType.image:       return Icons.photo_outlined;
      case PostType.video:       return Icons.videocam_outlined;
    }
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  void _submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('You must be logged in to share a post.');
      return;
    }
    if (_contentController.text.trim().isEmpty && _selectedMediaFile == null) {
      _snack('Please add some content or media!');
      return;
    }
    if (_selectedType == PostType.helpRequest && _titleController.text.trim().isEmpty) {
      _snack('Please add a descriptive title for your help request.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? mediaUrl;

      if (_selectedMediaFile != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final isVideoFile = _selectedMediaFile!.path.toLowerCase().endsWith('.mp4') ||
            _selectedType == PostType.video;
        final folder    = isVideoFile ? 'posts/videos' : 'posts/images';
        final extension = isVideoFile ? 'mp4' : 'jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('$folder/${user.uid}_$timestamp.$extension');
        final TaskSnapshot taskSnapshot =
            await storageRef.putFile(_selectedMediaFile!).whenComplete(() {});
        if (taskSnapshot.state == TaskState.success) {
          mediaUrl = await storageRef.getDownloadURL();
        } else {
          throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'upload-failed',
            message: 'Upload did not complete.',
          );
        }
      }

      final userDoc  = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final String verifiedUsername    = userData?['username'] != null
          ? userData!['username']
          : (user.email != null ? '@${user.email!.split("@")[0]}' : '@user');
      final String verifiedDisplayName = userData?['name'] ?? user.displayName ?? 'Anonymous User';

      final Map<String, dynamic> postPayload = {
        'authorId':       user.uid,
        'authorName':     verifiedDisplayName,
        'authorAvatar':   user.photoURL ?? '',
        'authorUsername': verifiedUsername.startsWith('@') ? verifiedUsername : '@$verifiedUsername',
        'type':           _selectedType.name,
        'content':        _contentController.text.trim(),
        'mediaUrl':       mediaUrl,
        'createdAt':      FieldValue.serverTimestamp(),
        'likeCount':      0,
        'commentCount':   0,
        'likedBy':        [],
        'savedBy':        [],
        'communityId':    widget.communityId,
      };

      if (_selectedType == PostType.helpRequest) {
        postPayload['title']        = _titleController.text.trim();
        postPayload['karmaReward']  = int.tryParse(_rewardController.text.trim()) ?? 0;
        postPayload['isCompleted']  = false;
        postPayload['assignedTo']   = null;
      }

      await FirebaseFirestore.instance.collection('posts').add(postPayload);

      if (!mounted) return;
      _snack(
        '🎉 ${_labelFor(_selectedType)} post published!',
        color: const Color(0xFF388E3C),
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/main');
      }
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isHelp  = _selectedType == PostType.helpRequest;
    final isImage = _selectedType == PostType.image;
    final isVideo = _selectedType == PostType.video;

    return Scaffold(
      backgroundColor: _primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _fieldBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _primary),
          ),
        ),
        title: const Text(
          'New post',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: const Text(
              'Post',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
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
                    // ── Type chips ──────────────────────────────────────────
                    _SectionLabel(label: 'Post type'),
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
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected ? _primary : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected ? _primary : _chipBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _iconFor(type),
                                      size: 15,
                                      color: selected ? Colors.white : _primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _labelFor(type),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: selected ? Colors.white : _primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Main card ───────────────────────────────────────────
                    if (!isHelp) ...[
                      _PostCard(
                        children: [
                          if (!isImage && !isVideo) ...[
                            _FieldLabel(label: "What's on your mind?"),
                            const SizedBox(height: 6),
                            _StyledTextArea(
                              controller: _contentController,
                              placeholder: 'Share something with the community...',
                              maxLines: 5,
                            ),
                          ] else ...[
                            _FieldLabel(label: 'Caption'),
                            const SizedBox(height: 6),
                            _StyledTextArea(
                              controller: _contentController,
                              placeholder: 'Write a caption for your media...',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 14),
                            _buildMediaPicker(isVideo: isVideo),
                          ],
                        ],
                      ),
                    ],

                    // ── Help request card ───────────────────────────────────
                    if (isHelp)
                      _PostCard(
                        children: [
                          _FieldLabel(label: 'Task title'),
                          const SizedBox(height: 6),
                          _StyledInputWithIcon(
                            controller: _titleController,
                            placeholder: 'Describe the task briefly...',
                            icon: Icons.title_rounded,
                          ),
                          const SizedBox(height: 14),
                          _PostCardDivider(),
                          const SizedBox(height: 14),
                          _FieldLabel(label: 'Details'),
                          const SizedBox(height: 6),
                          _StyledTextArea(
                            controller: _contentController,
                            placeholder: 'Explain what needs to be done...',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 14),
                          _PostCardDivider(),
                          const SizedBox(height: 14),
                          _KarmaRewardRow(controller: _rewardController),
                        ],
                      ),

                    const SizedBox(height: 28),

                    // ── Submit button ───────────────────────────────────────
                    _PrimaryButton(
                      label: isHelp ? '🚀  Launch task request' : 'Share post',
                      icon: isHelp ? null : Icons.send_rounded,
                      onTap: _submitPost,
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Visible to everyone in the community',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _textMuted),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 16),
          Text('Publishing your post...', style: TextStyle(color: _textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMediaPicker({required bool isVideo}) {
    if (_selectedMediaFile != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: isVideo && _videoPreviewController != null && _videoPreviewController!.value.isInitialized
                ? SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: AspectRatio(
                      aspectRatio: _videoPreviewController!.value.aspectRatio,
                      child: VideoPlayer(_videoPreviewController!),
                    ),
                  )
                : Image.file(
                    _selectedMediaFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
          GestureDetector(
            onTap: () {
              _videoPreviewController?.pause();
              setState(() => _selectedMediaFile = null);
            },
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, color: Colors.white, size: 16),
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
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC4C1F0), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.video_collection_outlined : Icons.add_photo_alternate_outlined,
              size: 36,
              color: _primary,
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Tap to select video' : 'Tap to select image',
              style: const TextStyle(fontSize: 13, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8884BB),
          letterSpacing: 0.8,
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF8884BB),
        ),
      );
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _PostCardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Color(0xFFEAE8FB), thickness: 0.5, height: 1);
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
        style: const TextStyle(fontSize: 14, color: Color(0xFF2D2A6E)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: Color(0xFFB0ADDE), fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF5F4FF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE4E2F8), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE4E2F8), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63D5), width: 1.5),
          ),
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
        style: const TextStyle(fontSize: 14, color: Color(0xFF2D2A6E)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: Color(0xFFB0ADDE), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF9E9BD0), size: 18),
          filled: true,
          fillColor: const Color(0xFFF5F4FF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE4E2F8), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE4E2F8), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63D5), width: 1.5),
          ),
        ),
      );
}

class _KarmaRewardRow extends StatelessWidget {
  final TextEditingController controller;
  const _KarmaRewardRow({required this.controller});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5DCAA), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFFC9830A), size: 22),
            const SizedBox(width: 10),
            const Text(
              'Karma reward',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7A5010),
              ),
            ),
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
                  color: Color(0xFF7A5010),
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Color(0xFFD4A85C)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63D5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}
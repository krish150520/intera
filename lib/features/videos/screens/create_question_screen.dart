import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/services/nsfw_detection_service.dart';

class CreateQuestionScreen extends StatefulWidget {
  final String communityId;
  final String? communityName;

  const CreateQuestionScreen({
    super.key,
    required this.communityId,
    this.communityName,
  });

  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _isPublishing = false;

  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      _snack('Please enter your question.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isPublishing = true);

    try {
      // NSFW check
      final hasNsfwText = await NsfwDetectionService.isTextNsfw(title) ||
          await NsfwDetectionService.isTextNsfw(body);
      if (hasNsfwText) {
        setState(() => _isPublishing = false);
        _snack('Content flagged as inappropriate.', color: Colors.red);
        return;
      }

      // Fetch user info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final ud = userDoc.data() ?? {};
      final displayName = ud['name'] ?? user.displayName ?? 'Anonymous';
      final rawUsername =
          ud['username'] ?? user.email?.split('@')[0] ?? 'user';
      final username =
          rawUsername.startsWith('@') ? rawUsername : '@$rawUsername';
      final avatarUrl =
          ud['profileImageUrl'] ?? ud['photoURL'] ?? user.photoURL ?? '';

      final post = Post(
        id: '',
        authorId: user.uid,
        authorName: displayName,
        authorUsername: username,
        authorAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        type: PostType.question,
        title: title,
        body: body,
        content: body.isNotEmpty ? '$title\n$body' : title,
        communityId: widget.communityId,
        createdAt: DateTime.now(),
        tags: _selectedTags.toList(),
      );

      final payload = post.toFirestore();
      payload['communityId'] = widget.communityId;
      payload['visibility'] = 'Public';
      payload['allowComments'] = true;

      await FirebaseFirestore.instance.collection('posts').add(payload);

      if (mounted) {
        _snack('❓ Question published!', color: const Color(0xFF388E3C));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _snack('Failed to publish: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
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

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ask a Question',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _isPublishing ? null : _publish,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isPublishing ? c.field : c.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Publish',
                  style: TextStyle(
                    color: _isPublishing ? c.textMuted : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isPublishing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: c.primary),
                  const SizedBox(height: 16),
                  Text('Publishing question...',
                      style: TextStyle(
                          color: c.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Community badge
                  if (widget.communityName != null)
                    _buildStaggered(
                      0,
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_rounded,
                                color: c.primary, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              widget.communityName!,
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
                  const SizedBox(height: 20),

                  // Inputs Card
                  _buildStaggered(
                    50,
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: c.border.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleController,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              hintText: 'What is your question? *',
                              hintStyle: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                              border: InputBorder.none,
                            ),
                          ),
                          Divider(
                              color: c.border.withOpacity(0.5),
                              height: 24),
                          TextField(
                            controller: _bodyController,
                            maxLines: null,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14,
                                height: 1.5),
                            decoration: InputDecoration(
                              hintText:
                                  'Add details or context (optional)...',
                              hintStyle: TextStyle(
                                  color: c.textMuted, fontSize: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags Picker
                  _buildStaggered(
                    100,
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: c.border.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tag_rounded,
                                  color: c.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Tags & Topics',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              'help',
                              'question',
                              'tech',
                              'flutter',
                              'design',
                              'college'
                            ].map((tag) {
                              final isSelected =
                                  _selectedTags.contains(tag);
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? c.primary.withOpacity(0.15)
                                        : c.field,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? c.primary
                                          : c.border.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      color: isSelected
                                          ? c.primary
                                          : c.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStaggered(int delayMs, Widget child) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + delayMs),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, childWidget) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: childWidget),
        );
      },
      child: child,
    );
  }
}

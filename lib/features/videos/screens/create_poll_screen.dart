import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../core/services/nsfw_detection_service.dart';

class CreatePollScreen extends StatefulWidget {
  final String communityId;
  final String? communityName;

  const CreatePollScreen({
    super.key,
    required this.communityId,
    this.communityName,
  });

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen>
    with SingleTickerProviderStateMixin {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isPublishing = false;
  int _durationIndex = 3; // default: 1 day

  final List<Map<String, dynamic>> _durations = [
    {'label': 'No expiry', 'duration': null},
    {'label': '1 hour', 'duration': const Duration(hours: 1)},
    {'label': '6 hours', 'duration': const Duration(hours: 6)},
    {'label': '1 day', 'duration': const Duration(days: 1)},
    {'label': '3 days', 'duration': const Duration(days: 3)},
    {'label': '1 week', 'duration': const Duration(days: 7)},
  ];

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
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _animCtrl.dispose();
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 5) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  Future<void> _publish() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      _snack('Please enter your poll question.');
      return;
    }

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (options.length < 2) {
      _snack('Add at least 2 poll options.');
      return;
    }

    // Check for duplicate options
    if (options.toSet().length != options.length) {
      _snack('Poll options must be unique.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isPublishing = true);

    try {
      // NSFW check
      final hasNsfwText = await NsfwDetectionService.isTextNsfw(question);
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

      // Build poll votes map
      final Map<String, int> pollVotes = {};
      for (final opt in options) {
        pollVotes[opt] = 0;
      }

      // Calculate expiry
      DateTime? expiresAt;
      final dur = _durations[_durationIndex]['duration'] as Duration?;
      if (dur != null) {
        expiresAt = DateTime.now().add(dur);
      }

      final post = Post(
        id: '',
        authorId: user.uid,
        authorName: displayName,
        authorUsername: username,
        authorAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        type: PostType.poll,
        title: question,
        body: '',
        content: question,
        communityId: widget.communityId,
        createdAt: DateTime.now(),
        pollOptions: options,
        pollVotes: pollVotes,
        pollVotedBy: [],
        totalVotes: 0,
        pollExpiresAt: expiresAt,
      );

      final payload = post.toFirestore();
      payload['communityId'] = widget.communityId;
      payload['visibility'] = 'Public';
      payload['allowComments'] = true;

      await FirebaseFirestore.instance.collection('posts').add(payload);

      if (mounted) {
        _snack('📊 Poll published!', color: const Color(0xFF388E3C));
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
          'Create Poll',
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
                  Text('Publishing poll...',
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
                          color: c.primary.withValues(alpha: 0.08),
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

                  // Question input
                  _buildStaggered(
                    50,
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: c.border.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.poll_rounded,
                                  color: c.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Poll Question',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _questionController,
                            maxLines: null,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              hintText: 'Ask your community something...',
                              hintStyle: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Poll options
                  _buildStaggered(
                    100,
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: c.border.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.list_alt_rounded,
                                  color: c.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Options',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_optionControllers.length}/5',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...List.generate(_optionControllers.length,
                              (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color:
                                          c.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: c.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _optionControllers[index],
                                      style: TextStyle(
                                          color: c.textPrimary,
                                          fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Option ${index + 1}',
                                        hintStyle: TextStyle(
                                            color: c.textMuted,
                                            fontSize: 14),
                                        filled: true,
                                        fillColor: c.field,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  16),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets
                                                .symmetric(
                                                horizontal: 16,
                                                vertical: 12),
                                      ),
                                    ),
                                  ),
                                  if (_optionControllers.length > 2)
                                    IconButton(
                                      icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: c.error,
                                          size: 20),
                                      onPressed: () =>
                                          _removeOption(index),
                                    ),
                                ],
                              ),
                            );
                          }),
                          if (_optionControllers.length < 5)
                            TextButton.icon(
                              onPressed: _addOption,
                              icon: Icon(Icons.add_circle_outline,
                                  color: c.primary, size: 18),
                              label: Text(
                                'Add Option',
                                style: TextStyle(
                                  color: c.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Duration picker
                  _buildStaggered(
                    150,
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: c.border.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  color: c.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Poll Duration',
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
                            children: List.generate(
                                _durations.length, (index) {
                              final isSelected =
                                  _durationIndex == index;
                              return GestureDetector(
                                onTap: () => setState(
                                    () => _durationIndex = index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? c.primary.withValues(alpha: 0.15)
                                        : c.field,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? c.primary
                                          : c.border.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _durations[index]['label']
                                        as String,
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
                            }),
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

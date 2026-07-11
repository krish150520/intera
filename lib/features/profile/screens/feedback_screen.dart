import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';


enum _FeedbackType { bug, suggestion, complaint, praise, other }

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  _FeedbackType _type   = _FeedbackType.suggestion;
  int           _rating = 0; // 0 = not rated yet
  final _bodyCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted  = false;

  // ── Theme helpers ──────────────────────────────────────────────────────────
  ColorScheme get _cs  => Theme.of(context).colorScheme;
  bool get _isDark     => Theme.of(context).brightness == Brightness.dark;
  Color get _bg        => Theme.of(context).scaffoldBackgroundColor;
  Color get _surface   => _cs.surface;
  Color get _primary   => _cs.primary;
  Color get _border    => _isDark ? AppColors.darkBorder    : AppColors.lightBorder;
  Color get _field     => _isDark ? AppColors.darkField     : AppColors.lightField;
  Color get _textDark  => _isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
  Color get _textMuted => _isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

  @override
  void initState() {
    super.initState();
    // Pre-fill email if logged in
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    _emailCtrl.text = email;
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      _snack('Please describe your feedback before submitting.');
      return;
    }
    setState(() => _submitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('feedback').add({
        'uid':       user?.uid,
        'email':     _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim()
            : (user?.email ?? ''),
        'type':      _type.name,
        'rating':    _rating,
        'body':      body,
        'createdAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
      });

      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('Failed to send: $e');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Feedback',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Thank you!',
                style: TextStyle(
                    color: _textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps us make INTERA better for everyone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back to settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Star rating ────────────────────────────────────────────────
          _Card(children: [
            _Label('How would you rate INTERA?'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 36,
                      color: filled
                          ? AppColors.warningKarma
                          : _textMuted,
                    ),
                  ),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _ratingLabel(_rating),
                  style: TextStyle(
                      color: AppColors.warningKarma,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // ── Feedback type ──────────────────────────────────────────────
          _SectionLabel('CATEGORY'),
          const SizedBox(height: 8),
          _Card(children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _FeedbackType.values.map((t) {
                final selected = t == _type;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _primary : _field,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? _primary : _border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcon(t),
                            size: 14,
                            color: selected ? Colors.white : _primary),
                        const SizedBox(width: 6),
                        Text(_typeLabel(t),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.white : _primary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Message ────────────────────────────────────────────────────
          _SectionLabel('YOUR FEEDBACK'),
          const SizedBox(height: 8),
          _Card(children: [
            _Label(_bodyPlaceholderLabel()),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              maxLines: 6,
              maxLength: 1000,
              style: TextStyle(fontSize: 14, color: _textDark),
              decoration: InputDecoration(
                hintText: _bodyHint(),
                hintStyle: TextStyle(color: _textMuted, fontSize: 13),
                filled: true,
                fillColor: _field,
                counterStyle: TextStyle(color: _textMuted, fontSize: 11),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primary, width: 1.5)),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Contact email ──────────────────────────────────────────────
          _SectionLabel('CONTACT (OPTIONAL)'),
          const SizedBox(height: 8),
          _Card(children: [
            _Label('Email for follow-up'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(fontSize: 14, color: _textDark),
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: TextStyle(color: _textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.mail_outline_rounded,
                    color: _textMuted, size: 18),
                filled: true,
                fillColor: _field,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Leave blank to submit anonymously.',
              style: TextStyle(color: _textMuted, fontSize: 11),
            ),
          ]),

          const SizedBox(height: 28),

          // ── Submit ─────────────────────────────────────────────────────
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Send feedback',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
          ),

          const SizedBox(height: 12),
          Text(
            'Feedback is reviewed by the INTERA team. '
            'We read everything.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _ratingLabel(int r) => switch (r) {
    1 => 'Needs a lot of work 😟',
    2 => 'Could be better 😕',
    3 => 'It\'s okay 🙂',
    4 => 'Pretty good 😊',
    5 => 'Love it! 🎉',
    _ => '',
  };

  String _typeLabel(_FeedbackType t) => switch (t) {
    _FeedbackType.bug        => 'Bug report',
    _FeedbackType.suggestion => 'Suggestion',
    _FeedbackType.complaint  => 'Complaint',
    _FeedbackType.praise     => 'Praise',
    _FeedbackType.other      => 'Other',
  };

  IconData _typeIcon(_FeedbackType t) => switch (t) {
    _FeedbackType.bug        => Icons.bug_report_outlined,
    _FeedbackType.suggestion => Icons.lightbulb_outline_rounded,
    _FeedbackType.complaint  => Icons.warning_amber_rounded,
    _FeedbackType.praise     => Icons.favorite_border_rounded,
    _FeedbackType.other      => Icons.more_horiz_rounded,
  };

  String _bodyPlaceholderLabel() => switch (_type) {
    _FeedbackType.bug        => 'Describe the bug',
    _FeedbackType.suggestion => 'Describe your idea',
    _FeedbackType.complaint  => 'Tell us what went wrong',
    _FeedbackType.praise     => 'What do you love?',
    _FeedbackType.other      => 'Your message',
  };

  String _bodyHint() => switch (_type) {
    _FeedbackType.bug        => 'Steps to reproduce, what you expected, what happened...',
    _FeedbackType.suggestion => 'What feature would make INTERA better for you?',
    _FeedbackType.complaint  => 'We\'re sorry to hear that — please tell us more.',
    _FeedbackType.praise     => 'We\'d love to hear what you enjoy about INTERA!',
    _FeedbackType.other      => 'Anything you\'d like to share with us...',
  };
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8)),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;
    return Text(label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: muted));
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

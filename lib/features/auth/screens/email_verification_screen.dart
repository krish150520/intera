import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/custom_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    AuthService.instance.sendEmailVerification();
    // Auto-poll every 4s in case they verify in another tab/app and come back.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkVerified(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (!silent) setState(() => _isChecking = true);
    await AuthService.instance.reloadUser();
    if (!mounted) return;

    if (AuthService.instance.isVerified) {
      _pollTimer?.cancel();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
      return;
    }
    if (!silent) {
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not verified yet — check your inbox.')),
      );
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    await AuthService.instance.sendEmailVerification();
    if (!mounted) return;
    setState(() => _isResending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? 'your email';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 64, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text('Verify your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 12),
              Text(
                'We sent a confirmation link to $email. Open it, then come back here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: "I've verified, continue",
                isLoading: _isChecking,
                onPressed: () => _checkVerified(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isResending ? null : _resend,
                child: Text(_isResending ? 'Sending...' : 'Resend email'),
              ),
              TextButton(
                onPressed: () async {
                  await AuthService.instance.signOut();
                  if (!mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
                },
                child: const Text('Sign out', style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
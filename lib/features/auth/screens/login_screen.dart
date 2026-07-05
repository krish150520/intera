import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('prefillEmail')) {
      _identifierController.text = args['prefillEmail'] ?? '';
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final emailVal = _identifierController.text.trim();
    final passVal = _passwordController.text;

    try {
      final credentials = await AuthService.instance.signIn(
        email: emailVal,
        password: passVal,
      );

      if (credentials.user != null) {
        await AuthService.instance.ensureUserProfileExists(credentials.user!);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pass_for_$emailVal', passVal);

        final list = prefs.getStringList('recent_accounts') ?? [];
        list.remove(emailVal);
        list.insert(0, emailVal);
        if (list.length > 5) list.removeRange(5, list.length);
        await prefs.setStringList('recent_accounts', list);
      }

      if (!mounted) return;
      final route = AuthService.instance.isVerified ? AppRoutes.main : AppRoutes.verifyEmail;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication rejected.'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final credentials = await AuthService.instance.signInWithGoogle();
      if (credentials.user != null) {
        await AuthService.instance.ensureUserProfileExists(credentials.user!);
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'sign-in-cancelled') return; // user backed out, no error needed
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed.'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleForgotPassword() async {
    final email = _identifierController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write your email address in the input field first to request a reset link.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    try {
      await AuthService.instance.sendPasswordReset(email);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset Link Issued'),
          content: Text('A secure link has been transmitted over to $email. Please check your inbox or spam folders to complete your configuration changes.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset sequence failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text(AppStrings.login, style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: c.surface,
        foregroundColor: c.textHi,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Welcome back',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: c.textHi)),
                  const SizedBox(height: 6),
                  Text('Log in to continue earning Karma.',
                      style: TextStyle(color: c.textMuted, fontSize: 14)),
                  const SizedBox(height: 36),
                  CustomTextField(
                    label: AppStrings.emailOrPhone,
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your registered email address.';
                      }
                      if (!value.contains('@')) {
                        return 'Please structure a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  CustomTextField(
                    label: AppStrings.password,
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_open_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password string entry required.';
                      if (value.length < 6) return 'Password lengths must clear at least 6 characters.';
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: Text(AppStrings.forgotPassword,
                          style: TextStyle(color: c.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(label: AppStrings.login, isLoading: _isLoading, onPressed: _handleLogin),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: c.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(color: c.textMuted)),
                      ),
                      Expanded(child: Divider(color: c.border)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: Icon(Icons.g_mobiledata, size: 28, color: c.textHi),
                    label: Text('Continue with Google', style: TextStyle(color: c.textHi)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: c.border),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
                      child: Text(AppStrings.dontHaveAccount, style: TextStyle(color: c.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
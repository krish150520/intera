import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _scale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
    );
    
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
    );

    _ctrl.forward();
    _navigateNext();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    String route = AppRoutes.welcome;

    try {
      // Allow the animation to play beautifully
      await Future.delayed(const Duration(milliseconds: 2500));

      final auth = AuthService.instance;
      if (auth.isLoggedIn) {
        await auth.reloadUser();
        route = auth.isVerified ? AppRoutes.main : AppRoutes.verifyEmail;
      }
    } catch (e, st) {
      debugPrint('Splash navigation error: $e\n$st');
    }

    if (!mounted) return;

    try {
      Navigator.of(context).pushReplacementNamed(route);
    } catch (e, st) {
      debugPrint('Navigation failed for route "$route": $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Center Branding ───────────────────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glowing logo squircle with scale animation
                  ScaleTransition(
                    scale: _scale,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              c.primary,
                              c.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: c.primary.withValues(alpha: 0.25),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: c.primary.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Decorative background circles
                            Positioned(
                              top: -10,
                              left: -10,
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            // Logo letter mark
                            const Center(
                              child: Text(
                                'IN',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Brand title with fade-in animation
                  FadeTransition(
                    opacity: _fade,
                    child: Column(
                      children: [
                        Text(
                          AppStrings.appName.toUpperCase(),
                          style: TextStyle(
                            color: c.textHi,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.tagline,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Loading indicator at the bottom ───────────────────────────
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        child: LinearProgressIndicator(
                          minHeight: 2.5,
                          backgroundColor: c.field,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            c.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'INTERACTION DESIGNED',
                        style: TextStyle(
                          color: c.textDim,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
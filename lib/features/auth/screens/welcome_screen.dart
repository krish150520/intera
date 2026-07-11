import 'package:flutter/material.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/custom_button.dart';

/// Screen 2: Welcome Screen
/// Entry point with Login and Sign Up actions.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Squircle logo (no image asset) ───────────────────────────
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative ghost circle (top-left)
                    Positioned(
                      top: -10,
                      left: -10,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    // "IN" lettermark
                    const Text(
                      'IN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                AppStrings.appName,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.tagline,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(flex: 3),
              CustomButton(
                label: AppStrings.login,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.login),
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: AppStrings.signUp,
                type: CustomButtonType.outline,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.signup),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

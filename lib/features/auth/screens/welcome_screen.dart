import 'package:flutter/material.dart';
import '../../../core/constants/strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../core/constants/assets.dart';

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
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Image.asset(
                    AppAssets.logo,
                    fit: BoxFit.contain,
                  ),
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

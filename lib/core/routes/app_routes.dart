import 'package:flutter/material.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/navigation/screens/bottom_nav_screen.dart';
import '../../features/home/screens/post_detail_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/create/screens/create_post_screen.dart';
import '../../features/create/screens/create_community_screen.dart';
import '../../features/home/screens/create_spark_screen.dart';
import '../../shared/models/post_model.dart';

/// Centralized named-route definitions for INTERA.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verifyEmail = '/verify-email';
  static const String main = '/main';
  static const String postDetail = '/post-detail';
  static const String editProfile = '/edit-profile';
  static const String createPost = '/create-post';
  static const String createCommunity = '/create-community';
  static const String createSpark = '/create-spark';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        welcome: (context) => const WelcomeScreen(),
        login: (context) => const LoginScreen(),
        signup: (context) => const SignUpScreen(),
        verifyEmail: (context) => const EmailVerificationScreen(),
        main: (context) => const BottomNavScreen(),
        editProfile: (context) => const EditProfileScreen(),
        createPost: (context) => const CreatePostScreen(),
        createCommunity: (context) => const CreateCommunityScreen(),
        createSpark: (context) => const CreateSparkScreen(),
      };

  /// For routes that need arguments (e.g. PostDetailScreen needs a [Post]),
  /// use onGenerateRoute in MaterialApp pointing here.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case postDetail:
        final post = settings.arguments as Post?;
        return MaterialPageRoute(
          builder: (context) => PostDetailScreen(post: post),
        );
      default:
        return null;
    }
  }
}
import 'package:flutter/material.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/setup_username_screen.dart';
import '../../features/navigation/screens/bottom_nav_screen.dart';
import '../../features/home/screens/post_detail_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/create/screens/create_post_screen.dart';
import '../../features/create/screens/create_community_screen.dart';
import '../../features/home/screens/create_spark_screen.dart';
import '../../features/echos/screens/echo_viewer_screen.dart';
import '../../features/echos/screens/create_echo_screen.dart';
import '../../features/echos/screens/audio_page_screen.dart';
import '../../features/echos/screens/create_audio_screen.dart';
import '../../features/create/screens/create_help_post_screen.dart';
import '../../shared/models/post_model.dart';

/// Centralized named-route definitions for INTERA.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verifyEmail = '/verify-email';
  static const String setupUsername = '/setup-username';
  static const String main = '/main';
  static const String postDetail = '/post-detail';
  static const String editProfile = '/edit-profile';
  static const String createPost = '/create-post';
  static const String createCommunity = '/create-community';
  static const String createSpark = '/create-spark';
  static const String echoViewer = '/echo-viewer';
  static const String createEcho = '/create-echo';
  static const String audioPage = '/audio-page';
  static const String createAudio = '/create-audio';
  static const String createHelpPost = '/create-help-post';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        welcome: (context) => const WelcomeScreen(),
        login: (context) => const LoginScreen(),
        signup: (context) => const SignUpScreen(),
        verifyEmail: (context) => const EmailVerificationScreen(),
        setupUsername: (context) => const SetupUsernameScreen(),
        main: (context) => const BottomNavScreen(),
        editProfile: (context) => const EditProfileScreen(),
        createPost: (context) => const CreatePostScreen(),
        createCommunity: (context) => const CreateCommunityScreen(),
        createSpark: (context) => const CreateSparkScreen(),
        createAudio: (context) => const CreateAudioScreen(),
        createHelpPost: (context) => const CreateHelpPostScreen(),
      };

 
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case postDetail:
        if (settings.arguments is Post) {
          final post = settings.arguments as Post;
          return MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: post),
          );
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          final post = args['post'] as Post?;
          final heroTag = args['heroTag'] as String?;
          return MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: post, heroTag: heroTag),
          );
        }
        return MaterialPageRoute(
          builder: (context) => const PostDetailScreen(),
        );
      case echoViewer:
        final args = settings.arguments as Map<String, dynamic>?;
        final posts = args?['posts'] as List<Post>? ?? [];
        final initialIndex = args?['initialIndex'] as int? ?? 0;
        return MaterialPageRoute(
          builder: (context) => EchoViewerScreen(posts: posts, initialIndex: initialIndex),
        );
      case createEcho:
        final args = settings.arguments as Map<String, dynamic>?;
        final audioId = args?['audioId'] as String?;
        final audioTitle = args?['audioTitle'] as String?;
        final audioAuthorId = args?['audioAuthorId'] as String?;
        return MaterialPageRoute(
          builder: (context) => CreateEchoScreen(
            audioId: audioId,
            audioTitle: audioTitle,
            audioAuthorId: audioAuthorId,
          ),
        );
      case audioPage:
        final args = settings.arguments as Map<String, dynamic>?;
        final audioId = args?['audioId'] as String? ?? '';
        final audioTitle = args?['audioTitle'] as String?;
        final audioAuthorId = args?['audioAuthorId'] as String?;
        return MaterialPageRoute(
          builder: (context) => AudioPageScreen(
            audioId: audioId,
            audioTitle: audioTitle,
            audioAuthorId: audioAuthorId,
          ),
        );
      case createHelpPost:
        final args = settings.arguments as Map<String, dynamic>?;
        final communityId = args?['communityId'] as String?;
        return MaterialPageRoute(
          builder: (context) => CreateHelpPostScreen(initialCommunityId: communityId),
        );
      default:
        return null;
    }
  }
}

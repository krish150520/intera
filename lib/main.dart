import 'package:flutter/material.dart';
import 'core/constants/strings.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.initTheme();
  runApp(const InteraApp());
}


class InteraApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const InteraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: AppStrings.appName,
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentMode,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          builder: (context, child) {
            final isDark = currentMode == ThemeMode.system
                ? MediaQuery.of(context).platformBrightness == Brightness.dark
                : currentMode == ThemeMode.dark;
            return Material(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF2A2F55), Color(0xFF171A30)]
                        : const [Color(0xFFD8E2FF), Color(0xFFA7B7E7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

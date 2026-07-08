import 'package:flutter/material.dart';
import 'core/constants/strings.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InteraApp());
}

/// Root widget for the INTERA app.
class InteraApp extends StatelessWidget {
  const InteraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
  }
}

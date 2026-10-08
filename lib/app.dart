
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

import 'features/auth/splash_screen.dart';
import 'features/auth/google_signin_screen.dart';

// =====================================
// MY MEDICAL HISTORY - MAIN APP
// =====================================

class MyMedicalHistoryApp extends StatelessWidget {
  const MyMedicalHistoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // =====================================
      // APPLICATION INFORMATION
      // =====================================

      title: 'My Medical History',

      debugShowCheckedModeBanner: false,

      // =====================================
      // APPLICATION THEME
      // =====================================

      theme: AppTheme.lightTheme,

      themeMode: ThemeMode.light,

      // =====================================
      // FIRST SCREEN - SPLASH
      // =====================================

      home: const SplashScreen(
        nextScreen: GoogleSignInScreen(),
      ),
    );
  }
}

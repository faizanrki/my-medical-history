
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Controls the logo animation
  bool _showLogo = false;

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  // Start animation and open the next screen
  Future<void> _startSplash() async {
    // Small delay before showing the logo
    await Future.delayed(
      const Duration(milliseconds: 200),
    );

    if (!mounted) return;

    setState(() {
      _showLogo = true;
    });

    // Show the splash screen briefly
    await Future.delayed(
      const Duration(milliseconds: 2200),
    );

    if (!mounted) return;

    // Replace splash with the next screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => widget.nextScreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Center(
          child: AnimatedOpacity(
            opacity: _showLogo ? 1.0 : 0.0,
            duration: const Duration(
              milliseconds: 800,
            ),

            child: AnimatedScale(
              scale: _showLogo ? 1.0 : 0.85,
              duration: const Duration(
                milliseconds: 800,
              ),
              curve: Curves.easeOutCubic,

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App logo
                  Image.asset(
                    'assets/images/my_medical_history_splash_icon.png',
                    width: 190,
                    height: 190,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 24),

                  // App title
                  const Text(
                    'My Medical History',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // App tagline
                  const Text(
                    'Your health records, always with you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
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

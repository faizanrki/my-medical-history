
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';
import 'data/app_database.dart';

// ==========================================
// MY MEDICAL HISTORY
// SECURE STARTUP + GOOGLE DRIVE FIX
// STEP 45 - UPDATED MAIN.DART
// ==========================================

// This must be the WEB APPLICATION
// OAuth Client ID from Google Cloud.
//
// This ID is not a client secret.

const String _googleWebClientId =
    '1034931391245-7meob6r56ovvlgv13nhv1s4qbu4qbk9j.apps.googleusercontent.com';

// ==========================================
// MAIN APPLICATION ENTRY POINT
// ==========================================

Future<void> main() async {
  // ========================================
  // INITIALIZE FLUTTER
  // ========================================

  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ======================================
    // STEP 1 - LOCK MEDICAL STORAGE
    // ======================================

    // Never open an account-specific
    // database before Google Sign-In.
    //
    // This does not delete databases,
    // medical records, or encryption keys.

    await AppDatabase.instance.lockAccount();

    // ======================================
    // STEP 2 - INITIALIZE GOOGLE SIGN-IN
    // ======================================

    // IMPORTANT:
    //
    // Supply the WEB OAuth Client ID
    // through serverClientId.
    //
    // Wait until initialization completes
    // before starting the application.
    //
    // Do not ignore initialization errors.

    await GoogleSignIn.instance.initialize(
      serverClientId: _googleWebClientId,
    );

    // ======================================
    // STEP 3 - START MY MEDICAL HISTORY
    // ======================================

    // app.dart opens the Splash Screen.
    //
    // The Google Sign-In screen then
    // authenticates the user.
    //
    // The user's account-specific encrypted
    // database must be opened only after
    // successful Google authentication.

    runApp(const MyMedicalHistoryApp());
  } catch (error) {
    // ======================================
    // SECURE STARTUP FAILURE
    // ======================================

    // If initialization fails:
    //
    // - Do not open the medical database.
    // - Do not bypass authentication.
    // - Do not delete medical records.
    // - Do not create replacement keys.
    //
    // Print only the exception type.
    // Do not print tokens or private data.

    debugPrint(
      'Secure startup failed: '
          '${error.runtimeType}',
    );

    runApp(
      const _SecureStartupUnavailableApp(),
    );
  }
}

// ==========================================
// SECURE STARTUP ERROR APPLICATION
// ==========================================

class _SecureStartupUnavailableApp
    extends StatelessWidget {
  const _SecureStartupUnavailableApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Medical History',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769E8),
        ),
      ),

      home: Scaffold(
        backgroundColor:
        const Color(0xFFF5F8FC),

        appBar: AppBar(
          title: const Text(
            'My Medical History',
          ),
        ),

        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  // ========================
                  // ERROR ICON
                  // ========================

                  const Icon(
                    Icons.lock_outline,
                    size: 72,
                    color: Color(0xFFE74C3C),
                  ),

                  const SizedBox(height: 22),

                  // ========================
                  // TITLE
                  // ========================

                  const Text(
                    'Secure Startup Unavailable',

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B4D),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ========================
                  // EXPLANATION
                  // ========================

                  const Text(
                    'The application could not '
                        'initialize Google Sign-In '
                        'or secure medical storage.',

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF718096),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ========================
                  // DATA SAFETY CARD
                  // ========================

                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFFF4E5,
                      ),

                      borderRadius:
                      BorderRadius.circular(14),
                    ),

                    child: const Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFFE67E22),
                        ),

                        SizedBox(height: 12),

                        Text(
                          'Your medical records '
                              'have not been '
                              'intentionally deleted.\n\n'
                              'Do not uninstall this '
                              'app or clear its data '
                              'while fixing the '
                              'Google configuration.',

                          textAlign: TextAlign.center,

                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ========================
                  // RECOVERY INSTRUCTIONS
                  // ========================

                  const Text(
                    'Check the Web OAuth Client ID, '
                        'Android app configuration, '
                        'and Google Sign-In setup. '
                        'Then close and reopen the app.',

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black54,
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

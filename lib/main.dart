
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';

// =====================================
// MY MEDICAL HISTORY - SECURE STARTUP
// STEP 44.3
// =====================================

Future<void> main() async {
  // =====================================
  // INITIALIZE FLUTTER
  // =====================================

  WidgetsFlutterBinding.ensureInitialized();

  try {
    // =====================================
    // LOCK MEDICAL STORAGE BEFORE LOGIN
    // =====================================

    // Do not open the legacy database here.
    //
    // Google authentication must happen
    // before selecting a medical database.
    //
    // This protects the startup flow from
    // accessing records before login.

    await AppDatabase.instance.lockAccount();

    // =====================================
    // START APPLICATION
    // =====================================

    // app.dart starts SplashScreen and then
    // GoogleSignInScreen.
    //
    // GoogleSignInScreen will select the
    // authenticated account's database
    // before entering Dashboard.

    runApp(const MyMedicalHistoryApp());
  } catch (_) {
    // =====================================
    // SECURE STARTUP FAILURE
    // =====================================

    // Do not open another database.
    //
    // Do not delete records or encryption keys.
    //
    // Do not print sensitive information.

    assert(() {
      debugPrint(
        'Secure application startup failed.',
      );

      return true;
    }());

    runApp(const _SecureStartupUnavailableApp());
  }
}

// =====================================
// SECURE STARTUP UNAVAILABLE SCREEN
// =====================================

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
                  // =================================
                  // SECURITY ICON
                  // =================================

                  const Icon(
                    Icons.lock_outline,

                    size: 72,

                    color: Color(0xFFE74C3C),
                  ),

                  const SizedBox(height: 22),

                  // =================================
                  // SCREEN TITLE
                  // =================================

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

                  // =================================
                  // EXPLANATION
                  // =================================

                  const Text(
                    'The application could not '
                        'initialize secure medical '
                        'storage access.',

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF718096),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================
                  // DATA SAFETY INFORMATION
                  // =================================

                  Container(
                    width: double.infinity,

                    padding:
                    const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),

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
                          'No database reset or deletion '
                              'was requested.\n\n'
                              'Do not uninstall the app or '
                              'clear its storage while '
                              'recovering medical data.',

                          textAlign: TextAlign.center,

                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================
                  // RECOVERY MESSAGE
                  // =================================

                  const Text(
                    'Close and reopen the app once. '
                        'If the problem continues, '
                        'review the storage configuration '
                        'before trying again.',

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 13,
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


import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../home/dashboard_screen.dart';
import 'drive_setup_screen.dart';

// =====================================
// STEP 44.6 - GOOGLE SIGN-IN
// =====================================

class GoogleSignInScreen extends StatefulWidget {
  // Used after signing out so the app
  // does not automatically restore a user.
  final bool skipAutomaticSignIn;

  // Optional message from the sign-out flow.
  final String? notice;

  const GoogleSignInScreen({
    super.key,
    this.skipAutomaticSignIn = false,
    this.notice,
  });

  @override
  State<GoogleSignInScreen> createState() =>
      _GoogleSignInScreenState();
}

class _GoogleSignInScreenState
    extends State<GoogleSignInScreen> {

  // =====================================
  // GOOGLE AUTHENTICATION
  // =====================================

  final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;

  static const String _serverClientId =
  String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  // Initialize Google Sign-In only once
  // during this app process.
  static Future<void>? _initializationFuture;

  bool _isInitializing = true;
  bool _isSigningIn = false;
  bool _hasNavigated = false;

  String? _errorMessage;

  // =====================================
  // INITIALIZE SCREEN
  // =====================================

  @override
  void initState() {
    super.initState();

    _errorMessage = widget.notice;
    _initializeAuthentication();
  }

  // =====================================
  // INITIALIZE GOOGLE SDK ONCE
  // =====================================

  Future<void> _ensureGoogleInitialized() async {
    _initializationFuture ??=
        _googleSignIn.initialize(
          serverClientId: _serverClientId.isEmpty
              ? null
              : _serverClientId,
        );

    try {
      await _initializationFuture;
    } catch (_) {
      // Do not retain a failed initialization.
      _initializationFuture = null;
      rethrow;
    }
  }

  // =====================================
  // PREPARE AUTHENTICATION
  // =====================================

  Future<void> _initializeAuthentication() async {
    try {
      // Keep database access locked while
      // the sign-in screen is displayed.
      await AppDatabase.instance.lockAccount();

      // Initialize Google Sign-In once.
      await _ensureGoogleInitialized();

      if (!mounted) return;

      // After explicit sign-out, skip automatic
      // session restoration. The user must
      // press Continue with Google.
      if (widget.skipAutomaticSignIn) {
        return;
      }

      // Restore a previously signed-in
      // Google account when available.
      final attempt = _googleSignIn
          .attemptLightweightAuthentication();

      if (attempt == null) {
        return;
      }

      final existingAccount = await attempt;

      if (!mounted) return;

      if (existingAccount != null) {
        await _openAccountDatabase(
          existingAccount,
        );
      }
    } on GoogleSignInException {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        'Google authentication could not '
            'be initialized. Check your '
            'Google OAuth configuration.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        'Unable to prepare secure sign-in. '
            'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  // =====================================
  // INTERACTIVE GOOGLE SIGN-IN
  // =====================================

  Future<void> _signInWithGoogle() async {
    if (_isInitializing ||
        _isSigningIn ||
        _hasNavigated) {
      return;
    }

    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      if (!_googleSignIn.supportsAuthenticate()) {
        throw StateError(
          'Interactive Google Sign-In '
              'is not supported here.',
        );
      }

      // Show Google's real account picker.
      final account =
      await _googleSignIn.authenticate();

      if (!mounted) return;

      // Open this account's encrypted database.
      await _openAccountDatabase(account);
    } on GoogleSignInException catch (error) {
      if (!mounted) return;

      if (error.code ==
          GoogleSignInExceptionCode.canceled) {
        return;
      }

      setState(() {
        _errorMessage =
        'Google Sign-In failed. Check your '
            'internet connection and Google '
            'OAuth configuration.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        'Sign-in could not be completed. '
            'Your records have not been '
            'intentionally deleted.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  // =====================================
  // SELECT ACCOUNT DATABASE
  // =====================================

  Future<void> _openAccountDatabase(
      GoogleSignInAccount account,
      ) async {
    if (_hasNavigated) return;

    try {
      // Use Google's stable account ID,
      // not the email address.
      final accountId = account.id.trim();

      if (accountId.isEmpty) {
        throw StateError(
          'Google account ID is missing.',
        );
      }

      await AppDatabase.instance.useGoogleAccount(
        accountId,
      );

      if (!mounted || _hasNavigated) {
        return;
      }

      // Confirm the selected database opened.
      final database =
      await AppDatabase.instance.database;

      if (!database.isOpen) {
        throw StateError(
          'Medical database did not open.',
        );
      }

      if (!mounted || _hasNavigated) {
        return;
      }

      _hasNavigated = true;

      // Remove authentication routes so
      // Back cannot show stale login UI.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
          const DashboardScreen(),
        ),
            (route) => false,
      );
    } catch (_) {
      // Fail closed if storage selection fails.
      try {
        await AppDatabase.instance.lockAccount();
      } catch (_) {
        // Do not expose storage diagnostics.
      }

      if (!mounted) return;

      setState(() {
        _errorMessage =
        'Google account selected, but '
            'secure medical storage could '
            'not be opened. Existing records '
            'have not been intentionally deleted.';
      });
    }
  }

  // =====================================
  // OPEN DRIVE SETUP PREVIEW
  // =====================================

  void _openDriveSetup() {
    if (_isInitializing || _isSigningIn) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
        const DriveSetupScreen(),
      ),
    );
  }

  // =====================================
  // DISPLAY ERROR OR NOTICE
  // =====================================

  Widget _buildMessage() {
    if (_errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),

        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            const Icon(
              Icons.info_outline,
              color: AppColors.primary,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // BUILD GOOGLE SIGN-IN SCREEN
  // =====================================

  @override
  Widget build(BuildContext context) {
    final isBusy =
        _isInitializing || _isSigningIn;

    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight =
            constraints.maxHeight > 48
                ? constraints.maxHeight - 48
                : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),

              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight,
                ),

                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,

                  children: [
                    const SizedBox(height: 24),

                    // =========================
                    // LOGO AND WELCOME
                    // =========================

                    Column(
                      children: [
                        Image.asset(
                          'assets/images/'
                              'my_medical_history_splash_icon.png',

                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,

                          errorBuilder:
                              (context, error, stack) {
                            return const Icon(
                              Icons.health_and_safety,
                              size: 120,
                              color: AppColors.primary,
                            );
                          },
                        ),

                        const SizedBox(height: 20),

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

                        const Text(
                          'Your health records, '
                              'always with you.',

                          textAlign: TextAlign.center,

                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    // =========================
                    // GOOGLE SIGN-IN
                    // =========================

                    Column(
                      children: [
                        if (isBusy) ...[
                          const CircularProgressIndicator(),

                          const SizedBox(height: 14),

                          Text(
                            _isInitializing
                                ? 'Checking Google account...'
                                : 'Opening secure storage...',

                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],

                        SizedBox(
                          width: double.infinity,
                          height: 56,

                          child: OutlinedButton(
                            onPressed: isBusy
                                ? null
                                : _signInWithGoogle,

                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor:
                              const Color(0xFF1F1F1F),

                              side: const BorderSide(
                                color: Color(0xFF747775),
                              ),

                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(28),
                              ),
                            ),

                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,

                              children: [
                                Image.asset(
                                  'assets/images/google_g_logo.png',
                                  width: 20,
                                  height: 20,

                                  errorBuilder:
                                      (context, error, stack) {
                                    return const Icon(
                                      Icons.account_circle_outlined,
                                    );
                                  },
                                ),

                                const SizedBox(width: 12),

                                const Text(
                                  'Continue with Google',

                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Sign in with Google to '
                              'access your medical records.',

                          textAlign: TextAlign.center,

                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 14),

                        _buildMessage(),

                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: isBusy
                              ? null
                              : _openDriveSetup,

                          child: const Text(
                            'Google Drive Backup Setup',
                          ),
                        ),
                      ],
                    ),

                    // =========================
                    // BACKUP INFORMATION
                    // =========================

                    const Padding(
                      padding: EdgeInsets.only(
                        top: 30,
                        bottom: 8,
                      ),

                      child: Text(
                        'Secure Google Drive backup is fully '
                            'integrated and ready for synchronization.',

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

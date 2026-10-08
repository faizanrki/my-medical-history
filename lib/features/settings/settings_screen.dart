
import 'backup_restore_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../services/medical_history_read_service.dart';
import '../../services/google_drive_backup_service.dart';

import '../auth/google_signin_screen.dart';

// ============================================
// MY MEDICAL HISTORY
// STEP 45.2 - SETTINGS + GOOGLE DRIVE
// ============================================
//
// FEATURES:
//
// 1. Account-specific medical record counts.
// 2. Encrypted SQLite database verification.
// 3. Google Drive authorization.
// 4. Private Drive backup-file listing.
// 5. Account session checks.
// 6. Google sign-out with database locking.
// 7. Doctors and History navigation.
// 8. Safe handling of asynchronous requests.
//
// NOTE:
// Google Drive backup and restore are not
// implemented in this screen yet.
//
// ============================================

enum _SettingsMenuAction {
  refresh,
  verifyDatabase,
  about,
  signOut,
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onOpenDoctors;
  final VoidCallback? onOpenHistory;

  const SettingsScreen({
    super.key,
    this.onOpenDoctors,
    this.onOpenHistory,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen>
    with WidgetsBindingObserver {

  // ========================================
  // SERVICES
  // ========================================

  final MedicalHistoryReadService _readService =
      MedicalHistoryReadService.instance;

  final GoogleDriveBackupService _driveService =
      GoogleDriveBackupService.instance;

  // ========================================
  // ACCOUNT SESSION
  // ========================================

  late final int _screenSessionGeneration;

  bool get _isCurrentSession =>
      AppDatabase.instance.isSessionCurrent(
        _screenSessionGeneration,
      );

  // ========================================
  // MEDICAL RECORD COUNTS
  // ========================================

  MedicalHistoryCounts? _counts;

  bool _isLoadingCounts = true;

  String? _countsError;

  int _countsRequest = 0;

  // ========================================
  // DATABASE HEALTH
  // ========================================

  bool _isCheckingStorage = false;

  String? _storageResult;

  bool? _storagePassed;

  int _storageRequest = 0;

  // ========================================
  // GOOGLE DRIVE STATE
  // ========================================

  bool _isConnectingDrive = false;

  bool _isDriveConnected = false;

  String? _driveMessage;

  List<MedicalDriveBackupFile> _driveFiles = [];

  int _driveRequest = 0;

  // ========================================
  // SIGN-OUT STATE
  // ========================================

  bool _isSigningOut = false;

  // ========================================
  // INITIALIZE
  // ========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _screenSessionGeneration =
        AppDatabase.instance.sessionGeneration;

    _loadCounts();
  }

  // ========================================
  // APP LIFECYCLE
  // ========================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed &&
        mounted) {
      // Recheck session before showing
      // sensitive medical record counts.
      setState(() {});
    }
  }

  // ========================================
  // DISPOSE
  // ========================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _countsRequest++;
    _storageRequest++;
    _driveRequest++;

    super.dispose();
  }

  // ========================================
  // LOAD MEDICAL RECORD COUNTS
  // ========================================

  Future<void> _loadCounts() async {
    if (!mounted ||
        _isSigningOut ||
        !_isCurrentSession) {
      return;
    }

    final request = ++_countsRequest;

    setState(() {
      _isLoadingCounts = true;
      _countsError = null;
    });

    try {
      final counts =
      await _readService.getHistoryCounts();

      if (!mounted ||
          _isSigningOut ||
          !_isCurrentSession ||
          request != _countsRequest) {
        return;
      }

      setState(() {
        _counts = counts;
        _countsError = null;
      });
    } catch (_) {
      if (!mounted ||
          _isSigningOut ||
          !_isCurrentSession ||
          request != _countsRequest) {
        return;
      }

      setState(() {
        _counts = null;
        _countsError =
        'Unable to load medical record counts.';
      });
    } finally {
      if (mounted &&
          !_isSigningOut &&
          _isCurrentSession &&
          request == _countsRequest) {
        setState(() {
          _isLoadingCounts = false;
        });
      }
    }
  }

  // ========================================
  // VERIFY ENCRYPTED DATABASE
  // ========================================

  Future<void> _checkDatabaseHealth() async {
    if (!mounted ||
        _isSigningOut ||
        _isCheckingStorage ||
        !_isCurrentSession) {
      return;
    }

    final request = ++_storageRequest;

    setState(() {
      _isCheckingStorage = true;
      _storagePassed = null;
      _storageResult = null;
    });

    try {
      final db = await AppDatabase.instance.database;

      if (!_isCurrentSession) {
        throw StateError('Account session changed.');
      }

      // ====================================
      // CHECK SQLCIPHER
      // ====================================

      final cipherResult = await db.rawQuery(
        'PRAGMA cipher_version',
      );

      if (!_isCurrentSession) {
        throw StateError('Account session changed.');
      }

      if (cipherResult.isEmpty ||
          cipherResult.first.isEmpty ||
          cipherResult.first.values.first
              .toString()
              .trim()
              .isEmpty) {
        throw StateError(
          'SQLCipher verification failed.',
        );
      }

      // ====================================
      // CHECK FOREIGN KEYS
      // ====================================

      final foreignKeys = await db.rawQuery(
        'PRAGMA foreign_keys',
      );

      if (!_isCurrentSession) {
        throw StateError('Account session changed.');
      }

      if (foreignKeys.isEmpty ||
          foreignKeys.first.isEmpty ||
          foreignKeys.first.values.first
              .toString() !=
              '1') {
        throw StateError(
          'Foreign keys are not enabled.',
        );
      }

      // ====================================
      // CHECK RELATIONSHIP INTEGRITY
      // ====================================

      final relationshipProblems =
      await db.rawQuery(
        'PRAGMA foreign_key_check',
      );

      if (!_isCurrentSession) {
        throw StateError('Account session changed.');
      }

      if (relationshipProblems.isNotEmpty) {
        throw StateError(
          'Database relationship check failed.',
        );
      }

      // ====================================
      // CHECK DATABASE INTEGRITY
      // ====================================

      final integrityResult = await db.rawQuery(
        'PRAGMA quick_check',
      );

      if (!_isCurrentSession) {
        throw StateError('Account session changed.');
      }

      if (integrityResult.length != 1 ||
          integrityResult.first.isEmpty ||
          integrityResult.first.values.first
              .toString()
              .trim()
              .toLowerCase() !=
              'ok') {
        throw StateError(
          'Database integrity check failed.',
        );
      }

      if (!mounted ||
          _isSigningOut ||
          !_isCurrentSession ||
          request != _storageRequest) {
        return;
      }

      setState(() {
        _storagePassed = true;

        _storageResult =
        'Database checks passed. '
            'SQLCipher is available, foreign '
            'keys are enabled, and the '
            'integrity checks returned OK.';
      });
    } catch (_) {
      if (!mounted ||
          _isSigningOut ||
          !_isCurrentSession ||
          request != _storageRequest) {
        return;
      }

      setState(() {
        _storagePassed = false;

        _storageResult =
        'Database verification could not '
            'be completed successfully. '
            'No medical records or encryption '
            'keys were intentionally deleted.';
      });
    } finally {
      if (mounted &&
          !_isSigningOut &&
          _isCurrentSession &&
          request == _storageRequest) {
        setState(() {
          _isCheckingStorage = false;
        });
      }
    }
  }

  // ========================================
  // CONNECT GOOGLE DRIVE
  // ========================================

  Future<void> _connectGoogleDrive() async {
    if (!mounted ||
        _isSigningOut ||
        _isConnectingDrive ||
        !_isCurrentSession) {
      return;
    }

    final request = ++_driveRequest;

    setState(() {
      _isConnectingDrive = true;
      _isDriveConnected = false;
      _driveFiles = [];

      _driveMessage =
      'Checking your signed-in Google '
          'account and requesting Drive access...';
    });

    try {
      // ====================================
      // GET EXISTING GOOGLE ACCOUNT
      // ====================================

      // Google Sign-In 7.x does not expose
      // the old currentUser property.
      //
      // Attempt to recover the existing
      // authenticated Google account.
      //
      // Do not call authenticate() here.
      // This screen must not silently start
      // a new, different account session.

      final attempt = GoogleSignIn.instance
          .attemptLightweightAuthentication();

      if (attempt == null) {
        throw StateError(
          'The current Google account could '
              'not be retrieved. Please return '
              'to Google Sign-In.',
        );
      }

      final GoogleSignInAccount? account =
      await attempt;

      if (!mounted ||
          !_isCurrentSession ||
          _isSigningOut ||
          request != _driveRequest) {
        return;
      }

      if (account == null) {
        throw StateError(
          'No authenticated Google account '
              'is available. Please sign in again.',
        );
      }

      // ====================================
      // REQUEST DRIVE PERMISSION
      // ====================================

      // The Drive service verifies that
      // this account ID matches the active
      // encrypted medical database.
      //
      // It then requests drive.appdata scope
      // and reads only backup-file metadata.

      final files =
      await _driveService.connectAndListBackups(
        account,
      );

      // ====================================
      // CHECK SESSION AFTER NETWORK REQUEST
      // ====================================

      if (!mounted ||
          !_isCurrentSession ||
          _isSigningOut ||
          request != _driveRequest) {
        return;
      }

      // ====================================
      // CONNECTED
      // ====================================

      setState(() {
        _isDriveConnected = true;
        _driveFiles = files;

        _driveMessage = files.isEmpty
            ? 'Google Drive is connected. '
            'No app backup files were found.'
            : 'Google Drive is connected. '
            '${files.length} backup file(s) found.';
      });
    } catch (error) {
      if (!mounted ||
          !_isCurrentSession ||
          _isSigningOut ||
          request != _driveRequest) {
        return;
      }

      // Do not expose access tokens,
      // database paths, or raw API replies.

      String message =
          'Could not connect Google Drive. '
          'Check your internet connection, '
          'Drive API configuration, and '
          'Google account permissions.';

      // These messages are produced by our
      // own service, not a raw HTTP response.
      if (error is StateError) {
        message = error.message;
      }

      setState(() {
        _isDriveConnected = false;
        _driveFiles = [];
        _driveMessage = message;
      });
    } finally {
      if (mounted &&
          !_isSigningOut &&
          _isCurrentSession &&
          request == _driveRequest) {
        setState(() {
          _isConnectingDrive = false;
        });
      }
    }
  }

  // ========================================
  // FORMAT BACKUP DATE
  // ========================================

  String _formatBackupDate(DateTime? date) {
    if (date == null) {
      return 'Date unavailable';
    }

    final local = date.toLocal();

    final day =
    local.day.toString().padLeft(2, '0');

    final month =
    local.month.toString().padLeft(2, '0');

    final hour =
    local.hour.toString().padLeft(2, '0');

    final minute =
    local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }

  // ========================================
  // GOOGLE SIGN OUT
  // ========================================

  Future<void> _signOut() async {
    if (!mounted ||
        _isSigningOut ||
        _isConnectingDrive) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Sign out of Google?',
          ),

          content: const Text(
            'You will leave your medical '
                'history account on this device.\n\n'
                'Your saved local medical records '
                'will not be deleted.\n\n'
                'A Google Drive backup is not '
                'automatically created when '
                'you sign out.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  false,
                );
              },

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  true,
                );
              },

              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    if (_isConnectingDrive || _isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
      _isDriveConnected = false;
      _driveFiles = [];
      _driveMessage = null;
      _counts = null;
    });

    // Ignore older asynchronous responses.
    _countsRequest++;
    _storageRequest++;
    _driveRequest++;

    // ======================================
    // LOCK ENCRYPTED LOCAL DATABASE FIRST
    // ======================================

    try {
      await AppDatabase.instance.lockAccount();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSigningOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medical storage could not be '
                'locked safely. Sign-out was '
                'stopped. Close the app before '
                'trying again.',
          ),
        ),
      );

      return;
    }

    // ======================================
    // SIGN OUT OF GOOGLE
    // ======================================

    String notice =
        'You signed out successfully. '
        'Sign in again to access your records.';

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      notice =
      'Local medical storage is locked, '
          'but Google sign-out could not '
          'be confirmed. Please try again.';
    }

    if (!mounted) {
      return;
    }

    // ======================================
    // RETURN TO SIGN-IN SCREEN
    // ======================================

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => GoogleSignInScreen(
          skipAutomaticSignIn: true,
          notice: notice,
        ),
      ),
          (route) => false,
    );
  }

  // ========================================
  // ABOUT APP
  // ========================================

  void _showAboutApp() {
    if (!_isCurrentSession || !mounted) {
      return;
    }

    showAboutDialog(
      context: context,
      applicationName: 'My Medical History',

      applicationIcon: const Icon(
        Icons.health_and_safety_outlined,
        color: AppColors.primary,
        size: 36,
      ),

      children: const [
        Text(
          'Organize your doctor visits, '
              'medicines, and medical tests.',
        ),

        SizedBox(height: 10),

        Text(
          'Local records use encrypted '
              'SQLite storage. Google Drive '
              'connection is being added, '
              'but backup and restore are '
              'not available yet.',
        ),

        SizedBox(height: 10),

        Text(
          'Use dummy medical records until '
              'backup recovery and account '
              'security testing are complete.',
        ),
      ],
    );
  }

  // ========================================
  // MORE MENU ACTIONS
  // ========================================

  Future<void> _handleMenuAction(
      _SettingsMenuAction action,
      ) async {
    if (_isSigningOut || !_isCurrentSession) {
      return;
    }

    switch (action) {
      case _SettingsMenuAction.refresh:
        await _loadCounts();
        return;

      case _SettingsMenuAction.verifyDatabase:
        await _checkDatabaseHealth();
        return;

      case _SettingsMenuAction.about:
        _showAboutApp();
        return;

      case _SettingsMenuAction.signOut:
        await _signOut();
        return;
    }
  }

  // ========================================
  // SECTION HEADER
  // ========================================

  Widget _buildSectionHeader(
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          subtitle,

          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ========================================
  // STATISTICS CARD
  // ========================================

  Widget _buildCountCard({
    required String title,
    required int? count,
    required IconData icon,
    required Color color,
    required Color lightColor,
  }) {
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 145,
        ),

        child: Padding(
          padding: const EdgeInsets.all(15),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Container(
                width: 42,
                height: 42,

                decoration: BoxDecoration(
                  color: lightColor,

                  borderRadius:
                  BorderRadius.circular(12),
                ),

                child: Icon(
                  icon,
                  size: 23,
                  color: color,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                count?.toString() ?? '--',

                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                title,

                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // RESPONSIVE STATISTICS GRID
  // ========================================

  Widget _buildCountsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;

        final width = constraints.maxWidth;

        final columns = width < 310 ? 1 : 2;

        final cardWidth = columns == 1
            ? width
            : (width - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,

          children: [
            SizedBox(
              width: cardWidth,

              child: _buildCountCard(
                title: 'Doctors',
                count: _counts?.doctors,

                icon:
                Icons.medical_services_outlined,

                color: AppColors.doctors,
                lightColor:
                AppColors.doctorsLight,
              ),
            ),

            SizedBox(
              width: cardWidth,

              child: _buildCountCard(
                title: 'Visits',
                count: _counts?.visits,

                icon:
                Icons.calendar_month_outlined,

                color: AppColors.visits,
                lightColor:
                AppColors.visitsLight,
              ),
            ),

            SizedBox(
              width: cardWidth,

              child: _buildCountCard(
                title: 'Medicines',
                count: _counts?.medicines,

                icon: Icons.medication_outlined,

                color: AppColors.medicines,
                lightColor:
                AppColors.medicinesLight,
              ),
            ),

            SizedBox(
              width: cardWidth,

              child: _buildCountCard(
                title: 'Medical Tests',
                count: _counts?.tests,

                icon: Icons.science_outlined,

                color: AppColors.medicalTests,
                lightColor:
                AppColors.medicalTestsLight,
              ),
            ),
          ],
        );
      },
    );
  }

  // ========================================
  // REUSABLE SETTINGS TILE
  // ========================================

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,

    VoidCallback? onTap,

    Color iconColor = AppColors.primary,
    Color iconBackground =
        AppColors.primaryLight,
  }) {
    return Card(
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 9,
        ),

        leading: Container(
          width: 44,
          height: 44,

          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius:
            BorderRadius.circular(13),
          ),

          child: Icon(
            icon,
            color: iconColor,
            size: 23,
          ),
        ),

        title: Text(
          title,

          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 5,
          ),

          child: Text(
            subtitle,

            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        trailing: onTap == null
            ? null
            : const Icon(
          Icons.chevron_right,
          color: AppColors.textMuted,
        ),

        onTap: _isSigningOut ||
            !_isCurrentSession
            ? null
            : onTap,
      ),
    );
  }

  // ========================================
  // MEDICAL RECORDS SECTION
  // ========================================

  Widget _buildMedicalRecordsSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        _buildSectionHeader(
          'Medical records',
          'Your saved local medical information.',
        ),

        const SizedBox(height: 15),

        if (_isLoadingCounts) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 14),
        ],

        if (_countsError != null) ...[
          Text(
            _countsError!,

            style: const TextStyle(
              color: AppColors.error,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 12),
        ],

        _buildCountsGrid(),

        const SizedBox(height: 14),

        _buildSettingsTile(
          icon: Icons.people_outline,

          title: 'View Doctors',

          subtitle:
          'Open your saved doctor profiles.',

          onTap: widget.onOpenDoctors,
        ),

        const SizedBox(height: 10),

        _buildSettingsTile(
          icon: Icons.history,

          title: 'Medical History',

          subtitle:
          'View your saved doctor visits.',

          onTap: widget.onOpenHistory,

          iconColor: AppColors.visits,
          iconBackground:
          AppColors.visitsLight,
        ),
      ],
    );
  }

  // ========================================
  // DATABASE CHECK RESULT
  // ========================================

  Widget _buildSecurityResult() {
    if (_storageResult == null) {
      return const SizedBox.shrink();
    }

    final passed = _storagePassed == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Icon(
              passed
                  ? Icons.check_circle_outline
                  : Icons.error_outline,

              color: passed
                  ? AppColors.success
                  : AppColors.error,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                _storageResult!,

                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // PRIVACY AND SECURITY SECTION
  // ========================================

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        _buildSectionHeader(
          'Privacy & security',
          'Protection of locally saved '
              'medical records.',
        ),

        const SizedBox(height: 14),

        _buildSettingsTile(
          icon: Icons.lock_outline,

          title: 'Encrypted Local Database',

          subtitle:
          'Medical records are stored in '
              'a SQLCipher-encrypted database.',

          iconColor: AppColors.success,

          iconBackground:
          AppColors.successLight,
        ),

        const SizedBox(height: 10),

        _buildSettingsTile(
          icon: Icons.shield_outlined,

          title: 'Database Health Check',

          subtitle:
          'Check encryption support, '
              'relationships, and database integrity.',
        ),

        const SizedBox(height: 13),

        SizedBox(
          width: double.infinity,

          child: OutlinedButton.icon(
            onPressed: _isCheckingStorage ||
                _isSigningOut
                ? null
                : _checkDatabaseHealth,

            icon: _isCheckingStorage
                ? const SizedBox(
              width: 18,
              height: 18,

              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.verified_user_outlined,
            ),

            label: Text(
              _isCheckingStorage
                  ? 'Checking Database...'
                  : 'Verify Database Security',
            ),
          ),
        ),

        if (_storageResult != null) ...[
          const SizedBox(height: 13),
          _buildSecurityResult(),
        ],

        const SizedBox(height: 12),

        const Text(
          'A successful database check does '
              'not replace a complete medical '
              'data security audit.',

          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ========================================
  // GOOGLE DRIVE BACKUP STATUS
  // ========================================

  Widget _buildDriveStatus() {
    if (_driveMessage == null &&
        !_isDriveConnected) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  _isDriveConnected
                      ? Icons.cloud_done_outlined
                      : Icons.info_outline,

                  color: _isDriveConnected
                      ? AppColors.success
                      : AppColors.primary,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        _isDriveConnected
                            ? 'Google Drive Connected'
                            : 'Google Drive Status',

                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w700,
                          color:
                          AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        _driveMessage ?? '',

                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color:
                          AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ==================================
            // SHOW EXISTING BACKUP METADATA
            // ==================================

            if (_isDriveConnected &&
                _driveFiles.isNotEmpty) ...[
              const SizedBox(height: 15),

              const Divider(),

              const SizedBox(height: 10),

              const Text(
                'Backup files found',

                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              for (final file
              in _driveFiles.take(5))
                ListTile(
                  dense: true,

                  contentPadding:
                  EdgeInsets.zero,

                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primary,
                  ),

                  title: Text(
                    file.name,

                    maxLines: 2,

                    overflow:
                    TextOverflow.ellipsis,
                  ),

                  subtitle: Text(
                    _formatBackupDate(
                      file.modifiedAt ??
                          file.createdAt,
                    ),
                  ),
                ),

              if (_driveFiles.length > 5)
                Text(
                  '${_driveFiles.length - 5} '
                      'additional backup files '
                      'were found.',

                  style: const TextStyle(
                    fontSize: 12,
                    color:
                    AppColors.textSecondary,
                  ),
                ),
            ],

            if (_isDriveConnected) ...[
              const SizedBox(height: 10),

              const Text(
                'Connection only. Medical '
                    'data has not been uploaded '
                    'or restored by this action.',

                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========================================
  // GOOGLE DRIVE SECTION
  // ========================================

  Widget _buildGoogleDriveSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        _buildSectionHeader(
          'Google Drive backup',
          'Connect private app storage '
              'for future encrypted backups.',
        ),

        const SizedBox(height: 14),

        _buildSettingsTile(
          icon: Icons.cloud_outlined,

          title: 'Private Google Drive Storage',

          subtitle:
          'Use the Google Drive app-data '
              'folder for encrypted backups.',

          iconColor: AppColors.visits,

          iconBackground:
          AppColors.visitsLight,
        ),

        const SizedBox(height: 13),

        SizedBox(
          width: double.infinity,

          child: FilledButton.icon(
            onPressed: _isConnectingDrive ||
                _isSigningOut
                ? null
                : _connectGoogleDrive,

            icon: _isConnectingDrive
                ? const SizedBox(
              width: 18,
              height: 18,

              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : Icon(
              _isDriveConnected
                  ? Icons.refresh
                  : Icons.add_to_drive,
            ),

            label: Text(
              _isConnectingDrive
                  ? 'Connecting to Drive...'
                  : _isDriveConnected
                  ? 'Refresh Drive Connection'
                  : 'Connect Google Drive',
            ),
          ),
        ),

        if (_driveMessage != null ||
            _isDriveConnected) ...[
          const SizedBox(height: 13),

          _buildDriveStatus(),
        ],

        const SizedBox(height: 16),

        _buildSectionHeader(
          'Backup & recovery',
          'These features will become '
              'available after encryption '
              'and restore verification.',
        ),

        const SizedBox(height: 12),

        _buildSettingsTile(
          icon: Icons.cloud_upload_outlined,

          title: 'Back Up Medical History',

          subtitle:
          'Not available yet. A portable '
              'encrypted backup and recovery '
              'password are still required.',

          iconColor: AppColors.medicines,

          iconBackground:
          AppColors.medicinesLight,
        ),

        const SizedBox(height: 10),

        _buildSettingsTile(
          icon: Icons.restore_outlined,

          title: 'Restore Medical History',

          subtitle:
          'Not available yet. Restore '
              'must be verified before any '
              'local records are changed.',
        ),

        const SizedBox(height: 14),

        const Card(
          child: Padding(
            padding: EdgeInsets.all(15),

            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.info_outline,

                  color: AppColors.primary,
                ),

                SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Connecting Google Drive '
                        'does not back up your '
                        'medical records.\n\n'
                        'Your current records remain '
                        'in encrypted local storage. '
                        'Do not uninstall the app '
                        'or clear its data expecting '
                        'Drive recovery to work yet.',

                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color:
                      AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================
  // GOOGLE ACCOUNT SECTION
  // ========================================

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        _buildSectionHeader(
          'Google account',
          'Manage your signed-in '
              'medical history account.',
        ),

        const SizedBox(height: 14),

        _buildSettingsTile(
          icon: Icons.account_circle_outlined,

          title: 'Google Account',

          subtitle:
          'Each signed-in Google account '
              'uses a separate local '
              'encrypted database.',
        ),

        const SizedBox(height: 10),

        _buildSettingsTile(
          icon: Icons.security,

          title: 'Additional App Protection',

          subtitle:
          'More privacy controls are '
              'planned for future updates.',

          iconColor: AppColors.medicines,

          iconBackground:
          AppColors.medicinesLight,
        ),

        const SizedBox(height: 15),

        const Card(
          child: Padding(
            padding: EdgeInsets.all(15),

            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                ),

                SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Account-specific storage '
                        'and the visit-saving workflow '
                        'still require full '
                        'account-switch testing. '
                        'Use dummy records only.',

                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color:
                      AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ==================================
        // GOOGLE SIGN OUT BUTTON
        // ==================================

        SizedBox(
          width: double.infinity,

          child: OutlinedButton.icon(
            onPressed: _isSigningOut ||
                _isConnectingDrive
                ? null
                : _signOut,

            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,

              side: const BorderSide(
                color: AppColors.border,
              ),
            ),

            icon: _isSigningOut
                ? const SizedBox(
              width: 18,
              height: 18,

              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.logout),

            label: Text(
              _isSigningOut
                  ? 'Signing Out...'
                  : 'Sign Out of Google',
            ),
          ),
        ),
      ],
    );
  }

  // ========================================
  // ABOUT SECTION
  // ========================================

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        _buildSectionHeader(
          'About',
          'Information about this application.',
        ),

        const SizedBox(height: 14),

        _buildSettingsTile(
          icon:
          Icons.health_and_safety_outlined,

          title: 'My Medical History',

          subtitle:
          'A personal medical '
              'record organizer.',

          onTap: _showAboutApp,
        ),

        const SizedBox(height: 10),

        _buildSettingsTile(
          icon: Icons.storage_outlined,

          title: 'Local Medical Storage',

          subtitle:
          'Records are saved on this '
              'device in an encrypted '
              'local database.',
        ),

        const SizedBox(height: 10),

        _buildSettingsTile(
          icon: Icons.info_outline,

          title: 'Medical Information Notice',

          subtitle:
          'The app stores your records. '
              'It does not provide medical '
              'advice or diagnoses.',
        ),
      ],
    );
  }

  // ========================================
  // INVALID ACCOUNT SESSION
  // ========================================

  Widget _buildInvalidSessionScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Settings'),
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(
                Icons.lock_outline,
                size: 48,
                color: AppColors.error,
              ),

              const SizedBox(height: 16),

              const Text(
                'Account Session Unavailable',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your medical account changed '
                    'or was locked. Sign in again '
                    'to access Settings.',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).maybePop();
                },

                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // MAIN SETTINGS SCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    if (!_isCurrentSession) {
      return _buildInvalidSessionScreen();
    }

    return PopScope(
      canPop:
      !_isSigningOut &&
          !_isConnectingDrive,

      child: Scaffold(
        backgroundColor: AppColors.background,

        // ==================================
        // APP BAR
        // ==================================

        appBar: AppBar(
          title: const Text('Settings'),

          actions: [
            IconButton(
              tooltip: 'Refresh record counts',

              onPressed: _isLoadingCounts ||
                  _isSigningOut
                  ? null
                  : _loadCounts,

              icon: const Icon(
                Icons.refresh,
              ),
            ),

            PopupMenuButton<_SettingsMenuAction>(
              tooltip: 'More settings options',

              enabled: !_isSigningOut &&
                  !_isConnectingDrive,

              icon: const Icon(Icons.more_vert),

              onSelected: _handleMenuAction,

              itemBuilder: (_) => const [
                PopupMenuItem(
                  value:
                  _SettingsMenuAction.refresh,

                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 12),
                      Text('Refresh data'),
                    ],
                  ),
                ),

                PopupMenuItem(
                  value:
                  _SettingsMenuAction
                      .verifyDatabase,

                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 12),
                      Text('Verify database'),
                    ],
                  ),
                ),

                PopupMenuItem(
                  value:
                  _SettingsMenuAction.about,

                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 12),
                      Text('About app'),
                    ],
                  ),
                ),

                PopupMenuDivider(),

                PopupMenuItem(
                  value:
                  _SettingsMenuAction.signOut,

                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        color: AppColors.error,
                      ),

                      SizedBox(width: 12),

                      Text(
                        'Sign out',
                        style: TextStyle(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),
          ],
        ),

        // ==================================
        // SETTINGS CONTENT
        // ==================================

        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadCounts,

            child: ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),

              padding:
              const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                35,
              ),

              children: [
                const Text(
                  'App settings',

                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Manage your medical records, '
                      'Google account, backups '
                      'and privacy.',

                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 27),

                // ============================
                // MEDICAL RECORDS
                // ============================

                _buildMedicalRecordsSection(),

                const SizedBox(height: 30),

                // ============================
                // LOCAL SECURITY
                // ============================

                _buildPrivacySection(),

                const SizedBox(height: 30),

                // ============================
                // GOOGLE DRIVE
                // ============================

                _buildGoogleDriveSection(),

                const SizedBox(height: 30),

                // ============================
                // GOOGLE ACCOUNT
                // ============================

                _buildAccountSection(),

                const SizedBox(height: 30),

                // ============================
                // ABOUT
                // ============================

                _buildAboutSection(),

                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

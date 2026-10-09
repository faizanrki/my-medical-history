
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../services/google_drive_backup_service.dart';
import '../../services/medical_history_read_service.dart';
import '../auth/google_signin_screen.dart';
import 'backup_restore_screen.dart';

// MY MEDICAL HISTORY
// STEP 45 - SETTINGS WITH GOOGLE DRIVE

enum _SettingsAction {
  refresh,
  verify,
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

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _readService = MedicalHistoryReadService.instance;
  final _driveService = GoogleDriveBackupService.instance;

  late final int _generation;

  MedicalHistoryCounts? _counts;
  bool _loadingCounts = true;
  String? _countsError;

  bool _checkingStorage = false;
  String? _storageMessage;
  bool? _storagePassed;

  bool _connectingDrive = false;
  bool _driveConnected = false;
  GoogleSignInAccount? _driveAccount;
  List<MedicalDriveBackupFile> _driveFiles = [];
  String? _driveMessage;

  bool _signingOut = false;

  int _countsRequest = 0;
  int _storageRequest = 0;
  int _driveRequest = 0;

  bool get _valid =>
      AppDatabase.instance.isSessionCurrent(_generation);

  bool get _driveBusy => _connectingDrive || _signingOut;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _generation = AppDatabase.instance.sessionGeneration;

    _loadCounts();

    // Automatically look for existing Drive access.
    // Do not show a new consent screen.
    _connectDrive(requestPermission: false);
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

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
    if (!mounted || !_valid || _signingOut) return;

    final request = ++_countsRequest;

    setState(() {
      _loadingCounts = true;
      _countsError = null;
    });

    try {
      final counts = await _readService.getHistoryCounts();

      if (!mounted ||
          !_valid ||
          _signingOut ||
          request != _countsRequest) {
        return;
      }

      setState(() {
        _counts = counts;
      });
    } catch (_) {
      if (!mounted ||
          !_valid ||
          _signingOut ||
          request != _countsRequest) {
        return;
      }

      setState(() {
        _counts = null;
        _countsError =
        'Unable to load your medical record counts.';
      });
    } finally {
      if (mounted &&
          _valid &&
          !_signingOut &&
          request == _countsRequest) {
        setState(() => _loadingCounts = false);
      }
    }
  }

  // ========================================
  // VERIFY ENCRYPTED DATABASE
  // ========================================

  Future<void> _verifyDatabase() async {
    if (!mounted ||
        !_valid ||
        _signingOut ||
        _checkingStorage) {
      return;
    }

    final request = ++_storageRequest;

    setState(() {
      _checkingStorage = true;
      _storageMessage = null;
      _storagePassed = null;
    });

    try {
      final db = await AppDatabase.instance.database;

      if (!_valid) {
        throw StateError('Account changed.');
      }

      final cipher = await db.rawQuery(
        'PRAGMA cipher_version',
      );

      if (!_valid) {
        throw StateError('Account changed.');
      }

      if (cipher.isEmpty ||
          cipher.first.isEmpty ||
          cipher.first.values.first
              .toString()
              .trim()
              .isEmpty) {
        throw StateError('SQLCipher check failed.');
      }

      final foreignKeys = await db.rawQuery(
        'PRAGMA foreign_keys',
      );

      if (!_valid) {
        throw StateError('Account changed.');
      }

      if (foreignKeys.isEmpty ||
          foreignKeys.first.values.first.toString() != '1') {
        throw StateError('Foreign keys are disabled.');
      }

      final problems = await db.rawQuery(
        'PRAGMA foreign_key_check',
      );

      if (!_valid) {
        throw StateError('Account changed.');
      }

      if (problems.isNotEmpty) {
        throw StateError('Database relationships are invalid.');
      }

      final integrity = await db.rawQuery(
        'PRAGMA quick_check',
      );

      if (!_valid) {
        throw StateError('Account changed.');
      }

      if (integrity.length != 1 ||
          integrity.first.values.first
              .toString()
              .toLowerCase() !=
              'ok') {
        throw StateError('Database integrity check failed.');
      }

      if (!mounted ||
          !_valid ||
          request != _storageRequest) {
        return;
      }

      setState(() {
        _storagePassed = true;
        _storageMessage =
        'Database checks passed. SQLCipher is active. '
            'Foreign keys and integrity checks returned OK.';
      });
    } catch (_) {
      if (!mounted ||
          !_valid ||
          request != _storageRequest) {
        return;
      }

      setState(() {
        _storagePassed = false;
        _storageMessage =
        'Database verification could not be completed. '
            'No records or encryption keys were deleted.';
      });
    } finally {
      if (mounted &&
          _valid &&
          request == _storageRequest) {
        setState(() => _checkingStorage = false);
      }
    }
  }

  // ========================================
  // GOOGLE DRIVE CONNECTION
  // ========================================

  Future<void> _connectDrive({
    required bool requestPermission,
  }) async {
    if (!mounted ||
        !_valid ||
        _signingOut ||
        _connectingDrive) {
      return;
    }

    final request = ++_driveRequest;

    setState(() {
      _connectingDrive = true;
      _driveConnected = false;
      _driveAccount = null;
      _driveFiles = [];

      _driveMessage = requestPermission
          ? 'Connecting to Google Drive...'
          : 'Checking existing Google Drive access...';
    });

    try {
      // Reuse the Google account signed in earlier.
      // Never start a different interactive sign-in
      // from Settings.

      final attempt = GoogleSignIn.instance
          .attemptLightweightAuthentication();

      final GoogleSignInAccount? account =
      attempt == null ? null : await attempt;

      if (!mounted ||
          !_valid ||
          _signingOut ||
          request != _driveRequest) {
        return;
      }

      if (account == null) {
        throw StateError(
          'No signed-in Google account was found. '
              'Please sign in again.',
        );
      }

      // This is a silent permission check.
      // It does not request new consent.

      final authorization = await account
          .authorizationClient
          .authorizationForScopes([
        GoogleDriveBackupService.driveScope,
      ]);

      if (!mounted ||
          !_valid ||
          _signingOut ||
          request != _driveRequest) {
        return;
      }

      if (authorization == null && !requestPermission) {
        setState(() {
          _driveMessage =
          'Google account is signed in. '
              'Tap Connect Google Drive to allow backups.';
        });
        return;
      }

      // The service verifies the Google account
      // matches the active encrypted database.
      // When necessary, it requests Drive permission.

      final files =
      await _driveService.connectAndListBackups(
        account,
      );

      if (!mounted ||
          !_valid ||
          _signingOut ||
          request != _driveRequest) {
        return;
      }

      setState(() {
        _driveAccount = account;
        _driveConnected = true;
        _driveFiles = files;

        _driveMessage = files.isEmpty
            ? 'Google Drive connected successfully. '
            'No backups found yet.'
            : 'Google Drive connected successfully. '
            '${files.length} backup(s) found.';
      });
    } catch (error) {
      if (!mounted ||
          !_valid ||
          _signingOut ||
          request != _driveRequest) {
        return;
      }

      var message =
          'Could not verify Google Drive. '
          'Check your connection and try again.';

      if (error is StateError) {
        message = error.message.toString();
      } else if (error is FormatException) {
        message = error.message;
      }

      setState(() {
        _driveConnected = false;
        _driveAccount = null;
        _driveFiles = [];
        _driveMessage = message;
      });
    } finally {
      if (mounted &&
          _valid &&
          !_signingOut &&
          request == _driveRequest) {
        setState(() => _connectingDrive = false);
      }
    }
  }

  // ========================================
  // OPEN BACKUP & RESTORE
  // ========================================

  Future<void> _openBackupRestore() async {
    if (!mounted ||
        !_valid ||
        _driveBusy ||
        !_driveConnected ||
        _driveAccount == null) {
      return;
    }

    final account = _driveAccount!;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BackupRestoreScreen(
          initialAccount: account,
          initialBackups:
          List<MedicalDriveBackupFile>.of(_driveFiles),
        ),
      ),
    );

    if (!mounted || !_valid || _signingOut) {
      return;
    }

    // Refresh after backing up or restoring.
    await _connectDrive(requestPermission: false);

    if (mounted && _valid) {
      await _loadCounts();
    }
  }

  // ========================================
  // GOOGLE SIGN OUT
  // ========================================

  Future<void> _signOut() async {
    if (!mounted || _driveBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of Google?'),
        content: const Text(
          'You will leave your medical account on this device.\n\n'
              'Your local medical records will not be deleted.\n\n'
              'Signing out does not create a Google Drive backup.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || _driveBusy) {
      return;
    }

    setState(() {
      _signingOut = true;
      _driveConnected = false;
      _driveAccount = null;
      _driveFiles = [];
      _driveMessage = null;
      _counts = null;
    });

    _driveRequest++;
    _countsRequest++;
    _storageRequest++;

    try {
      await AppDatabase.instance.lockAccount();
    } catch (_) {
      if (!mounted) return;

      setState(() => _signingOut = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not safely lock medical storage. '
                'Sign-out was stopped.',
          ),
        ),
      );
      return;
    }

    String notice =
        'You signed out successfully. '
        'Sign in again to access your records.';

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      notice =
      'Medical storage is locked, but Google sign-out '
          'could not be confirmed.';
    }

    if (!mounted) return;

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
  // ABOUT
  // ========================================

  void _about() {
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
          'Organize doctor visits, medicines '
              'and medical tests.',
        ),
        SizedBox(height: 10),
        Text(
          'Medical records are stored in an encrypted '
              'account-specific database.',
        ),
        SizedBox(height: 10),
        Text(
          'Google Drive backups require a recovery password. '
              'The current backup format does not include '
              'external images, PDFs or test reports.',
        ),
      ],
    );
  }

  Future<void> _menuAction(_SettingsAction action) async {
    if (!_valid || _signingOut) return;

    switch (action) {
      case _SettingsAction.refresh:
        await _loadCounts();
        return;
      case _SettingsAction.verify:
        await _verifyDatabase();
        return;
      case _SettingsAction.about:
        _about();
        return;
      case _SettingsAction.signOut:
        await _signOut();
        return;
    }
  }

  // ========================================
  // REUSABLE UI
  // ========================================

  Widget _heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
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

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color iconColor = AppColors.primary,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 8,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right),
        onTap: !_valid || _signingOut ? null : onTap,
      ),
    );
  }

  Widget _countCard(
      String title,
      int? count,
      IconData icon,
      Color color,
      ) {
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 13),
              Text(
                count?.toString() ?? '--',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countsGrid() {
    return LayoutBuilder(
      builder: (context, size) {
        final width = size.maxWidth;
        final columns = width < 310 ? 1 : 2;
        final cardWidth =
        columns == 1 ? width : (width - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _countCard(
                'Doctors',
                _counts?.doctors,
                Icons.medical_services_outlined,
                AppColors.doctors,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _countCard(
                'Visits',
                _counts?.visits,
                Icons.calendar_month_outlined,
                AppColors.visits,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _countCard(
                'Medicines',
                _counts?.medicines,
                Icons.medication_outlined,
                AppColors.medicines,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _countCard(
                'Medical Tests',
                _counts?.tests,
                Icons.science_outlined,
                AppColors.medicalTests,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _medicalRecords() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Medical records',
          'Your saved local medical information.',
        ),
        const SizedBox(height: 15),
        if (_loadingCounts) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],
        if (_countsError != null) ...[
          Text(
            _countsError!,
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 12),
        ],
        _countsGrid(),
        const SizedBox(height: 14),
        _tile(
          icon: Icons.people_outline,
          title: 'View Doctors',
          subtitle: 'Open your saved doctor profiles.',
          onTap: widget.onOpenDoctors,
        ),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.history,
          title: 'Medical History',
          subtitle: 'View your saved doctor visits.',
          iconColor: AppColors.visits,
          onTap: widget.onOpenHistory,
        ),
      ],
    );
  }

  Widget _securitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Privacy & security',
          'Check protection of your local medical records.',
        ),
        const SizedBox(height: 14),
        _tile(
          icon: Icons.lock_outline,
          title: 'Encrypted Local Database',
          subtitle:
          'Medical records are stored using SQLCipher.',
          iconColor: AppColors.success,
        ),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.shield_outlined,
          title: 'Database Health Check',
          subtitle:
          'Check encryption and database integrity.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _checkingStorage || _signingOut
                ? null
                : _verifyDatabase,
            icon: _checkingStorage
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.verified_user_outlined),
            label: Text(
              _checkingStorage
                  ? 'Checking Database...'
                  : 'Verify Database Security',
            ),
          ),
        ),
        if (_storageMessage != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Icon(
                    _storagePassed == true
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: _storagePassed == true
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_storageMessage!)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'A successful check does not replace '
              'a complete medical-data security audit.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _backupDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  Widget _driveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Google Drive backup',
          'Private, password-encrypted backup storage.',
        ),
        const SizedBox(height: 14),
        _tile(
          icon: Icons.cloud_outlined,
          title: 'Private Google Drive Storage',
          subtitle:
          'Uses your Google Drive private app-data folder.',
          iconColor: AppColors.visits,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _driveBusy
                ? null
                : _driveConnected
                ? _openBackupRestore
                : () => _connectDrive(
              requestPermission: true,
            ),
            icon: _connectingDrive
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : Icon(
              _driveConnected
                  ? Icons.cloud_done_outlined
                  : Icons.add_to_drive,
            ),
            label: Text(
              _connectingDrive
                  ? 'Checking Google Drive...'
                  : _driveConnected
                  ? 'Open Backup & Restore'
                  : 'Connect Google Drive',
            ),
          ),
        ),
        if (_driveMessage != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    _driveConnected
                        ? Icons.cloud_done_outlined
                        : Icons.info_outline,
                    color: _driveConnected
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _driveMessage!,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_driveConnected && _driveFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final backup in _driveFiles.take(5))
            ListTile(
              dense: true,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(
                backup.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _backupDate(
                  backup.modifiedAt ?? backup.createdAt,
                ),
              ),
            ),
        ],
        if (_driveConnected)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _driveBusy
                  ? null
                  : () => _connectDrive(
                requestPermission: false,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh backups'),
            ),
          ),
        const SizedBox(height: 16),
        _heading(
          'Backup & recovery',
          'Save or recover medical records using '
              'a recovery password.',
        ),
        const SizedBox(height: 12),
        _tile(
          icon: Icons.cloud_upload_outlined,
          title: 'Back Up Medical History',
          subtitle: _driveConnected
              ? 'Create an encrypted Google Drive backup.'
              : 'Connect Google Drive first.',
          onTap: _driveConnected ? _openBackupRestore : null,
          iconColor: AppColors.medicines,
        ),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.restore_outlined,
          title: 'Restore Medical History',
          subtitle: _driveConnected
              ? 'Select a backup and enter its password.'
              : 'Connect Google Drive first.',
          onTap: _driveConnected ? _openBackupRestore : null,
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Text(
              'Connecting Google Drive does not automatically '
                  'upload your records.\n\n'
                  'The current backup format does not include '
                  'external prescription photos, PDFs, '
                  'or medical test reports.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Google account',
          'Manage your signed-in medical account.',
        ),
        const SizedBox(height: 14),
        _tile(
          icon: Icons.account_circle_outlined,
          title: 'Google Account',
          subtitle:
          'Each Google account has a separate '
              'encrypted medical database.',
        ),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.security,
          title: 'Additional App Protection',
          subtitle:
          'More privacy controls are planned.',
          iconColor: AppColors.medicines,
        ),
        const SizedBox(height: 13),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Text(
              'Account isolation and backup restoration '
                  'still need full testing. Use dummy records.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _driveBusy ? null : _signOut,
            icon: _signingOut
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.logout),
            label: Text(
              _signingOut
                  ? 'Signing Out...'
                  : 'Sign Out of Google',
            ),
          ),
        ),
      ],
    );
  }

  Widget _aboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'About',
          'Information about this application.',
        ),
        const SizedBox(height: 14),
        _tile(
          icon: Icons.health_and_safety_outlined,
          title: 'My Medical History',
          subtitle: 'A personal medical record organizer.',
          onTap: _about,
        ),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.storage_outlined,
          title: 'Local Medical Storage',
          subtitle: 'Records are encrypted on this device.',
        ),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.info_outline,
          title: 'Medical Information Notice',
          subtitle:
          'This app stores records. '
              'It does not provide medical diagnoses.',
        ),
      ],
    );
  }

  Widget _invalidSessionScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your Google account session changed. '
                'Sign in again to access Settings.',
            textAlign: TextAlign.center,
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
    if (!_valid) {
      return _invalidSessionScreen();
    }

    return PopScope(
      canPop: !_driveBusy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            IconButton(
              tooltip: 'Refresh record counts',
              onPressed: _loadingCounts || _signingOut
                  ? null
                  : _loadCounts,
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<_SettingsAction>(
              tooltip: 'More options',
              enabled: !_driveBusy,
              onSelected: _menuAction,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _SettingsAction.refresh,
                  child: Text('Refresh data'),
                ),
                PopupMenuItem(
                  value: _SettingsAction.verify,
                  child: Text('Verify database'),
                ),
                PopupMenuItem(
                  value: _SettingsAction.about,
                  child: Text('About app'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _SettingsAction.signOut,
                  child: Text('Sign out'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadCounts,
            child: ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                18, 18, 18, 35,
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
                  'Manage medical records, Google Drive '
                      'backups, account and privacy.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 27),
                _medicalRecords(),
                const SizedBox(height: 30),
                _securitySection(),
                const SizedBox(height: 30),
                _driveSection(),
                const SizedBox(height: 30),
                _accountSection(),
                const SizedBox(height: 30),
                _aboutSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

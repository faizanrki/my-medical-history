import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../services/google_drive_backup_service.dart';

// ============================================
// MY MEDICAL HISTORY
// GOOGLE DRIVE BACKUP & RESTORE SCREEN
// ============================================

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen>
    with WidgetsBindingObserver {
  final GoogleDriveBackupService _service = GoogleDriveBackupService.instance;

  late final int _generation;

  GoogleSignInAccount? _account;

  List<MedicalDriveBackupFile> _backups = [];

  bool _busy = false;

  String? _status;

  int _request = 0;

  bool get _sessionValid => AppDatabase.instance.isSessionCurrent(_generation);

  bool get _connected => _account != null && _sessionValid;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _generation = AppDatabase.instance.sessionGeneration;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _request++;
    super.dispose();
  }

  // ========================================
  // GET EXISTING GOOGLE ACCOUNT
  // ========================================

  Future<GoogleSignInAccount> _getGoogleAccount() async {
    final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();

    if (attempt == null) {
      throw StateError(
        'No Google account is available. '
        'Please sign in again.',
      );
    }

    final account = await attempt;

    if (account == null || !_sessionValid) {
      throw StateError(
        'Your Google account is unavailable '
        'or the session has changed.',
      );
    }

    return account;
  }

  // ========================================
  // DISPLAY SAFE ERRORS
  // ========================================

  String _errorText(Object error) {
    if (error is FormatException) {
      return error.message;
    }

    if (error is StateError) {
      return error.message.toString();
    }

    return 'The operation could not be '
        'confirmed. Check the Google account '
        'and internet connection.';
  }

  // ========================================
  // CONNECT TO GOOGLE DRIVE
  // ========================================

  Future<void> _connect() async {
    if (_busy || !_sessionValid) return;

    final request = ++_request;

    setState(() {
      _busy = true;
      _status = 'Connecting to Google Drive...';
    });

    try {
      final account = await _getGoogleAccount();

      if (!mounted || !_sessionValid || request != _request) {
        return;
      }

      final backups = await _service.connectAndListBackups(account);

      if (!mounted || !_sessionValid || request != _request) {
        return;
      }

      setState(() {
        _account = account;
        _backups = backups;

        _status =
            'Google Drive connected. '
            '${backups.length} backup(s) found.';
      });
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        _account = null;
        _backups = [];

        _status = _errorText(error);
      });
    } finally {
      if (mounted && request == _request) {
        setState(() => _busy = false);
      }
    }
  }

  // ========================================
  // RECOVERY PASSWORD DIALOG
  // ========================================

  Future<String?> _requestPassword({required bool create}) async {
    final first = TextEditingController();
    final confirmation = TextEditingController();

    bool hidden = true;
    String? error;

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,

        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, update) {
              return AlertDialog(
                title: Text(
                  create
                      ? 'Create Encrypted Backup'
                      : 'Restore Medical History',
                ),

                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        create
                            ? 'Create a strong recovery '
                                  'password with at least '
                                  '14 characters. You will '
                                  'need this password '
                                  'after reinstalling.'
                            : 'Enter the same recovery '
                                  'password used when '
                                  'the backup was created.',
                      ),

                      const SizedBox(height: 15),

                      TextField(
                        controller: first,
                        obscureText: hidden,
                        autocorrect: false,
                        enableSuggestions: false,

                        decoration: InputDecoration(
                          labelText: 'Recovery Password',

                          suffixIcon: IconButton(
                            onPressed: () {
                              update(() {
                                hidden = !hidden;
                              });
                            },

                            icon: Icon(
                              hidden ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),

                      if (create) ...[
                        const SizedBox(height: 12),

                        TextField(
                          controller: confirmation,
                          obscureText: hidden,
                          autocorrect: false,
                          enableSuggestions: false,

                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                          ),
                        ),
                      ],

                      if (error != null) ...[
                        const SizedBox(height: 12),

                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),

                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Cancel'),
                  ),

                  FilledButton(
                    onPressed: () {
                      if (first.text.runes.length < 14) {
                        update(() {
                          error =
                              'Enter at least '
                              '14 characters.';
                        });
                        return;
                      }

                      if (create && first.text != confirmation.text) {
                        update(() {
                          error = 'Passwords do not match.';
                        });
                        return;
                      }

                      Navigator.pop(dialogContext, first.text);
                    },

                    child: Text(create ? 'Back Up' : 'Restore'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      first.dispose();
      confirmation.dispose();
    }
  }

  // ========================================
  // CREATE GOOGLE DRIVE BACKUP
  // ========================================

  Future<void> _createBackup() async {
    if (_busy || !_connected) return;

    final password = await _requestPassword(create: true);

    if (!mounted || password == null || !_connected) {
      return;
    }

    final request = ++_request;
    final account = _account!;

    setState(() {
      _busy = true;
      _status =
          'Encrypting and uploading '
          'medical history...';
    });

    try {
      final result = await _service.createEncryptedBackup(account, password);

      if (!mounted || !_sessionValid || request != _request) {
        return;
      }

      setState(() {
        _status =
            'Encrypted backup verified: '
            '${result.name}';
      });

      // Refresh the file list after
      // a successful upload.

      try {
        final backups = await _service.connectAndListBackups(account);

        if (mounted && _sessionValid && request == _request) {
          setState(() {
            _backups = backups;
          });
        }
      } catch (_) {
        // Keep the verified upload result.
        // A listing error does not mean
        // the upload failed.
      }
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        _status = _errorText(error);
      });
    } finally {
      if (mounted && request == _request) {
        setState(() => _busy = false);
      }
    }
  }

  // ========================================
  // RESTORE SELECTED BACKUP
  // ========================================

  Future<void> _restore(MedicalDriveBackupFile backup) async {
    if (_busy || !_connected) return;

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore Medical History?'),

          content: const Text(
            'Missing records will be added '
            'to the current Google account. '
            'Existing visits will not be '
            'overwritten or deleted.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || !_connected) {
      return;
    }

    final password = await _requestPassword(create: false);

    if (!mounted || password == null || !_connected) {
      return;
    }

    final request = ++_request;
    final account = _account!;

    setState(() {
      _busy = true;
      _status =
          'Downloading and restoring '
          'encrypted medical history...';
    });

    try {
      final result = await _service.restoreEncryptedBackup(
        account,
        backup.id,
        password,
      );

      if (!mounted || !_sessionValid || request != _request) {
        return;
      }

      setState(() {
        _status =
            'Restore completed. '
            '${result.doctorsAdded} doctors, '
            '${result.visitsAdded} visits, '
            '${result.medicinesAdded} medicines '
            'and ${result.testsAdded} tests added. '
            '${result.existingVisitsSkipped} '
            'existing visits kept.';
      });
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        _status =
            'Restore not confirmed. '
            '${_errorText(error)}';
      });
    } finally {
      if (mounted && request == _request) {
        setState(() => _busy = false);
      }
    }
  }

  // ========================================
  // BACKUP DATE
  // ========================================

  String _dateText(DateTime? date) {
    if (date == null) return 'Unknown date';

    final local = date.toLocal();

    return '${local.day}/${local.month}/'
        '${local.year}';
  }

  // ========================================
  // MAIN SCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    if (!_sessionValid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Google Drive Backup')),

        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),

            child: Text(
              'Your Google account session '
              'has changed. Sign in again '
              'before using backups.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_busy,

      child: Scaffold(
        backgroundColor: AppColors.background,

        appBar: AppBar(title: const Text('Google Drive Backup')),

        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),

            children: [
              const Text(
                'Backup & Restore',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Protect your medical records '
                'with encrypted Google Drive '
                'backups and a recovery password.',
                style: TextStyle(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 22),

              // ============================
              // CONNECT GOOGLE DRIVE
              // ============================
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.add_to_drive,
                    color: AppColors.primary,
                  ),

                  title: const Text('Connect Google Drive'),

                  subtitle: Text(
                    _connected
                        ? 'Connected to your '
                              'medical Google account'
                        : 'Authorize private '
                              'backup storage',
                  ),

                  onTap: _busy ? null : _connect,

                  trailing: const Icon(Icons.chevron_right),
                ),
              ),

              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],

              if (_status != null) ...[
                const SizedBox(height: 14),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15),

                    child: Text(_status!),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // ============================
              // BACKUP BUTTON
              // ============================
              SizedBox(
                width: double.infinity,

                child: FilledButton.icon(
                  onPressed: _connected && !_busy ? _createBackup : null,

                  icon: const Icon(Icons.cloud_upload_outlined),

                  label: const Text('Back Up Medical History'),
                ),
              ),

              const SizedBox(height: 25),

              // ============================
              // RESTORE BACKUPS
              // ============================
              const Text(
                'Available Backups',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              if (!_connected)
                const Text(
                  'Connect Google Drive to '
                  'view available backups.',
                )
              else if (_backups.isEmpty)
                const Text('No encrypted backups found.')
              else
                for (final backup in _backups)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.restore_outlined),

                      title: Text(
                        _dateText(backup.createdAt ?? backup.modifiedAt),
                      ),

                      subtitle: Text(
                        backup.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      trailing: const Icon(Icons.chevron_right),

                      onTap: _busy ? null : () => _restore(backup),
                    ),
                  ),

              const SizedBox(height: 22),

              // ============================
              // PRIVACY NOTICE
              // ============================
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(15),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),

                      SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'Keep your recovery password '
                          'safe. Without it, an encrypted '
                          'backup cannot be restored.\n\n'
                          'Photos, prescription PDFs '
                          'and external test reports '
                          'are not supported by this '
                          'backup version.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

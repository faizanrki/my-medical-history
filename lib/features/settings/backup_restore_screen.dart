
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../services/google_drive_backup_service.dart';

// ==========================================
// MY MEDICAL HISTORY
// STEP 46 - BACKUP DIALOG LIFECYCLE FIX
// ==========================================

class BackupRestoreScreen extends StatefulWidget {
  final GoogleSignInAccount? initialAccount;

  final List<MedicalDriveBackupFile> initialBackups;

  const BackupRestoreScreen({
    super.key,
    this.initialAccount,
    this.initialBackups =
    const <MedicalDriveBackupFile>[],
  });

  @override
  State<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState
    extends State<BackupRestoreScreen>
    with WidgetsBindingObserver {
  final GoogleDriveBackupService _service =
      GoogleDriveBackupService.instance;

  late final int _generation;

  GoogleSignInAccount? _account;

  List<MedicalDriveBackupFile> _backups = [];

  bool _busy = false;

  String? _status;

  int _request = 0;

  bool get _sessionValid =>
      AppDatabase.instance.isSessionCurrent(
        _generation,
      );

  bool get _connected =>
      _account != null && _sessionValid;

  // ========================================
  // INITIALIZE
  // ========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _generation =
        AppDatabase.instance.sessionGeneration;

    if (_sessionValid &&
        widget.initialAccount != null) {
      _account = widget.initialAccount;

      _backups = List<MedicalDriveBackupFile>.of(
        widget.initialBackups,
      );

      _status =
      'Google Drive connected. '
          '${_backups.length} backup(s) available.';
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
            (_) {
          if (mounted && _sessionValid) {
            _connect(requestPermission: false);
          }
        },
      );
    }
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed &&
        mounted) {
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
  // SAFE ERROR MESSAGE
  // ========================================

  String _errorText(Object error) {
    if (error is FormatException) {
      return error.message;
    }

    if (error is StateError) {
      return error.message.toString();
    }

    return 'Operation failed. Check your '
        'Google Drive connection and try again.';
  }

  // ========================================
  // GET GOOGLE ACCOUNT
  // ========================================

  Future<GoogleSignInAccount>
  _getGoogleAccount() async {
    if (_connected) {
      return _account!;
    }

    final attempt = GoogleSignIn.instance
        .attemptLightweightAuthentication();

    if (attempt == null) {
      throw StateError(
        'Google account is not available. '
            'Please sign in again.',
      );
    }

    final account = await attempt;

    if (account == null || !_sessionValid) {
      throw StateError(
        'Google account is unavailable '
            'or the session has changed.',
      );
    }

    return account;
  }

  // ========================================
  // CONNECT GOOGLE DRIVE
  // ========================================

  Future<void> _connect({
    bool requestPermission = true,
  }) async {
    if (!mounted ||
        !_sessionValid ||
        _busy) {
      return;
    }

    final request = ++_request;

    setState(() {
      _busy = true;
      _status = requestPermission
          ? 'Connecting to Google Drive...'
          : 'Checking Google Drive access...';
    });

    try {
      final account = await _getGoogleAccount();

      if (!mounted ||
          !_sessionValid ||
          request != _request) {
        return;
      }

      final authorization =
      await account.authorizationClient
          .authorizationForScopes([
        GoogleDriveBackupService.driveScope,
      ]);

      if (!mounted ||
          !_sessionValid ||
          request != _request) {
        return;
      }

      if (authorization == null &&
          !requestPermission) {
        setState(() {
          _account = null;
          _backups = [];
          _status =
          'Tap Connect Google Drive '
              'to grant backup permission.';
        });

        return;
      }

      final files =
      await _service.connectAndListBackups(
        account,
      );

      if (!mounted ||
          !_sessionValid ||
          request != _request) {
        return;
      }

      setState(() {
        _account = account;
        _backups = files;
        _status =
        'Google Drive connected. '
            '${files.length} backup(s) found.';
      });
    } catch (error) {
      if (!mounted ||
          !_sessionValid ||
          request != _request) {
        return;
      }

      setState(() {
        _account = null;
        _backups = [];
        _status = _errorText(error);
      });
    } finally {
      if (mounted &&
          _sessionValid &&
          request == _request) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ========================================
  // SHOW RECOVERY PASSWORD DIALOG
  // ========================================

  Future<String?> _requestPassword({
    required bool create,
  }) async {
    if (!mounted || !_sessionValid) {
      return null;
    }

    // FIX:
    // The dialog owns its TextEditingController.
    //
    // We do not create and immediately dispose
    // controllers around showDialog().
    //
    // The dialog disposes its controllers
    // when Flutter removes the dialog widget.

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RecoveryPasswordDialog(
        create: create,
      ),
    );
  }

  // ========================================
  // CREATE ENCRYPTED BACKUP
  // ========================================

  Future<void> _createBackup() async {
    if (_busy || !_connected) {
      return;
    }

    final account = _account;

    if (account == null) {
      return;
    }

    final password = await _requestPassword(
      create: true,
    );

    if (!mounted ||
        !_sessionValid ||
        password == null ||
        _busy) {
      return;
    }

    // Allow Flutter to finish the current
    // frame after dismissing the dialog.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted || !_sessionValid || _busy) {
      return;
    }

    final request = ++_request;

    setState(() {
      _busy = true;
      _status =
      'Encrypting your medical history '
          'and uploading to Google Drive...';
    });

    try {
      final backup =
      await _service.createEncryptedBackup(
        account,
        password,
      );

      if (!mounted ||
          !_sessionValid ||
          request != _request) {
        return;
      }

      setState(() {
        _status =
        'Encrypted backup uploaded and '
            'verified successfully.\n\n'
            '${backup.name}';
      });

      // Refresh backup list.

      try {
        final updated =
        await _service.connectAndListBackups(
          account,
        );

        if (mounted &&
            _sessionValid &&
            request == _request) {
          setState(() {
            _backups = updated;
          });
        }
      } catch (_) {
        // Do not hide successful upload
        // confirmation if refresh fails.
      }
    } catch (error) {
      if (!mounted ||
          !_sessionValid ||
          request != _request) {
        return;
      }

      setState(() {
        _status = _errorText(error);
      });
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ========================================
  // RESTORE MEDICAL HISTORY
  // ========================================

  Future<void> _restore(
      MedicalDriveBackupFile backup,
      ) async {
    if (_busy || !_connected) {
      return;
    }

    final account = _account;

    if (account == null) {
      return;
    }

    // FIX:
    // Use one password/confirmation dialog.
    // Avoid opening a second dialog while
    // the first dialog is still closing.

    final password = await _requestPassword(
      create: false,
    );

    if (!mounted ||
        !_sessionValid ||
        password == null ||
        _busy) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted || !_sessionValid || _busy) {
      return;
    }

    final request = ++_request;

    setState(() {
      _busy = true;
      _status =
      'Downloading and restoring '
          'medical records...';
    });

    try {
      final result =
      await _service.restoreEncryptedBackup(
        account,
        backup.id,
        password,
      );

      if (!mounted ||
          !_sessionValid ||
          request != _request) {
        return;
      }

      setState(() {
        _status =
        'Restore completed successfully.\n\n'
            'Doctors added: ${result.doctorsAdded}\n'
            'Visits added: ${result.visitsAdded}\n'
            'Medicines added: ${result.medicinesAdded}\n'
            'Tests added: ${result.testsAdded}\n'
            'Existing visits kept: '
            '${result.existingVisitsSkipped}';
      });
    } catch (error) {
      if (!mounted ||
          !_sessionValid ||
          request != _request) {
        return;
      }

      setState(() {
        _status =
        'Restore could not be confirmed.\n'
            '${_errorText(error)}';
      });
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ========================================
  // FORMAT DATE
  // ========================================

  String _dateText(DateTime? date) {
    if (date == null) {
      return 'Unknown date';
    }

    final local = date.toLocal();

    return '${local.day}/${local.month}/'
        '${local.year}';
  }

  // ========================================
  // INVALID SESSION SCREEN
  // ========================================

  Widget _invalidSessionScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Google Drive Backup',
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your Google account session '
                'has changed. Sign in again '
                'to access medical backups.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // ========================================
  // MAIN SCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    if (!_sessionValid) {
      return _invalidSessionScreen();
    }

    return PopScope(
      canPop: !_busy,

      child: Scaffold(
        backgroundColor: AppColors.background,

        appBar: AppBar(
          title: const Text(
            'Google Drive Backup',
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh backups',
              onPressed: _busy
                  ? null
                  : () => _connect(
                requestPermission: false,
              ),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

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
                'Keep your medical records '
                    'safe with encrypted '
                    'Google Drive backups.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 22),

              // ============================
              // CONNECTION CARD
              // ============================

              Card(
                child: ListTile(
                  leading: Icon(
                    _connected
                        ? Icons.cloud_done_outlined
                        : Icons.add_to_drive,
                    color: AppColors.primary,
                  ),

                  title: Text(
                    _connected
                        ? 'Google Drive Connected'
                        : 'Connect Google Drive',
                  ),

                  subtitle: Text(
                    _connected
                        ? 'Using your signed-in '
                        'Google account'
                        : 'Authorize private '
                        'backup storage',
                  ),

                  trailing: const Icon(
                    Icons.chevron_right,
                  ),

                  onTap: _busy
                      ? null
                      : () => _connect(),
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
                    padding: const EdgeInsets.all(16),

                    child: Text(
                      _status!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
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
                  onPressed: _connected && !_busy
                      ? _createBackup
                      : null,

                  icon: const Icon(
                    Icons.cloud_upload_outlined,
                  ),

                  label: const Text(
                    'Back Up Medical History',
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ============================
              // AVAILABLE BACKUPS
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
                  'Connect Google Drive '
                      'to view your backups.',
                )
              else if (_backups.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),

                    child: Text(
                      'No encrypted backups '
                          'found yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (final backup in _backups)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.restore_outlined,
                        color: AppColors.primary,
                      ),

                      title: Text(
                        _dateText(
                          backup.createdAt ??
                              backup.modifiedAt,
                        ),
                      ),

                      subtitle: Text(
                        backup.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      trailing: const Icon(
                        Icons.chevron_right,
                      ),

                      onTap: _busy
                          ? null
                          : () => _restore(backup),
                    ),
                  ),

              const SizedBox(height: 24),

              // ============================
              // BACKUP INFORMATION
              // ============================

              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),

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
                          'Keep your recovery password '
                              'safe. Without it, an '
                              'encrypted backup cannot '
                              'be restored.\n\n'
                              'This backup version does '
                              'not include external images, '
                              'prescription PDFs or '
                              'medical test reports.',

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
          ),
        ),
      ),
    );
  }
}

// ==========================================
// RECOVERY PASSWORD DIALOG
// ==========================================
//
// FIX:
// The dialog owns and disposes its own
// TextEditingControllers.
//
// Previously the calling method disposed
// the controllers immediately after
// showDialog completed.
//
// ==========================================

class _RecoveryPasswordDialog
    extends StatefulWidget {
  final bool create;

  const _RecoveryPasswordDialog({
    required this.create,
  });

  @override
  State<_RecoveryPasswordDialog> createState() =>
      _RecoveryPasswordDialogState();
}

class _RecoveryPasswordDialogState
    extends State<_RecoveryPasswordDialog> {
  final TextEditingController _passwordController =
  TextEditingController();

  final TextEditingController _confirmController =
  TextEditingController();

  bool _obscure = true;

  String? _error;

  // ========================================
  // DISPOSE ONLY WHEN DIALOG IS REMOVED
  // ========================================

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();

    super.dispose();
  }

  // ========================================
  // SUBMIT PASSWORD
  // ========================================

  void _submit() {
    final password =
        _passwordController.text;

    if (widget.create &&
        password.runes.length < 14) {
      setState(() {
        _error =
        'Use a password with '
            'at least 14 characters.';
      });
      return;
    }

    if (!widget.create && password.isEmpty) {
      setState(() {
        _error =
        'Enter your recovery password.';
      });
      return;
    }

    if (widget.create &&
        password != _confirmController.text) {
      setState(() {
        _error = 'Passwords do not match.';
      });
      return;
    }

    // Remove keyboard focus before
    // dismissing the dialog.

    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop(password);
  }

  // ========================================
  // BUILD DIALOG
  // ========================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.create
            ? 'Create Encrypted Backup'
            : 'Restore Medical History',
      ),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Text(
              widget.create
                  ? 'Create a recovery password '
                  'with at least 14 characters. '
                  'You will need this password '
                  'if you reinstall the app '
                  'or change phones.'
                  : 'Enter the recovery password '
                  'used when creating this backup.\n\n'
                  'Missing records will be added. '
                  'Existing visits will not be '
                  'overwritten or deleted.',
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,

              obscureText: _obscure,

              autocorrect: false,

              enableSuggestions: false,

              textInputAction: widget.create
                  ? TextInputAction.next
                  : TextInputAction.done,

              onSubmitted: widget.create
                  ? null
                  : (_) => _submit(),

              decoration: InputDecoration(
                labelText: 'Recovery Password',

                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscure = !_obscure;
                    });
                  },

                  icon: Icon(
                    _obscure
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            ),

            if (widget.create) ...[
              const SizedBox(height: 12),

              TextField(
                controller: _confirmController,

                obscureText: _obscure,

                autocorrect: false,

                enableSuggestions: false,

                textInputAction:
                TextInputAction.done,

                onSubmitted: (_) => _submit(),

                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),

              Text(
                _error!,

                style: const TextStyle(
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus
                ?.unfocus();

            Navigator.of(context).pop();
          },

          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed: _submit,

          child: Text(
            widget.create
                ? 'Create Backup'
                : 'Restore',
          ),
        ),
      ],
    );
  }
}

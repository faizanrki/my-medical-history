import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_colors.dart';
import '../../services/google_drive_backup_service.dart';
import '../home/dashboard_screen.dart';

class DriveSetupScreen extends StatefulWidget {
  const DriveSetupScreen({super.key});

  @override
  State<DriveSetupScreen> createState() => _DriveSetupScreenState();
}

class _DriveSetupScreenState extends State<DriveSetupScreen> {
  bool _autoSync = false;
  bool _isLoading = false;
  GoogleSignInAccount? _account;
  String _backupStatus = 'Not started';
  String _lastSync = 'Never';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  @override
  void initState() {
    super.initState();
    _checkSignIn();
  }

  Future<void> _checkSignIn() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account != null && mounted) {
        setState(() {
          _account = account;
        });
        _listBackups(account);
      }
    } catch (_) {}
  }

  Future<void> _connectDrive() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _googleSignIn.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );
      final account = await _googleSignIn.authenticate();
      if (account != null) {
        setState(() {
          _account = account;
        });
        await _listBackups(account);
        _showMessage('Google Drive connected successfully!');
      }
    } catch (e) {
      if (e.toString().contains('clientConfigurationError') ||
          e.toString().contains('serverClientId')) {
        _showMessage(
          'Google Drive requires a Web Client ID.\n'
          'Run app with: flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=your_id',
        );
      } else {
        _showMessage('Failed to connect Google Drive: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _listBackups(GoogleSignInAccount account) async {
    try {
      final backups = await GoogleDriveBackupService.instance.connectAndListBackups(account);
      setState(() {
        _backupStatus = backups.isNotEmpty ? '${backups.length} backup(s) found' : 'No backups found';
        if (backups.isNotEmpty && backups.first.createdAt != null) {
          _lastSync = backups.first.createdAt.toString();
        }
      });
    } catch (e) {
      setState(() {
        _backupStatus = 'Error listing backups';
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)),
    );
  }

  void _openDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const DashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Google Drive Backup'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.cloud_outlined,
              size: 70,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Keep your records backed up',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your medical records can be synchronized with your Google Drive securely.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Google Account',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    _DetailRow(
                      label: 'Account',
                      value: _account?.email ?? 'Not connected',
                    ),
                    _DetailRow(
                      label: 'Connection',
                      value: _account != null ? 'Connected' : 'Not connected',
                    ),
                    _DetailRow(
                      label: 'Last Sync',
                      value: _lastSync,
                    ),
                    _DetailRow(
                      label: 'Backup Status',
                      value: _backupStatus,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text(
                  'Auto Sync',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Automatically back up your records.',
                ),
                secondary: const Icon(
                  Icons.sync,
                  color: AppColors.primary,
                ),
                value: _autoSync,
                activeThumbColor: AppColors.primary,
                onChanged: (bool value) {
                  setState(() {
                    _autoSync = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _connectDrive,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link),
                label: Text(
                  _account != null ? 'Reconnect / Switch Account' : 'Connect Google Drive',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _account == null
                    ? null
                    : () async {
                        if (_account != null) {
                          await _listBackups(_account!);
                          _showMessage('Backup status refreshed.');
                        }
                      },
                icon: const Icon(Icons.sync),
                label: const Text('Sync Now'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openDashboard,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Open Dashboard'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Google Drive appDataFolder is used exclusively for encrypted medical backups.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

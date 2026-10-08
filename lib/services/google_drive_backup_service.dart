import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../data/app_database.dart';
import 'medical_backup_crypto.dart';
import 'medical_backup_repository.dart';

// ============================================
// GOOGLE DRIVE BACKUP FILE MODEL
// ============================================

class MedicalDriveBackupFile {
  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final int? sizeBytes;

  const MedicalDriveBackupFile({
    required this.id,
    required this.name,
    this.createdAt,
    this.modifiedAt,
    this.sizeBytes,
  });

  factory MedicalDriveBackupFile.fromJson(Map<String, dynamic> map) {
    return MedicalDriveBackupFile(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdTime']?.toString() ?? ''),
      modifiedAt: DateTime.tryParse(map['modifiedTime']?.toString() ?? ''),
      sizeBytes: int.tryParse(map['size']?.toString() ?? ''),
    );
  }
}

// ============================================
// GOOGLE DRIVE BACKUP SERVICE
// ============================================

class GoogleDriveBackupService {
  GoogleDriveBackupService._();

  static final GoogleDriveBackupService instance = GoogleDriveBackupService._();

  static const String driveScope =
      'https://www.googleapis.com/auth/drive.appdata';

  static const String backupFilePrefix = 'mmh_backup_v1_';

  static const List<String> _scopes = [driveScope];

  static const Duration _timeout = Duration(seconds: 90);

  // ========================================
  // VERIFY ACTIVE GOOGLE ACCOUNT
  // ========================================

  Future<void> _verifyAccount(
    GoogleSignInAccount account,
    int generation,
  ) async {
    if (!AppDatabase.instance.isSessionCurrent(generation)) {
      throw StateError(
        'The medical account session changed. '
        'Sign in again.',
      );
    }

    final db = await AppDatabase.instance.database;

    if (!AppDatabase.instance.isSessionCurrent(generation)) {
      throw StateError('The medical account session changed.');
    }

    final fingerprint = sha256.convert(utf8.encode(account.id)).toString();

    if (p.basename(db.path) !=
        'my_medical_history_account_'
            '$fingerprint.db') {
      throw StateError(
        'Google Drive account does not '
        'match the selected medical database.',
      );
    }
  }

  // ========================================
  // GOOGLE DRIVE AUTHORIZATION
  // ========================================

  Future<Map<String, String>> _authHeaders(
    GoogleSignInAccount account,
    int generation,
  ) async {
    await _verifyAccount(account, generation);

    final client = account.authorizationClient;

    final authorization =
        await client.authorizationForScopes(_scopes) ??
        await client.authorizeScopes(_scopes);

    await _verifyAccount(account, generation);

    return {
      'Authorization': 'Bearer ${authorization.accessToken}',
      'Accept': 'application/json',
    };
  }

  // ========================================
  // CONNECT AND LIST BACKUPS
  // ========================================

  Future<List<MedicalDriveBackupFile>> connectAndListBackups(
    GoogleSignInAccount account,
  ) async {
    final generation = AppDatabase.instance.sessionGeneration;

    final headers = await _authHeaders(account, generation);

    final files = <MedicalDriveBackupFile>[];

    String? pageToken;
    var pages = 0;

    do {
      await _verifyAccount(account, generation);

      if (++pages > 100) {
        throw StateError('Drive backup listing limit reached.');
      }

      final query = <String, String>{
        'spaces': 'appDataFolder',
        'q':
            "trashed = false and name contains "
            "'$backupFilePrefix'",
        'fields':
            'nextPageToken,files('
            'id,name,size,createdTime,modifiedTime)',
        'pageSize': '100',
        if (pageToken != null) 'pageToken': pageToken,
      };

      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', query);

      final response = await http.get(uri, headers: headers).timeout(_timeout);

      await _verifyAccount(account, generation);

      _checkHttp(response, expected: [200], action: 'list backups');

      final map = _decodeObject(response.body);

      final records = map['files'];

      if (records is! List) {
        throw const FormatException('Invalid Drive file listing.');
      }

      for (final entry in records) {
        if (entry is! Map) continue;

        final file = MedicalDriveBackupFile.fromJson(
          Map<String, dynamic>.from(entry),
        );

        if (file.id.isNotEmpty && file.name.startsWith(backupFilePrefix)) {
          files.add(file);
        }
      }

      final next = map['nextPageToken'];

      pageToken = next is String && next.isNotEmpty ? next : null;
    } while (pageToken != null);

    await _verifyAccount(account, generation);

    files.sort(
      (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      ),
    );

    return files;
  }

  // ========================================
  // CREATE ENCRYPTED BACKUP
  // ========================================

  Future<MedicalDriveBackupFile> createEncryptedBackup(
    GoogleSignInAccount account,
    String recoveryPassword,
  ) async {
    final generation = AppDatabase.instance.sessionGeneration;

    final headers = await _authHeaders(account, generation);

    // Read medical data without exporting
    // the local SQLCipher encryption key.
    final document = await MedicalBackupRepository.instance.exportDocument(
      account.id,
    );

    await _verifyAccount(account, generation);

    // Encrypt all medical data before upload.
    final encrypted = await MedicalBackupCrypto.encrypt(
      document,
      recoveryPassword,
    );

    await _verifyAccount(account, generation);

    // ======================================
    // START GOOGLE DRIVE UPLOAD
    // ======================================

    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    final fileName = '$backupFilePrefix$stamp.mmhbak';

    final startUri = Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
      'uploadType': 'resumable',
      'fields': 'id,name,size,createdTime,modifiedTime',
    });

    final initResponse = await http
        .post(
          startUri,
          headers: {
            ...headers,
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': 'application/octet-stream',
            'X-Upload-Content-Length': '${encrypted.length}',
          },
          body: jsonEncode({
            'name': fileName,
            'parents': ['appDataFolder'],
            'mimeType': 'application/octet-stream',
          }),
        )
        .timeout(_timeout);

    await _verifyAccount(account, generation);

    _checkHttp(initResponse, expected: [200], action: 'start backup upload');

    // ======================================
    // VALIDATE UPLOAD SESSION
    // ======================================

    final sessionHeader = initResponse.headers['location'];

    if (sessionHeader == null) {
      throw StateError(
        'Google Drive did not create '
        'an upload session.',
      );
    }

    final sessionUri = Uri.tryParse(sessionHeader);

    // Never send a Google OAuth token to
    // an arbitrary URL.

    if (sessionUri == null ||
        sessionUri.scheme != 'https' ||
        !(sessionUri.host == 'www.googleapis.com' ||
            sessionUri.host.endsWith('.googleapis.com'))) {
      throw StateError('Invalid Google Drive upload endpoint.');
    }

    // ======================================
    // UPLOAD ENCRYPTED BYTES
    // ======================================

    final uploadResponse = await http
        .put(
          sessionUri,
          headers: {...headers, 'Content-Type': 'application/octet-stream'},
          body: encrypted,
        )
        .timeout(_timeout);

    await _verifyAccount(account, generation);

    _checkHttp(uploadResponse, expected: [200, 201], action: 'upload backup');

    final uploaded = MedicalDriveBackupFile.fromJson(
      _decodeObject(uploadResponse.body),
    );

    if (!_safeFileId(uploaded.id) || uploaded.name != fileName) {
      throw StateError(
        'Google Drive returned an invalid '
        'backup confirmation.',
      );
    }

    // ======================================
    // VERIFY UPLOADED DATA
    // ======================================

    // Download the encrypted file again
    // and compare its SHA-256 hash with
    // the locally encrypted backup.

    final checkBytes = await _downloadBackup(
      account,
      generation,
      headers,
      uploaded.id,
    );

    if (sha256.convert(checkBytes).toString() !=
        sha256.convert(encrypted).toString()) {
      throw StateError('Uploaded backup verification failed.');
    }

    return uploaded;
  }

  // ========================================
  // RESTORE ENCRYPTED BACKUP
  // ========================================

  Future<MedicalBackupRestoreResult> restoreEncryptedBackup(
    GoogleSignInAccount account,
    String fileId,
    String recoveryPassword,
  ) async {
    final generation = AppDatabase.instance.sessionGeneration;

    final headers = await _authHeaders(account, generation);

    // Download only from the private
    // app-specific Google Drive folder.

    final bytes = await _downloadBackup(account, generation, headers, fileId);

    // ======================================
    // DECRYPT
    // ======================================

    final document = await MedicalBackupCrypto.decrypt(bytes, recoveryPassword);

    await _verifyAccount(account, generation);

    // ======================================
    // RESTORE MISSING RECORDS
    // ======================================

    // Transactional and additive.
    // Existing visits are not deleted
    // or overwritten.

    return MedicalBackupRepository.instance.mergeDocument(document, account.id);
  }

  // ========================================
  // DOWNLOAD AND VERIFY BACKUP
  // ========================================

  Future<List<int>> _downloadBackup(
    GoogleSignInAccount account,
    int generation,
    Map<String, String> headers,
    String fileId,
  ) async {
    if (!_safeFileId(fileId)) {
      throw const FormatException('Invalid backup file ID.');
    }

    await _verifyAccount(account, generation);

    // ======================================
    // CHECK METADATA FIRST
    // ======================================

    final metadataResponse = await http
        .get(
          Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
            'fields': 'id,name,parents,size',
          }),
          headers: headers,
        )
        .timeout(_timeout);

    await _verifyAccount(account, generation);

    _checkHttp(metadataResponse, expected: [200], action: 'verify backup file');

    final info = _decodeObject(metadataResponse.body);

    if (!(info['name']?.toString().startsWith(backupFilePrefix) ?? false) ||
        info['parents'] is! List ||
        !(info['parents'] as List).contains('appDataFolder')) {
      throw const FormatException(
        'This file is not an app-private '
        'medical backup.',
      );
    }

    final size = int.tryParse(info['size']?.toString() ?? '');

    if (size == null ||
        size <= 0 ||
        size > MedicalBackupCrypto.maxEncryptedBytes) {
      throw const FormatException(
        'Backup is missing or exceeds '
        'the supported size limit.',
      );
    }

    // ======================================
    // DOWNLOAD FILE
    // ======================================

    final response = await http
        .get(
          Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
            'alt': 'media',
          }),
          headers: headers,
        )
        .timeout(_timeout);

    await _verifyAccount(account, generation);

    _checkHttp(response, expected: [200], action: 'download backup');

    if (response.bodyBytes.length != size) {
      throw const FormatException(
        'Downloaded backup size '
        'does not match Drive metadata.',
      );
    }

    return response.bodyBytes;
  }

  // ========================================
  // HELPERS
  // ========================================

  static bool _safeFileId(String fileId) {
    return RegExp(r'^[A-Za-z0-9_-]{5,256}$').hasMatch(fileId);
  }

  static Map<String, dynamic> _decodeObject(String content) {
    final decoded = jsonDecode(content);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Google Drive response.');
    }

    return decoded;
  }

  static void _checkHttp(
    http.Response response, {
    required List<int> expected,
    required String action,
  }) {
    if (expected.contains(response.statusCode)) {
      return;
    }

    if (response.statusCode == 401) {
      throw StateError(
        'Google Drive authorization expired. '
        'Reconnect Drive.',
      );
    }

    if (response.statusCode == 403) {
      throw StateError(
        'Google Drive permission was denied '
        'or API access is unavailable.',
      );
    }

    throw StateError(
      'Unable to $action '
      '(HTTP ${response.statusCode}).',
    );
  }
}

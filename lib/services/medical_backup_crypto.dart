import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Portable recovery encryption.
/// No device-local SQLCipher key is exported.
/// The password is never stored or sent to Google Drive.
class MedicalBackupCrypto {
  MedicalBackupCrypto._();

  static const String format = 'my-medical-history-encrypted';

  static const int formatVersion = 1;
  static const int kdfIterations = 210000;
  static const int maxEncryptedBytes = 12 * 1024 * 1024;

  static final AesGcm _cipher = AesGcm.with256bits();

  static final Random _random = Random.secure();

  static List<int> _randomBytes(int count) {
    return List<int>.generate(count, (_) => _random.nextInt(256));
  }

  static void _validatePassword(String password) {
    if (password.runes.length < 14) {
      throw const FormatException(
        'Use a backup recovery password '
        'of at least 14 characters.',
      );
    }

    if (password.runes.length > 1024) {
      throw const FormatException('Recovery password is too long.');
    }
  }

  // ========================================
  // ENCRYPT BACKUP
  // ========================================

  static Future<List<int>> encrypt(
    Map<String, Object?> document,
    String password,
  ) async {
    _validatePassword(password);

    final clearText = utf8.encode(jsonEncode(document));

    if (clearText.length > maxEncryptedBytes - 2048) {
      throw const FormatException(
        'Medical history is too large '
        'for this backup version.',
      );
    }

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);

    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: kdfIterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);

    final box = await _cipher.encrypt(clearText, secretKey: key, nonce: nonce);

    final envelope = <String, Object?>{
      'format': format,
      'version': formatVersion,
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': kdfIterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText),
    };

    final result = utf8.encode(jsonEncode(envelope));

    if (result.length > maxEncryptedBytes) {
      throw const FormatException(
        'Encrypted backup exceeds '
        'the supported size limit.',
      );
    }

    return result;
  }

  // ========================================
  // DECRYPT BACKUP
  // ========================================

  static Future<Map<String, dynamic>> decrypt(
    List<int> encryptedBytes,
    String password,
  ) async {
    if (password.isEmpty || password.runes.length > 1024) {
      throw const FormatException('Enter your backup recovery password.');
    }

    if (encryptedBytes.isEmpty || encryptedBytes.length > maxEncryptedBytes) {
      throw const FormatException('Backup is empty or too large.');
    }

    late final Map<String, dynamic> envelope;

    try {
      final decoded = jsonDecode(utf8.decode(encryptedBytes));

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup format.');
      }

      envelope = decoded;
    } catch (_) {
      throw const FormatException(
        'Not a supported encrypted '
        'medical backup.',
      );
    }

    if (envelope['format'] != format ||
        envelope['version'] != formatVersion ||
        envelope['cipher'] != 'AES-256-GCM' ||
        envelope['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        envelope['iterations'] != kdfIterations) {
      throw const FormatException(
        'Unsupported encrypted '
        'medical backup format.',
      );
    }

    try {
      final salt = base64Decode(envelope['salt'] as String);

      final nonce = base64Decode(envelope['nonce'] as String);

      final mac = base64Decode(envelope['mac'] as String);

      final ciphertext = base64Decode(envelope['ciphertext'] as String);

      if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
        throw const FormatException('Invalid cryptographic parameters.');
      }

      final key = await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: kdfIterations,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);

      final clear = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );

      final document = jsonDecode(utf8.decode(clear));

      if (document is! Map<String, dynamic>) {
        throw const FormatException('Invalid decrypted backup.');
      }

      return document;
    } catch (_) {
      throw const FormatException(
        'Wrong recovery password '
        'or damaged backup.',
      );
    }
  }
}

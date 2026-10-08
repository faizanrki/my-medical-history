
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

// =====================================
// MY MEDICAL HISTORY
// ENCRYPTED ACCOUNT DATABASE
// UPDATED STEP 45
// =====================================

class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance =
  AppDatabase._internal();

  // =====================================
  // DATABASE SETTINGS
  // =====================================

  // Keep the legacy database name unchanged.
  static const String databaseName =
      'my_medical_history.db';

  static const int databaseVersion = 1;

  // Keep the legacy encryption-key name.
  static const String _passwordKey =
      'my_medical_history_database_key_v1';

  final FlutterSecureStorage _secureStorage =
  const FlutterSecureStorage();

  Future<Database>? _databaseFuture;

  // Hashed stable Google account ID.
  String? _accountFingerprint;

  // Require Google Sign-In before access.
  // Existing legacy data is not deleted.
  bool _legacyModeAllowed = false;

  // Serialize account switching.
  Future<void> _scopeTransition =
  Future<void>.value();

  // =====================================
  // ACCOUNT SESSION PROTECTION
  // =====================================

  bool get isAccountSelected =>
      _accountFingerprint != null &&
          !_legacyModeAllowed;

  // Invalidate stale screens and requests.
  int _sessionGeneration = 0;

  int get sessionGeneration =>
      _sessionGeneration;

  bool isSessionCurrent(int generation) {
    return generation == _sessionGeneration &&
        isAccountSelected;
  }

  // =====================================
  // TABLE NAMES
  // =====================================

  static const String doctorsTable =
      'doctors';

  static const String visitsTable =
      'visits';

  static const String medicinesTable =
      'medicines';

  static const String testsTable =
      'medical_tests';

  static const String attachmentsTable =
      'attachments';

  // =====================================
  // GET ACTIVE ENCRYPTED DATABASE
  // =====================================

  Future<Database> get database async {
    // Wait for an account switch or lock.
    await _scopeTransition;

    if (!_legacyModeAllowed &&
        _accountFingerprint == null) {
      throw StateError(
        'Medical storage is locked. '
            'Sign in before accessing records.',
      );
    }

    return _databaseFuture ??=
        _openDatabase();
  }

  // =====================================
  // SELECT GOOGLE ACCOUNT
  // =====================================

  Future<void> useGoogleAccount(
      String googleAccountId,
      ) {
    // Pass the verified stable Google ID,
    // never an email address or text input.

    final accountId =
    googleAccountId.trim();

    if (accountId.isEmpty ||
        accountId.length > 256) {
      throw ArgumentError(
        'A valid Google account ID '
            'is required.',
      );
    }

    // Create a stable account fingerprint.
    final fingerprint = sha256
        .convert(utf8.encode(accountId))
        .toString();

    final operation =
    _scopeTransition.then((_) async {
      // ==================================
      // SAME ACCOUNT
      // ==================================

      if (_accountFingerprint == fingerprint &&
          !_legacyModeAllowed) {
        await (_databaseFuture ??=
            _openDatabase());

        return;
      }

      // ==================================
      // INVALIDATE PREVIOUS SESSION
      // ==================================

      _sessionGeneration++;

      // ==================================
      // LOCK PREVIOUS ACCOUNT
      // ==================================

      _legacyModeAllowed = false;
      _accountFingerprint = null;

      await _closeCurrentDatabase();

      // ==================================
      // SELECT NEW ACCOUNT
      // ==================================

      _accountFingerprint = fingerprint;

      try {
        // Open account-specific database.
        final selectedDb =
        await (_databaseFuture =
            _openDatabase());

        // ==================================
        // VERIFY SQLCIPHER
        // ==================================

        final cipher =
        await selectedDb.rawQuery(
          'PRAGMA cipher_version',
        );

        if (cipher.isEmpty ||
            cipher.first.isEmpty ||
            cipher.first.values.first
                .toString()
                .trim()
                .isEmpty) {
          throw StateError(
            'SQLCipher check failed.',
          );
        }
      } catch (_) {
        // Keep storage locked if opening
        // the selected account fails.

        _accountFingerprint = null;

        await _closeCurrentDatabase();

        rethrow;
      }
    });

    // Allow subsequent transitions even if
    // this operation fails.

    _scopeTransition =
        operation.then<void>(
              (_) {},
          onError: (
              Object _,
              StackTrace __,
              ) {},
        );

    return operation;
  }

  // =====================================
  // LOCK ACCOUNT ON SIGN OUT
  // =====================================

  Future<void> lockAccount() {
    final operation =
    _scopeTransition.then((_) async {
      // Invalidate old medical forms,
      // screens and asynchronous requests.

      _sessionGeneration++;

      // Lock account-specific access.
      _accountFingerprint = null;
      _legacyModeAllowed = false;

      // Close connection without deleting
      // medical records or encryption keys.

      await _closeCurrentDatabase();
    });

    _scopeTransition =
        operation.then<void>(
              (_) {},
          onError: (
              Object _,
              StackTrace __,
              ) {},
        );

    return operation;
  }

  // =====================================
  // CLOSE CURRENT DATABASE
  // =====================================

  Future<void> _closeCurrentDatabase() async {
    final previous = _databaseFuture;

    _databaseFuture = null;

    if (previous == null) {
      return;
    }

    Database? opened;

    try {
      opened = await previous;
    } catch (_) {
      return;
    }

    if (opened.isOpen) {
      await opened.close();
    }
  }

  // =====================================
  // GET OR CREATE ENCRYPTION PASSWORD
  // =====================================

  Future<String> _getDatabasePassword(
      String databasePath,
      String passwordKey,
      ) async {
    final savedPassword =
    await _secureStorage.read(
      key: passwordKey,
    );

    if (savedPassword != null &&
        savedPassword.isNotEmpty) {
      return savedPassword;
    }

    // Never create a replacement key
    // for an existing encrypted database.

    if (await databaseExists(databasePath)) {
      throw StateError(
        'Encrypted database exists, '
            'but its key is missing. '
            'No data was deleted.',
      );
    }

    final random = Random.secure();

    final bytes = List<int>.generate(
      32,
          (_) => random.nextInt(256),
    );

    final password =
    base64UrlEncode(bytes);

    await _secureStorage.write(
      key: passwordKey,
      value: password,
    );

    return password;
  }

  // =====================================
  // OPEN ENCRYPTED DATABASE
  // =====================================

  Future<Database> _openDatabase() async {
    final databasesPath =
    await getDatabasesPath();

    final fingerprint =
        _accountFingerprint;

    // Do not rename the legacy database.
    final fileName = fingerprint == null
        ? databaseName
        : 'my_medical_history_account_'
        '$fingerprint.db';

    final passwordKey = fingerprint == null
        ? _passwordKey
        : 'my_medical_history_account_key_'
        '${fingerprint}_v1';

    final databasePath = join(
      databasesPath,
      fileName,
    );

    final password =
    await _getDatabasePassword(
      databasePath,
      passwordKey,
    );

    return openDatabase(
      databasePath,
      password: password,
      version: databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // =====================================
  // CONFIGURE DATABASE
  // =====================================

  Future<void> _onConfigure(
      Database db,
      ) async {
    // Enforce foreign key relationships.
    await db.execute(
      'PRAGMA foreign_keys = ON',
    );
  }

  // =====================================
  // CREATE DATABASE TABLES
  // =====================================

  Future<void> _onCreate(
      Database db,
      int version,
      ) async {
    await _createDoctorsTable(db);

    await _createVisitsTable(db);

    await _createMedicinesTable(db);

    await _createTestsTable(db);

    await _createAttachmentsTable(db);

    await _createIndexes(db);
  }

  // =====================================
  // TABLE 1 - DOCTORS
  // =====================================

  Future<void> _createDoctorsTable(
      Database db,
      ) async {
    await db.execute('''
      CREATE TABLE $doctorsTable (
        id TEXT PRIMARY KEY NOT NULL,

        name TEXT NOT NULL,

        specialization TEXT NOT NULL
          DEFAULT '',

        phone TEXT NOT NULL
          DEFAULT '',

        hospital_name TEXT NOT NULL
          DEFAULT '',

        doctor_photo_path TEXT,

        hospital_photo_path TEXT,

        created_at TEXT NOT NULL,

        updated_at TEXT NOT NULL
      )
    ''');
  }

  // =====================================
  // TABLE 2 - MEDICAL VISITS
  // =====================================

  Future<void> _createVisitsTable(
      Database db,
      ) async {
    await db.execute('''
      CREATE TABLE $visitsTable (
        id TEXT PRIMARY KEY NOT NULL,

        doctor_id TEXT NOT NULL,

        hospital_name TEXT NOT NULL
          DEFAULT '',

        hospital_address TEXT NOT NULL
          DEFAULT '',

        latitude REAL,

        longitude REAL,

        visit_date TEXT NOT NULL,

        visit_time TEXT NOT NULL,

        reason TEXT NOT NULL,

        symptoms TEXT NOT NULL
          DEFAULT '',

        diagnosis TEXT NOT NULL
          DEFAULT '',

        notes TEXT NOT NULL
          DEFAULT '',

        follow_up_date TEXT,

        prescription_type TEXT NOT NULL
          DEFAULT 'Not provided',

        prescription_notes TEXT NOT NULL
          DEFAULT '',

        created_at TEXT NOT NULL,

        updated_at TEXT NOT NULL,

        FOREIGN KEY (doctor_id)
          REFERENCES $doctorsTable(id)
          ON DELETE RESTRICT
      )
    ''');
  }

  // =====================================
  // TABLE 3 - MEDICINES
  // =====================================

  Future<void> _createMedicinesTable(
      Database db,
      ) async {
    await db.execute('''
      CREATE TABLE $medicinesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        visit_id TEXT NOT NULL,

        name TEXT NOT NULL,

        dose TEXT NOT NULL,

        frequency TEXT NOT NULL,

        duration_days INTEGER NOT NULL
          CHECK (duration_days > 0),

        meal_timing TEXT NOT NULL,

        instructions TEXT NOT NULL
          DEFAULT '',

        FOREIGN KEY (visit_id)
          REFERENCES $visitsTable(id)
          ON DELETE CASCADE
      )
    ''');
  }

  // =====================================
  // TABLE 4 - MEDICAL TESTS
  // =====================================

  Future<void> _createTestsTable(
      Database db,
      ) async {
    await db.execute('''
      CREATE TABLE $testsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        visit_id TEXT NOT NULL,

        name TEXT NOT NULL,

        status TEXT NOT NULL,

        test_date TEXT,

        result_notes TEXT NOT NULL
          DEFAULT '',

        UNIQUE (id, visit_id),

        FOREIGN KEY (visit_id)
          REFERENCES $visitsTable(id)
          ON DELETE CASCADE
      )
    ''');
  }

  // =====================================
  // TABLE 5 - ATTACHMENTS
  // =====================================

  Future<void> _createAttachmentsTable(
      Database db,
      ) async {
    await db.execute('''
      CREATE TABLE $attachmentsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        visit_id TEXT NOT NULL,

        test_id INTEGER,

        attachment_kind TEXT NOT NULL
          CHECK (
            attachment_kind IN (
              'prescription',
              'test_report'
            )
          ),

        file_name TEXT NOT NULL,

        file_path TEXT NOT NULL,

        file_type TEXT NOT NULL
          CHECK (
            file_type IN ('image', 'pdf')
          ),

        created_at TEXT NOT NULL,

        CHECK (
          (
            attachment_kind = 'prescription'
            AND test_id IS NULL
          )
          OR
          (
            attachment_kind = 'test_report'
            AND test_id IS NOT NULL
          )
        ),

        FOREIGN KEY (visit_id)
          REFERENCES $visitsTable(id)
          ON DELETE CASCADE,

        FOREIGN KEY (test_id, visit_id)
          REFERENCES $testsTable(id, visit_id)
          ON DELETE CASCADE
      )
    ''');
  }

  // =====================================
  // CREATE DATABASE INDEXES
  // =====================================

  Future<void> _createIndexes(
      Database db,
      ) async {
    // Visits for one doctor.
    await db.execute('''
      CREATE INDEX idx_visits_doctor_date
      ON $visitsTable (
        doctor_id,
        visit_date DESC
      )
    ''');

    // Upcoming follow-up dates.
    await db.execute('''
      CREATE INDEX idx_visits_follow_up
      ON $visitsTable (
        follow_up_date
      )
    ''');

    // Medicines for one visit.
    await db.execute('''
      CREATE INDEX idx_medicines_visit
      ON $medicinesTable (
        visit_id
      )
    ''');

    // Tests for one visit.
    await db.execute('''
      CREATE INDEX idx_tests_visit
      ON $testsTable (
        visit_id
      )
    ''');

    // Attachments for one visit.
    await db.execute('''
      CREATE INDEX idx_attachments_visit
      ON $attachmentsTable (
        visit_id
      )
    ''');

    // Test report attachments.
    await db.execute('''
      CREATE INDEX idx_attachments_test
      ON $attachmentsTable (
        test_id,
        visit_id
      )
    ''');
  }

  // =====================================
  // DATABASE VERSION UPGRADE
  // =====================================

  Future<void> _onUpgrade(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {
    // Never drop existing tables during
    // an unimplemented upgrade.

    throw StateError(
      'Database upgrade from version '
          '$oldVersion to $newVersion '
          'has not been implemented.',
    );
  }

  // =====================================
  // GET DATABASE TABLE NAMES
  // =====================================

  Future<List<String>> getTableNames() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%'
      ORDER BY name
    ''');

    return result.map((row) {
      return row['name'].toString();
    }).toList();
  }

  // =====================================
  // VERIFY FOREIGN KEY STATUS
  // =====================================

  Future<bool> areForeignKeysEnabled() async {
    final db = await database;

    final result = await db.rawQuery(
      'PRAGMA foreign_keys',
    );

    if (result.isEmpty) {
      return false;
    }

    return result.first.values.first == 1;
  }
}

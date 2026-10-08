import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../data/app_database.dart';

// ============================================
// MEDICAL BACKUP RESTORE RESULT
// ============================================

class MedicalBackupRestoreResult {
  final int doctorsAdded;
  final int visitsAdded;
  final int medicinesAdded;
  final int testsAdded;
  final int existingVisitsSkipped;

  const MedicalBackupRestoreResult({
    required this.doctorsAdded,
    required this.visitsAdded,
    required this.medicinesAdded,
    required this.testsAdded,
    required this.existingVisitsSkipped,
  });
}

// ============================================
// MEDICAL BACKUP REPOSITORY
// ============================================

class MedicalBackupRepository {
  MedicalBackupRepository._();

  static final MedicalBackupRepository instance = MedicalBackupRepository._();

  static const int maxItemsPerTable = 100000;

  static const Map<String, List<String>> _allowedColumns = {
    AppDatabase.doctorsTable: [
      'id',
      'name',
      'specialization',
      'phone',
      'hospital_name',
      'doctor_photo_path',
      'hospital_photo_path',
      'created_at',
      'updated_at',
    ],
    AppDatabase.visitsTable: [
      'id',
      'doctor_id',
      'hospital_name',
      'hospital_address',
      'latitude',
      'longitude',
      'visit_date',
      'visit_time',
      'reason',
      'symptoms',
      'diagnosis',
      'notes',
      'follow_up_date',
      'prescription_type',
      'prescription_notes',
      'created_at',
      'updated_at',
    ],
    AppDatabase.medicinesTable: [
      'id',
      'visit_id',
      'name',
      'dose',
      'frequency',
      'duration_days',
      'meal_timing',
      'instructions',
    ],
    AppDatabase.testsTable: [
      'id',
      'visit_id',
      'name',
      'status',
      'test_date',
      'result_notes',
    ],
  };

  // ========================================
  // ACCOUNT CHECKS
  // ========================================

  String _accountHash(String googleUserId) {
    return sha256.convert(utf8.encode(googleUserId)).toString();
  }

  void _checkSession(int generation) {
    if (!AppDatabase.instance.isSessionCurrent(generation)) {
      throw StateError(
        'The Google account session changed. '
        'Operation stopped.',
      );
    }
  }

  // ========================================
  // EXPORT RECORDS
  // ========================================

  Future<Map<String, Object?>> exportDocument(String googleUserId) async {
    final generation = AppDatabase.instance.sessionGeneration;

    _checkSession(generation);

    final db = await AppDatabase.instance.database;

    _checkSession(generation);

    final tables = await db.transaction<Map<String, Object?>>((txn) async {
      // Portable v1 does not support
      // external PDF/image attachments.

      final attachments = await txn.query(
        AppDatabase.attachmentsTable,
        columns: ['id'],
        limit: 1,
      );

      _checkSession(generation);

      if (attachments.isNotEmpty) {
        throw StateError(
          'This account contains file '
          'attachments. Encrypted attachment '
          'export is not implemented yet. '
          'No incomplete backup was created.',
        );
      }

      final result = <String, Object?>{};

      // Read a consistent snapshot.
      for (final table in _allowedColumns.keys) {
        result[table] = await txn.query(table);

        _checkSession(generation);
      }

      final doctorRows =
          result[AppDatabase.doctorsTable] as List<Map<String, Object?>>;

      if (doctorRows.any(
        (row) =>
            row['doctor_photo_path'] != null ||
            row['hospital_photo_path'] != null,
      )) {
        throw StateError(
          'Doctor or hospital photos exist. '
          'Portable backup requires '
          'encrypted attachment support.',
        );
      }

      return result;
    });

    _checkSession(generation);

    return <String, Object?>{
      'format': 'my-medical-history-records',
      'schemaVersion': AppDatabase.databaseVersion,
      'accountHash': _accountHash(googleUserId),
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'attachmentsIncluded': false,
      'tables': tables,
    };
  }

  // ========================================
  // VALIDATE BACKUP ROWS
  // ========================================

  List<Map<String, Object?>> _parseRows(Object? value, String table) {
    if (value is! List || value.length > maxItemsPerTable) {
      throw const FormatException(
        'Backup contains an invalid '
        'or oversized table.',
      );
    }

    final columns = _allowedColumns[table]!;

    final result = <Map<String, Object?>>[];

    for (final entry in value) {
      if (entry is! Map) {
        throw const FormatException('Invalid backup row.');
      }

      final row = <String, Object?>{};

      for (final key in columns) {
        if (entry.containsKey(key)) {
          final cell = entry[key];

          if (cell != null && cell is! String && cell is! num) {
            throw const FormatException('Invalid backup cell.');
          }

          row[key] = cell;
        }
      }

      if (row.isEmpty) {
        throw const FormatException('Empty backup row.');
      }

      result.add(row);
    }

    return result;
  }

  static String _requiredId(Map<String, Object?> row, String field) {
    final id = row[field];

    if (id is! String || id.trim().isEmpty || id.length > 256) {
      throw const FormatException('Backup contains an invalid record ID.');
    }

    return id;
  }

  // ========================================
  // RESTORE MISSING RECORDS
  // ========================================

  Future<MedicalBackupRestoreResult> mergeDocument(
    Map<String, dynamic> document,
    String googleUserId,
  ) async {
    final generation = AppDatabase.instance.sessionGeneration;

    _checkSession(generation);

    if (document['format'] != 'my-medical-history-records' ||
        document['schemaVersion'] != AppDatabase.databaseVersion ||
        document['accountHash'] != _accountHash(googleUserId) ||
        document['attachmentsIncluded'] != false) {
      throw const FormatException(
        'Backup version or Google account '
        'does not match this medical account.',
      );
    }

    final tableData = document['tables'];

    if (tableData is! Map) {
      throw const FormatException('Backup tables are missing.');
    }

    final doctors = _parseRows(
      tableData[AppDatabase.doctorsTable],
      AppDatabase.doctorsTable,
    );

    final visits = _parseRows(
      tableData[AppDatabase.visitsTable],
      AppDatabase.visitsTable,
    );

    final medicines = _parseRows(
      tableData[AppDatabase.medicinesTable],
      AppDatabase.medicinesTable,
    );

    final tests = _parseRows(
      tableData[AppDatabase.testsTable],
      AppDatabase.testsTable,
    );

    // ======================================
    // CHECK DOCTOR IDS
    // ======================================

    final doctorIds = <String>{};

    for (final row in doctors) {
      if (!doctorIds.add(_requiredId(row, 'id'))) {
        throw const FormatException('Duplicate doctor IDs in backup.');
      }

      if (row['doctor_photo_path'] != null ||
          row['hospital_photo_path'] != null) {
        throw const FormatException(
          'Doctor photos require encrypted '
          'attachment support first.',
        );
      }
    }

    // ======================================
    // CHECK VISIT IDS
    // ======================================

    final visitIds = <String>{};

    for (final row in visits) {
      if (!visitIds.add(_requiredId(row, 'id'))) {
        throw const FormatException('Duplicate visit IDs in backup.');
      }

      if (!doctorIds.contains(_requiredId(row, 'doctor_id'))) {
        throw const FormatException('Backup references an absent doctor.');
      }
    }

    // ======================================
    // CHECK MEDICINE / TEST REFERENCES
    // ======================================

    for (final row in [...medicines, ...tests]) {
      if (!visitIds.contains(_requiredId(row, 'visit_id'))) {
        throw const FormatException('Backup references an absent visit.');
      }
    }

    final db = await AppDatabase.instance.database;

    _checkSession(generation);

    // ======================================
    // ATOMIC RESTORE
    // ======================================

    final summary = await db.transaction<MedicalBackupRestoreResult>((
      txn,
    ) async {
      _checkSession(generation);

      var doctorsAdded = 0;
      var visitsAdded = 0;
      var medicinesAdded = 0;
      var testsAdded = 0;
      var existingVisitsSkipped = 0;

      final newlyAddedVisits = <String>{};

      // ==================================
      // RESTORE DOCTORS
      // ==================================

      for (final row in doctors) {
        _checkSession(generation);

        final id = row['id'] as String;

        final previous = await txn.query(
          AppDatabase.doctorsTable,
          columns: ['id', 'name'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        _checkSession(generation);

        if (previous.isNotEmpty) {
          if (previous.first['name'] != row['name']) {
            throw const FormatException(
              'Backup doctor conflicts '
              'with an existing doctor ID.',
            );
          }
          continue;
        }

        await txn.insert(
          AppDatabase.doctorsTable,
          row,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        doctorsAdded++;
      }

      // ==================================
      // RESTORE VISITS
      // ==================================

      for (final row in visits) {
        _checkSession(generation);

        final id = row['id'] as String;

        final previous = await txn.query(
          AppDatabase.visitsTable,
          columns: ['id', 'doctor_id', 'visit_date'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        _checkSession(generation);

        if (previous.isNotEmpty) {
          if (previous.first['doctor_id'] != row['doctor_id'] ||
              previous.first['visit_date'] != row['visit_date']) {
            throw const FormatException(
              'Backup visit conflicts '
              'with an existing visit ID.',
            );
          }

          existingVisitsSkipped++;
          continue;
        }

        await txn.insert(
          AppDatabase.visitsTable,
          row,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        newlyAddedVisits.add(id);

        visitsAdded++;
      }

      // ==================================
      // RESTORE MEDICINES
      // ==================================

      for (final row in medicines) {
        _checkSession(generation);

        if (!newlyAddedVisits.contains(row['visit_id'])) {
          continue;
        }

        // AUTOINCREMENT IDs are local
        // to the device and are not copied.

        final copy = Map<String, Object?>.from(row)..remove('id');

        await txn.insert(
          AppDatabase.medicinesTable,
          copy,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        medicinesAdded++;
      }

      // ==================================
      // RESTORE MEDICAL TESTS
      // ==================================

      for (final row in tests) {
        _checkSession(generation);

        if (!newlyAddedVisits.contains(row['visit_id'])) {
          continue;
        }

        final copy = Map<String, Object?>.from(row)..remove('id');

        await txn.insert(
          AppDatabase.testsTable,
          copy,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        testsAdded++;
      }

      _checkSession(generation);

      // ==================================
      // VERIFY RELATIONSHIPS
      // ==================================

      final fkProblems = await txn.rawQuery('PRAGMA foreign_key_check');

      if (fkProblems.isNotEmpty) {
        throw StateError(
          'Backup restore failed '
          'foreign-key verification.',
        );
      }

      _checkSession(generation);

      return MedicalBackupRestoreResult(
        doctorsAdded: doctorsAdded,
        visitsAdded: visitsAdded,
        medicinesAdded: medicinesAdded,
        testsAdded: testsAdded,
        existingVisitsSkipped: existingVisitsSkipped,
      );
    });

    _checkSession(generation);

    return summary;
  }
}

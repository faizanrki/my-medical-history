
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../data/app_database.dart';

// ============================================
// MY MEDICAL HISTORY
// STEP 44.9 - SECURE DATABASE READ SERVICE
// ============================================
//
// FEATURES:
//
// 1. Read saved doctors.
// 2. Read saved medical visits.
// 3. Read medicines and tests.
// 4. Read complete visit details.
// 5. Read Dashboard and Reports counts.
// 6. Reject results if the account changes.
//
// All database operations require an active
// account-specific storage session.
//
// ============================================

// ============================================
// SAVED DOCTOR RECORD
// ============================================

class SavedDoctorRecord {
  final String id;
  final String name;
  final String specialization;
  final String phone;
  final String hospitalName;

  final int visitCount;
  final String? lastVisitDate;

  const SavedDoctorRecord({
    required this.id,
    required this.name,
    required this.specialization,
    required this.phone,
    required this.hospitalName,
    required this.visitCount,
    required this.lastVisitDate,
  });

  factory SavedDoctorRecord.fromMap(
      Map<String, Object?> map,
      ) {
    return SavedDoctorRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      specialization:
      map['specialization'] as String,
      phone: map['phone'] as String,
      hospitalName:
      map['hospital_name'] as String,
      visitCount:
      (map['visit_count'] as num).toInt(),
      lastVisitDate:
      map['last_visit_date'] as String?,
    );
  }
}

// ============================================
// SAVED VISIT SUMMARY
// ============================================

class SavedVisitSummary {
  final String id;
  final String doctorId;
  final String doctorName;
  final String hospitalName;

  final String visitDate;
  final String visitTime;

  final String reason;
  final String diagnosis;

  final String? followUpDate;
  final String createdAt;

  const SavedVisitSummary({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.hospitalName,
    required this.visitDate,
    required this.visitTime,
    required this.reason,
    required this.diagnosis,
    required this.followUpDate,
    required this.createdAt,
  });

  factory SavedVisitSummary.fromMap(
      Map<String, Object?> map,
      ) {
    return SavedVisitSummary(
      id: map['id'] as String,
      doctorId: map['doctor_id'] as String,
      doctorName:
      map['doctor_name'] as String,
      hospitalName:
      map['hospital_name'] as String,
      visitDate:
      map['visit_date'] as String,
      visitTime:
      map['visit_time'] as String,
      reason: map['reason'] as String,
      diagnosis:
      map['diagnosis'] as String,
      followUpDate:
      map['follow_up_date'] as String?,
      createdAt:
      map['created_at'] as String,
    );
  }
}

// ============================================
// SAVED MEDICINE RECORD
// ============================================

class SavedMedicineRecord {
  final int id;
  final String visitId;

  final String name;
  final String dose;
  final String frequency;

  final int durationDays;

  final String mealTiming;
  final String instructions;

  const SavedMedicineRecord({
    required this.id,
    required this.visitId,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.durationDays,
    required this.mealTiming,
    required this.instructions,
  });

  factory SavedMedicineRecord.fromMap(
      Map<String, Object?> map,
      ) {
    return SavedMedicineRecord(
      id: (map['id'] as num).toInt(),
      visitId:
      map['visit_id'] as String,
      name: map['name'] as String,
      dose: map['dose'] as String,
      frequency:
      map['frequency'] as String,
      durationDays:
      (map['duration_days'] as num).toInt(),
      mealTiming:
      map['meal_timing'] as String,
      instructions:
      map['instructions'] as String,
    );
  }
}

// ============================================
// SAVED MEDICAL TEST RECORD
// ============================================

class SavedMedicalTestRecord {
  final int id;
  final String visitId;

  final String name;
  final String status;

  final String? testDate;
  final String resultNotes;

  const SavedMedicalTestRecord({
    required this.id,
    required this.visitId,
    required this.name,
    required this.status,
    required this.testDate,
    required this.resultNotes,
  });

  factory SavedMedicalTestRecord.fromMap(
      Map<String, Object?> map,
      ) {
    return SavedMedicalTestRecord(
      id: (map['id'] as num).toInt(),
      visitId:
      map['visit_id'] as String,
      name: map['name'] as String,
      status: map['status'] as String,
      testDate:
      map['test_date'] as String?,
      resultNotes:
      map['result_notes'] as String,
    );
  }
}

// ============================================
// COMPLETE SAVED MEDICAL VISIT
// ============================================

class SavedVisitDetails {
  final SavedVisitSummary summary;

  final String doctorSpecialization;
  final String doctorPhone;

  final String hospitalAddress;

  final double? latitude;
  final double? longitude;

  final String symptoms;
  final String notes;

  final String prescriptionType;
  final String prescriptionNotes;

  final List<SavedMedicineRecord> medicines;
  final List<SavedMedicalTestRecord> tests;

  const SavedVisitDetails({
    required this.summary,
    required this.doctorSpecialization,
    required this.doctorPhone,
    required this.hospitalAddress,
    required this.latitude,
    required this.longitude,
    required this.symptoms,
    required this.notes,
    required this.prescriptionType,
    required this.prescriptionNotes,
    required this.medicines,
    required this.tests,
  });

  factory SavedVisitDetails.fromMap(
      Map<String, Object?> map, {
        required List<SavedMedicineRecord> medicines,
        required List<SavedMedicalTestRecord> tests,
      }) {
    return SavedVisitDetails(
      summary:
      SavedVisitSummary.fromMap(map),

      doctorSpecialization:
      map['doctor_specialization'] as String,

      doctorPhone:
      map['doctor_phone'] as String,

      hospitalAddress:
      map['hospital_address'] as String,

      latitude: map['latitude'] == null
          ? null
          : (map['latitude'] as num).toDouble(),

      longitude: map['longitude'] == null
          ? null
          : (map['longitude'] as num).toDouble(),

      symptoms:
      map['symptoms'] as String,

      notes:
      map['notes'] as String,

      prescriptionType:
      map['prescription_type'] as String,

      prescriptionNotes:
      map['prescription_notes'] as String,

      medicines:
      List.unmodifiable(medicines),

      tests:
      List.unmodifiable(tests),
    );
  }
}

// ============================================
// DATABASE RECORD COUNTS
// ============================================

class MedicalHistoryCounts {
  final int doctors;
  final int visits;
  final int medicines;
  final int tests;

  const MedicalHistoryCounts({
    required this.doctors,
    required this.visits,
    required this.medicines,
    required this.tests,
  });
}

// ============================================
// MEDICAL HISTORY READ SERVICE
// ============================================

class MedicalHistoryReadService {
  // ========================================
  // SINGLETON
  // ========================================

  MedicalHistoryReadService._();

  static final MedicalHistoryReadService instance =
  MedicalHistoryReadService._();

  // ========================================
  // COMMON VISIT QUERY
  // ========================================

  static const String _visitQuery = '''
    SELECT
      v.*,
      d.name AS doctor_name,
      d.specialization AS doctor_specialization,
      d.phone AS doctor_phone

    FROM ${AppDatabase.visitsTable} v

    INNER JOIN ${AppDatabase.doctorsTable} d
      ON d.id = v.doctor_id
  ''';

  // ========================================
  // ACCOUNT SESSION VERIFICATION
  // ========================================

  void _verifySession(int generation) {
    if (!AppDatabase.instance
        .isSessionCurrent(generation)) {
      throw StateError(
        'Your medical database session '
            'has changed or is locked. '
            'Please sign in again.',
      );
    }
  }

  // ========================================
  // SECURE DATABASE READ WRAPPER
  // ========================================

  Future<T> _readFromCurrentAccount<T>(
      Future<T> Function(Database db) operation,
      ) async {
    final storage = AppDatabase.instance;

    // =====================================
    // CAPTURE CURRENT SESSION
    // =====================================

    // Capture the session BEFORE any await.
    //
    // This allows us to detect account
    // changes that happen while waiting
    // for the database to open.

    final generation =
        storage.sessionGeneration;

    // =====================================
    // CHECK BEFORE DATABASE ACCESS
    // =====================================

    _verifySession(generation);

    // =====================================
    // GET SELECTED ENCRYPTED DATABASE
    // =====================================

    final db = await storage.database;

    // =====================================
    // CHECK AFTER DATABASE OPENING
    // =====================================

    _verifySession(generation);

    // =====================================
    // EXECUTE DATABASE QUERY
    // =====================================

    final result = await operation(db);

    // =====================================
    // CHECK AFTER DATABASE QUERY
    // =====================================

    // Do not return results from a query
    // if the user switched Google accounts
    // or signed out while it was running.

    _verifySession(generation);

    return result;
  }

  // ========================================
  // VALIDATE PAGINATION
  // ========================================

  void _validatePagination({
    required int limit,
    required int offset,
  }) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError(
        'Limit must be between 1 and 200.',
      );
    }

    if (offset < 0) {
      throw ArgumentError(
        'Offset cannot be negative.',
      );
    }
  }

  // ========================================
  // 1. READ ALL SAVED DOCTORS
  // ========================================

  Future<List<SavedDoctorRecord>>
  getDoctors() async {
    return _readFromCurrentAccount(
          (db) async {
        // Count visits for every doctor.
        // Doctors without visits receive 0.

        final rows = await db.rawQuery('''
          SELECT
            d.id,
            d.name,
            d.specialization,
            d.phone,
            d.hospital_name,

            COUNT(v.id) AS visit_count,
            MAX(v.visit_date) AS last_visit_date

          FROM ${AppDatabase.doctorsTable} d

          LEFT JOIN ${AppDatabase.visitsTable} v
            ON v.doctor_id = d.id

          GROUP BY d.id

          ORDER BY d.name COLLATE NOCASE ASC
        ''');

        return rows
            .map(SavedDoctorRecord.fromMap)
            .toList();
      },
    );
  }

  // ========================================
  // 2. READ DOCTOR BY ID
  // ========================================

  Future<SavedDoctorRecord?> getDoctorById(
      String doctorId,
      ) async {
    final id = doctorId.trim();

    if (id.isEmpty) {
      throw ArgumentError(
        'Doctor ID cannot be empty.',
      );
    }

    return _readFromCurrentAccount(
          (db) async {
        // Parameterized query prevents
        // the ID being inserted as SQL.

        final rows = await db.rawQuery('''
          SELECT
            d.id,
            d.name,
            d.specialization,
            d.phone,
            d.hospital_name,

            COUNT(v.id) AS visit_count,
            MAX(v.visit_date) AS last_visit_date

          FROM ${AppDatabase.doctorsTable} d

          LEFT JOIN ${AppDatabase.visitsTable} v
            ON v.doctor_id = d.id

          WHERE d.id = ?

          GROUP BY d.id

          LIMIT 1
        ''', [id]);

        if (rows.isEmpty) {
          return null;
        }

        return SavedDoctorRecord.fromMap(
          rows.first,
        );
      },
    );
  }

  // ========================================
  // 3. READ ALL SAVED VISITS
  // ========================================

  Future<List<SavedVisitSummary>>
  getAllVisits({
    int limit = 50,
    int offset = 0,
  }) async {
    _validatePagination(
      limit: limit,
      offset: offset,
    );

    return _readFromCurrentAccount(
          (db) async {
        final rows = await db.rawQuery('''
          $_visitQuery

          ORDER BY
            v.visit_date DESC,
            v.visit_time DESC,
            v.created_at DESC,
            v.id DESC

          LIMIT ? OFFSET ?
        ''', [limit, offset]);

        return rows
            .map(SavedVisitSummary.fromMap)
            .toList();
      },
    );
  }

  // ========================================
  // 4. READ VISITS FOR ONE DOCTOR
  // ========================================

  Future<List<SavedVisitSummary>>
  getVisitsByDoctor(
      String doctorId, {
        int limit = 50,
        int offset = 0,
      }) async {
    final id = doctorId.trim();

    if (id.isEmpty) {
      throw ArgumentError(
        'Doctor ID cannot be empty.',
      );
    }

    _validatePagination(
      limit: limit,
      offset: offset,
    );

    return _readFromCurrentAccount(
          (db) async {
        final rows = await db.rawQuery('''
          $_visitQuery

          WHERE v.doctor_id = ?

          ORDER BY
            v.visit_date DESC,
            v.visit_time DESC,
            v.created_at DESC,
            v.id DESC

          LIMIT ? OFFSET ?
        ''', [id, limit, offset]);

        return rows
            .map(SavedVisitSummary.fromMap)
            .toList();
      },
    );
  }

  // ========================================
  // 5. READ COMPLETE VISIT DETAILS
  // ========================================

  Future<SavedVisitDetails?> getVisitDetails(
      String visitId,
      ) async {
    final id = visitId.trim();

    if (id.isEmpty) {
      throw ArgumentError(
        'Visit ID cannot be empty.',
      );
    }

    return _readFromCurrentAccount(
          (db) async {
        // One transaction provides
        // a consistent set of visit details,
        // medicines, and medical tests.

        return db.transaction<SavedVisitDetails?>(
              (Transaction txn) async {
            // ==============================
            // READ VISIT AND DOCTOR
            // ==============================

            final visitRows =
            await txn.rawQuery('''
              $_visitQuery

              WHERE v.id = ?

              LIMIT 1
            ''', [id]);

            if (visitRows.isEmpty) {
              return null;
            }

            // ==============================
            // READ SAVED MEDICINES
            // ==============================

            final medicineRows = await txn.query(
              AppDatabase.medicinesTable,
              where: 'visit_id = ?',
              whereArgs: [id],
              orderBy: 'id ASC',
            );

            final medicines = medicineRows
                .map(
              SavedMedicineRecord.fromMap,
            )
                .toList();

            // ==============================
            // READ SAVED MEDICAL TESTS
            // ==============================

            final testRows = await txn.query(
              AppDatabase.testsTable,
              where: 'visit_id = ?',
              whereArgs: [id],
              orderBy: 'id ASC',
            );

            final tests = testRows
                .map(
              SavedMedicalTestRecord.fromMap,
            )
                .toList();

            // ==============================
            // BUILD COMPLETE VISIT OBJECT
            // ==============================

            return SavedVisitDetails.fromMap(
              visitRows.first,
              medicines: medicines,
              tests: tests,
            );
          },
        );
      },
    );
  }

  // ========================================
  // 6. GET DASHBOARD AND REPORT COUNTS
  // ========================================

  Future<MedicalHistoryCounts>
  getHistoryCounts() async {
    return _readFromCurrentAccount(
          (db) async {
        final rows = await db.rawQuery('''
          SELECT
            (
              SELECT COUNT(*)
              FROM ${AppDatabase.doctorsTable}
            ) AS doctors_count,

            (
              SELECT COUNT(*)
              FROM ${AppDatabase.visitsTable}
            ) AS visits_count,

            (
              SELECT COUNT(*)
              FROM ${AppDatabase.medicinesTable}
            ) AS medicines_count,

            (
              SELECT COUNT(*)
              FROM ${AppDatabase.testsTable}
            ) AS tests_count
        ''');

        final row = rows.first;

        return MedicalHistoryCounts(
          doctors:
          (row['doctors_count'] as num).toInt(),
          visits:
          (row['visits_count'] as num).toInt(),
          medicines:
          (row['medicines_count'] as num).toInt(),
          tests:
          (row['tests_count'] as num).toInt(),
        );
      },
    );
  }

  // ========================================
  // 7. CHECK WHETHER VISIT EXISTS
  // ========================================

  Future<bool> visitExists(
      String visitId,
      ) async {
    final id = visitId.trim();

    if (id.isEmpty) {
      return false;
    }

    return _readFromCurrentAccount(
          (db) async {
        final rows = await db.query(
          AppDatabase.visitsTable,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        return rows.isNotEmpty;
      },
    );
  }
}

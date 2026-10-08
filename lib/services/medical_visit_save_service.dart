
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../data/app_database.dart';
import '../models/visit_draft.dart';

// ============================================
// MY MEDICAL HISTORY
// STEP 44.12 - SECURE MEDICAL VISIT SAVE
// ============================================
//
// FEATURES:
//
// 1. Google account session protection.
// 2. Account-bound medical visit drafts.
// 3. Draft verification for Steps 1–7.
// 4. Duplicate save prevention.
// 5. Secure random doctor and visit IDs.
// 6. Doctor and visit validation.
// 7. Medicine and test validation.
// 8. Atomic SQLite transactions.
// 9. Reject expired account sessions.
// 10. Block unencrypted attachments.
//
// Requires AppDatabase from Step 44.8.
//
// ============================================

// ============================================
// SUCCESSFUL SAVE RESULT
// ============================================

class SavedVisitResult {
  final String doctorId;
  final String visitId;
  final bool doctorCreated;
  final int medicineCount;
  final int testCount;

  const SavedVisitResult({
    required this.doctorId,
    required this.visitId,
    required this.doctorCreated,
    required this.medicineCount,
    required this.testCount,
  });
}

// ============================================
// COMPLETED SAVE CACHE
// ============================================

class _CompletedVisitSave {
  final int generation;
  final SavedVisitResult result;

  const _CompletedVisitSave({
    required this.generation,
    required this.result,
  });
}

// ============================================
// PENDING SAVE CACHE
// ============================================

class _PendingVisitSave {
  final int generation;
  final Future<SavedVisitResult> operation;

  const _PendingVisitSave({
    required this.generation,
    required this.operation,
  });
}

// ============================================
// MEDICAL VISIT SAVE SERVICE
// ============================================

class MedicalVisitSaveService {
  // ========================================
  // SINGLETON
  // ========================================

  MedicalVisitSaveService._();

  static final MedicalVisitSaveService instance =
  MedicalVisitSaveService._();

  // ========================================
  // SECURE RANDOM ID GENERATOR
  // ========================================

  static final Random _random = Random.secure();

  // ========================================
  // COMPLETED SAVES
  // ========================================

  final Expando<_CompletedVisitSave> _completed =
  Expando<_CompletedVisitSave>();

  // ========================================
  // PENDING SAVES
  // ========================================

  final Map<VisitDraft, _PendingVisitSave> _pending =
  HashMap<VisitDraft, _PendingVisitSave>.identity();

  // ========================================
  // ACCOUNT-BOUND DRAFT OWNERSHIP
  // ========================================

  // Each visit draft belongs to the
  // account session that created it.

  final Expando<int> _draftSessionOwners =
  Expando<int>(
    'medical_visit_draft_session',
  );

  // ========================================
  // VERIFY CURRENT ACCOUNT SESSION
  // ========================================

  void _verifySession(int generation) {
    final database = AppDatabase.instance;

    if (!database.isSessionCurrent(generation)) {
      throw StateError(
        'Your medical account session has '
            'changed or is locked. Please sign '
            'in again before accessing or '
            'saving medical records.',
      );
    }
  }

  // ========================================
  // BIND NEW DRAFT TO ACCOUNT SESSION
  // ========================================

  // Called by AddVisitScreen when a new
  // VisitDraft is created in Step 1.

  void bindDraftToCurrentSession(
      VisitDraft draft,
      ) {
    final generation =
        AppDatabase.instance.sessionGeneration;

    _verifySession(generation);

    final previous =
    _draftSessionOwners[draft];

    // Prevent reusing a draft from an
    // earlier account session.

    if (previous != null &&
        previous != generation) {
      throw StateError(
        'This medical visit draft belongs '
            'to a previous Google account session. '
            'Please start a new visit.',
      );
    }

    _draftSessionOwners[draft] = generation;
  }

  // ========================================
  // VERIFY DRAFT OWNERSHIP
  // ========================================

  void _verifyDraftOwnership(
      VisitDraft draft,
      int generation,
      ) {
    if (_draftSessionOwners[draft] != generation) {
      throw StateError(
        'This visit draft does not belong '
            'to the current Google account '
            'session. Please open Add Visit '
            'and start a new form.',
      );
    }

    _verifySession(generation);
  }

  // ========================================
  // STEP 44.12 - VERIFY INTERMEDIATE STEPS
  // ========================================

  // IMPORTANT:
  //
  // This method is used by:
  //
  // Step 2 - LocationStepScreen
  // Step 3 - VisitInformationScreen
  // Step 4 - Symptoms / Diagnosis
  // Step 5 - Medicines
  // Step 6 - Medical Tests
  // Step 7 - Final Review
  //
  // It verifies an existing draft.
  // It does NOT bind an unregistered draft.

  void verifyDraftForCurrentSession(
      VisitDraft draft,
      ) {
    final generation =
        AppDatabase.instance.sessionGeneration;

    _verifyDraftOwnership(
      draft,
      generation,
    );
  }

  // ========================================
  // PUBLIC SAVE VISIT METHOD
  // ========================================

  Future<SavedVisitResult> saveVisit(
      VisitDraft draft,
      ) async {
    // ======================================
    // 1. CAPTURE ACTIVE SESSION
    // ======================================

    final generation =
        AppDatabase.instance.sessionGeneration;

    _verifySession(generation);

    // ======================================
    // 2. VERIFY DRAFT OWNER
    // ======================================

    // IMPORTANT:
    // Check ownership before accessing
    // pending or completed save results.

    _verifyDraftOwnership(
      draft,
      generation,
    );

    // ======================================
    // 3. CHECK COMPLETED SAVE
    // ======================================

    final completedSave =
    _completed[draft];

    if (completedSave != null &&
        completedSave.generation == generation) {
      _verifyDraftOwnership(
        draft,
        generation,
      );

      return completedSave.result;
    }

    // ======================================
    // 4. CHECK PENDING SAVE
    // ======================================

    final pendingSave =
    _pending[draft];

    if (pendingSave != null &&
        pendingSave.generation == generation) {
      final result =
      await pendingSave.operation;

      _verifyDraftOwnership(
        draft,
        generation,
      );

      return result;
    }

    // ======================================
    // 5. COPY DRAFT
    // ======================================

    final snapshot = _copyDraft(draft);

    // ======================================
    // 6. START SAVE OPERATION
    // ======================================

    final operation = _saveSnapshot(
      snapshot,
      generation,
    );

    final currentPendingSave =
    _PendingVisitSave(
      generation: generation,
      operation: operation,
    );

    _pending[draft] = currentPendingSave;

    try {
      final result = await operation;

      // ====================================
      // VERIFY SESSION AFTER SAVE
      // ====================================

      _verifyDraftOwnership(
        draft,
        generation,
      );

      // ====================================
      // REMEMBER SUCCESSFUL SAVE
      // ====================================

      _completed[draft] =
          _CompletedVisitSave(
            generation: generation,
            result: result,
          );

      return result;
    } finally {
      // ====================================
      // REMOVE PENDING OPERATION
      // ====================================

      // Remove only this operation.
      // Do not remove a newer operation
      // from a different session.

      if (identical(
        _pending[draft],
        currentPendingSave,
      )) {
        _pending.remove(draft);
      }
    }
  }

  // ========================================
  // COPY VISIT DRAFT
  // ========================================

  VisitDraft _copyDraft(
      VisitDraft source,
      ) {
    return VisitDraft(
      doctorId: source.doctorId,

      doctorName: source.doctorName,

      doctorSpecialization:
      source.doctorSpecialization,

      doctorPhone: source.doctorPhone,

      hospitalName: source.hospitalName,

      doctorPhotoPath:
      source.doctorPhotoPath,

      hospitalPhotoPath:
      source.hospitalPhotoPath,

      hospitalAddress:
      source.hospitalAddress,

      latitude: source.latitude,

      longitude: source.longitude,

      visitDate: source.visitDate,

      visitTime: source.visitTime,

      reason: source.reason,

      symptoms: source.symptoms,

      diagnosis: source.diagnosis,

      notes: source.notes,

      followUpDate: source.followUpDate,

      medicines: List<MedicineDraft>.of(
        source.medicines,
      ),

      tests: List<MedicalTestDraft>.of(
        source.tests,
      ),

      prescriptionType:
      source.prescriptionType,

      prescriptionNotes:
      source.prescriptionNotes,

      prescriptionAttachments:
      List<MedicalAttachmentDraft>.of(
        source.prescriptionAttachments,
      ),
    );
  }

  // ========================================
  // GENERATE SECURE RANDOM ID
  // ========================================

  String _newId(String prefix) {
    final bytes = List<int>.generate(
      16,
          (_) => _random.nextInt(256),
    );

    final randomText =
    base64UrlEncode(bytes).replaceAll('=', '');

    return '${prefix}_$randomText';
  }

  // ========================================
  // FORMAT DATE FOR SQLITE
  // ========================================

  String _formatDate(DateTime date) {
    final year =
    date.year.toString().padLeft(4, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    final day =
    date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ========================================
  // FORMAT TIME FOR SQLITE
  // ========================================

  String _formatTime(
      int hour,
      int minute,
      ) {
    final h =
    hour.toString().padLeft(2, '0');

    final m =
    minute.toString().padLeft(2, '0');

    return '$h:$m';
  }

  // ========================================
  // VALIDATE MEDICAL VISIT DRAFT
  // ========================================

  void _validateDraft(
      VisitDraft draft,
      ) {
    // ======================================
    // REQUIRED VISIT INFORMATION
    // ======================================

    if (!draft.hasRequiredVisitInformation) {
      throw const FormatException(
        'Please complete the doctor, '
            'hospital, address, visit date, '
            'visit time, and reason for visit.',
      );
    }

    // ======================================
    // DOCTOR DETAILS
    // ======================================

    if (draft.doctorId == null) {
      // New doctor requires specialization
      // and phone number.

      if (draft.doctorSpecialization
          .trim()
          .isEmpty ||
          draft.doctorPhone
              .trim()
              .isEmpty) {
        throw const FormatException(
          'Please complete the new doctor '
              'specialization and phone number.',
        );
      }
    } else if (
    draft.doctorId!.trim().isEmpty) {
      throw const FormatException(
        'The selected doctor ID is invalid.',
      );
    }

    // ======================================
    // FOLLOW-UP DATE
    // ======================================

    final followUp =
        draft.followUpDate;

    final visitDate =
    draft.visitDate!;

    if (followUp != null &&
        _formatDate(followUp)
            .compareTo(
          _formatDate(visitDate),
        ) <
            0) {
      throw const FormatException(
        'Follow-up date cannot be '
            'before the visit date.',
      );
    }

    // ======================================
    // MEDICINE VALIDATION
    // ======================================

    for (final medicine in draft.medicines) {
      if (medicine.name.trim().isEmpty ||
          medicine.dose.trim().isEmpty ||
          medicine.frequency.trim().isEmpty ||
          medicine.mealTiming.trim().isEmpty ||
          medicine.durationDays <= 0) {
        throw const FormatException(
          'One or more medicines have '
              'incomplete or invalid details.',
        );
      }
    }

    // ======================================
    // MEDICAL TEST VALIDATION
    // ======================================

    for (final test in draft.tests) {
      if (test.name.trim().isEmpty ||
          test.status.trim().isEmpty) {
        throw const FormatException(
          'One or more medical tests '
              'have incomplete details.',
        );
      }
    }

    // ======================================
    // BLOCK UNENCRYPTED ATTACHMENTS
    // ======================================

    // SQLCipher encrypts SQLite database
    // contents, not external PDF/image files.
    //
    // Block attachments until encrypted
    // file storage is implemented.

    final hasPrescriptionAttachments =
        draft.prescriptionAttachments.isNotEmpty;

    final hasTestAttachments =
    draft.tests.any(
          (test) =>
      test.reportAttachment != null,
    );

    if (hasPrescriptionAttachments ||
        hasTestAttachments) {
      throw UnsupportedError(
        'Encrypted attachment storage '
            'is not implemented yet. '
            'No medical visit was saved.',
      );
    }

    // ======================================
    // DOCTOR AND HOSPITAL PHOTOS
    // ======================================

    final hasDoctorPhoto =
        draft.doctorPhotoPath
            ?.trim()
            .isNotEmpty ??
            false;

    final hasHospitalPhoto =
        draft.hospitalPhotoPath
            ?.trim()
            .isNotEmpty ??
            false;

    if (hasDoctorPhoto ||
        hasHospitalPhoto) {
      throw UnsupportedError(
        'Secure doctor and hospital photo '
            'storage is not implemented yet.',
      );
    }
  }

  // ========================================
  // SAVE COMPLETE MEDICAL VISIT
  // ========================================

  Future<SavedVisitResult> _saveSnapshot(
      VisitDraft draft,
      int generation,
      ) async {
    // ======================================
    // 1. VERIFY ACCOUNT SESSION
    // ======================================

    _verifySession(generation);

    // ======================================
    // 2. VALIDATE VISIT
    // ======================================

    _validateDraft(draft);

    _verifySession(generation);

    // ======================================
    // 3. OPEN ENCRYPTED ACCOUNT DATABASE
    // ======================================

    final database =
    await AppDatabase.instance.database;

    _verifySession(generation);

    // ======================================
    // 4. GENERATE VISIT ID
    // ======================================

    final visitId =
    _newId('visit');

    final now =
    DateTime.now()
        .toUtc()
        .toIso8601String();

    // ======================================
    // 5. START SQLITE TRANSACTION
    // ======================================

    final result =
    await database.transaction<SavedVisitResult>(
          (Transaction txn) async {
        _verifySession(generation);

        // ==================================
        // FIND OR CREATE DOCTOR
        // ==================================

        final existingDoctorId =
        draft.doctorId?.trim();

        final doctorId =
            existingDoctorId ??
                _newId('doctor');

        final doctorCreated =
            existingDoctorId == null;

        // ==================================
        // CHECK EXISTING DOCTOR
        // ==================================

        if (!doctorCreated) {
          final existingDoctors =
          await txn.query(
            AppDatabase.doctorsTable,

            columns: ['id', 'name'],

            where: 'id = ?',

            whereArgs: [doctorId],

            limit: 1,
          );

          _verifySession(generation);

          if (existingDoctors.isEmpty) {
            throw StateError(
              'Selected doctor was not found. '
                  'Please select the doctor again.',
            );
          }

          final storedName =
          (existingDoctors.first['name'] ??
              '')
              .toString()
              .trim()
              .toLowerCase();

          final selectedName =
          draft.doctorName
              .trim()
              .toLowerCase();

          if (storedName != selectedName) {
            throw StateError(
              'The selected doctor does not '
                  'match the saved doctor profile. '
                  'Please reselect the doctor.',
            );
          }
        } else {
          // ==================================
          // INSERT NEW DOCTOR
          // ==================================

          _verifySession(generation);

          await txn.insert(
            AppDatabase.doctorsTable,
            {
              'id': doctorId,

              'name':
              draft.doctorName.trim(),

              'specialization':
              draft.doctorSpecialization
                  .trim(),

              'phone':
              draft.doctorPhone.trim(),

              'hospital_name':
              draft.hospitalName.trim(),

              'doctor_photo_path': null,

              'hospital_photo_path': null,

              'created_at': now,

              'updated_at': now,
            },
            conflictAlgorithm:
            ConflictAlgorithm.abort,
          );

          _verifySession(generation);
        }

        // ==================================
        // INSERT VISIT
        // ==================================

        _verifySession(generation);

        await txn.insert(
          AppDatabase.visitsTable,
          {
            'id': visitId,

            'doctor_id': doctorId,

            'hospital_name':
            draft.hospitalName.trim(),

            'hospital_address':
            draft.hospitalAddress.trim(),

            'latitude':
            draft.latitude,

            'longitude':
            draft.longitude,

            'visit_date':
            _formatDate(
              draft.visitDate!,
            ),

            'visit_time':
            _formatTime(
              draft.visitTime!.hour,
              draft.visitTime!.minute,
            ),

            'reason':
            draft.reason.trim(),

            'symptoms':
            draft.symptoms.trim(),

            'diagnosis':
            draft.diagnosis.trim(),

            'notes':
            draft.notes.trim(),

            'follow_up_date':
            draft.followUpDate == null
                ? null
                : _formatDate(
              draft.followUpDate!,
            ),

            'prescription_type':
            draft.prescriptionType.trim(),

            'prescription_notes':
            draft.prescriptionNotes.trim(),

            'created_at': now,

            'updated_at': now,
          },
          conflictAlgorithm:
          ConflictAlgorithm.abort,
        );

        _verifySession(generation);

        // ==================================
        // INSERT MEDICINES
        // ==================================

        for (final medicine in draft.medicines) {
          _verifySession(generation);

          await txn.insert(
            AppDatabase.medicinesTable,
            {
              'visit_id':
              visitId,

              'name':
              medicine.name.trim(),

              'dose':
              medicine.dose.trim(),

              'frequency':
              medicine.frequency.trim(),

              'duration_days':
              medicine.durationDays,

              'meal_timing':
              medicine.mealTiming.trim(),

              'instructions':
              medicine.instructions.trim(),
            },
            conflictAlgorithm:
            ConflictAlgorithm.abort,
          );

          _verifySession(generation);
        }

        // ==================================
        // INSERT MEDICAL TESTS
        // ==================================

        for (final test in draft.tests) {
          _verifySession(generation);

          await txn.insert(
            AppDatabase.testsTable,
            {
              'visit_id': visitId,

              'name':
              test.name.trim(),

              'status':
              test.status.trim(),

              'test_date':
              test.testDate == null
                  ? null
                  : _formatDate(
                test.testDate!,
              ),

              'result_notes':
              test.resultNotes.trim(),
            },
            conflictAlgorithm:
            ConflictAlgorithm.abort,
          );

          _verifySession(generation);
        }

        // ==================================
        // VERIFY SESSION BEFORE COMMIT
        // ==================================

        // If the account session changed,
        // throw to request transaction rollback.

        _verifySession(generation);

        // ==================================
        // RETURN SAVED VISIT DETAILS
        // ==================================

        return SavedVisitResult(
          doctorId: doctorId,

          visitId: visitId,

          doctorCreated: doctorCreated,

          medicineCount:
          draft.medicines.length,

          testCount:
          draft.tests.length,
        );
      },
    );

    // ======================================
    // VERIFY ACCOUNT AFTER SAVE
    // ======================================

    // A transaction may already be committed
    // if the session changes at this point.
    // Never claim the data was rolled back
    // solely because this check fails.

    _verifySession(generation);

    return result;
  }
}

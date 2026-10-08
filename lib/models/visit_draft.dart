
import 'package:flutter/material.dart';

// =====================================
// SHARED MEDICAL VISIT DRAFT
// =====================================

// This class stores information for ONE visit
// while the user completes the seven-step form.
//
// It is NOT a saved database record yet.

class VisitDraft {
  // =====================================
  // STEP 1 - DOCTOR INFORMATION
  // =====================================

  // Existing doctor ID.
  // Null means a new doctor is being entered.
  String? doctorId;

  String doctorName;
  String doctorSpecialization;
  String doctorPhone;
  String hospitalName;

  // Photo paths will be used later
  String? doctorPhotoPath;
  String? hospitalPhotoPath;

  // =====================================
  // STEP 2 - HOSPITAL LOCATION
  // =====================================

  String hospitalAddress;

  // GPS coordinates are optional.
  double? latitude;
  double? longitude;

  // =====================================
  // STEP 3 - VISIT INFORMATION
  // =====================================

  DateTime? visitDate;
  TimeOfDay? visitTime;

  String reason;
  String symptoms;
  String diagnosis;
  String notes;

  DateTime? followUpDate;

  // =====================================
  // STEP 4 - MEDICINES
  // =====================================

  // One visit can contain multiple medicines.
  final List<MedicineDraft> medicines;

  // =====================================
  // STEP 5 - MEDICAL TESTS
  // =====================================

  // One visit can contain multiple tests.
  final List<MedicalTestDraft> tests;

  // =====================================
  // STEP 6 - PRESCRIPTION
  // =====================================

  String prescriptionType;
  String prescriptionNotes;

  // Prescription images and PDFs
  final List<MedicalAttachmentDraft>
  prescriptionAttachments;

  // =====================================
  // CONSTRUCTOR
  // =====================================

  VisitDraft({
    this.doctorId,
    this.doctorName = '',
    this.doctorSpecialization = '',
    this.doctorPhone = '',
    this.hospitalName = '',
    this.doctorPhotoPath,
    this.hospitalPhotoPath,
    this.hospitalAddress = '',
    this.latitude,
    this.longitude,
    this.visitDate,
    this.visitTime,
    this.reason = '',
    this.symptoms = '',
    this.diagnosis = '',
    this.notes = '',
    this.followUpDate,
    List<MedicineDraft>? medicines,
    List<MedicalTestDraft>? tests,
    this.prescriptionType = 'Not provided',
    this.prescriptionNotes = '',
    List<MedicalAttachmentDraft>?
    prescriptionAttachments,
  })  : medicines = medicines ?? <MedicineDraft>[],
        tests = tests ?? <MedicalTestDraft>[],
        prescriptionAttachments =
            prescriptionAttachments ??
                <MedicalAttachmentDraft>[];

  // =====================================
  // HELPFUL GETTERS
  // =====================================

  // True when an existing doctor is selected.
  bool get isExistingDoctor {
    return doctorId != null;
  }

  // Check whether basic doctor details exist.
  bool get hasDoctorInformation {
    return doctorName.trim().isNotEmpty &&
        hospitalName.trim().isNotEmpty;
  }

  // Check basic information before review.
  // Individual screens still validate their fields.
  bool get hasRequiredVisitInformation {
    return hasDoctorInformation &&
        hospitalAddress.trim().isNotEmpty &&
        visitDate != null &&
        visitTime != null &&
        reason.trim().isNotEmpty;
  }

  // Total medicine count
  int get medicineCount {
    return medicines.length;
  }

  // Total medical test count
  int get testCount {
    return tests.length;
  }
}

// =====================================
// MEDICINE DRAFT MODEL
// =====================================

// Represents ONE medicine in the current visit.

class MedicineDraft {
  final int id;
  final String name;
  final String dose;
  final String frequency;
  final int durationDays;
  final String mealTiming;
  final String instructions;

  const MedicineDraft({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.durationDays,
    required this.mealTiming,
    required this.instructions,
  });
}

// =====================================
// MEDICAL TEST DRAFT MODEL
// =====================================

// Represents ONE medical test in the visit.

class MedicalTestDraft {
  final int id;
  final String name;
  final String status;
  final DateTime? testDate;
  final String resultNotes;

  // Optional image or PDF report
  final MedicalAttachmentDraft? reportAttachment;

  const MedicalTestDraft({
    required this.id,
    required this.name,
    required this.status,
    this.testDate,
    required this.resultNotes,
    this.reportAttachment,
  });
}

// =====================================
// ATTACHMENT TYPE
// =====================================

enum MedicalAttachmentType {
  image,
  pdf,
}

// =====================================
// MEDICAL ATTACHMENT DRAFT MODEL
// =====================================

// Represents a selected local file.
//
// The file picker and secure storage
// will be implemented in later steps.

class MedicalAttachmentDraft {
  final String fileName;
  final String filePath;
  final MedicalAttachmentType type;

  const MedicalAttachmentDraft({
    required this.fileName,
    required this.filePath,
    required this.type,
  });
}

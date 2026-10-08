
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../models/visit_draft.dart';
import '../../services/medical_visit_save_service.dart';

import 'review_save_screen.dart';

// ============================================
// MY MEDICAL HISTORY
// STEP 44.16 - SECURE PRESCRIPTION SCREEN
// STEP 6 OF 7
// ============================================
//
// FEATURES:
//
// 1. Account-bound shared VisitDraft.
// 2. Google account session verification.
// 3. Prescription type selection.
// 4. Prescription notes.
// 5. Doctor and hospital summary.
// 6. Medicines and tests counts.
// 7. Camera, gallery and PDF placeholders.
// 8. Preserve information when going back.
// 9. Secure navigation to final review.
// 10. Reject expired or unbound drafts.
//
// IMPORTANT:
//
// External prescription attachments are
// not encrypted or stored yet.
//
// Google Drive backup is not implemented.
//
// ============================================

class PrescriptionStepScreen extends StatefulWidget {
  // ========================================
  // EXISTING CONSTRUCTOR PARAMETERS
  // ========================================

  // Preserved for compatibility with
  // MedicalTestsStepScreen.

  final String? doctorId;
  final String doctorName;
  final String hospitalName;

  final String hospitalAddress;

  final DateTime visitDate;
  final TimeOfDay visitTime;

  final String reason;
  final String symptoms;
  final String diagnosis;
  final String notes;

  final DateTime? followUpDate;

  final List<Map<String, Object?>> medicines;
  final List<Map<String, Object?>> tests;

  const PrescriptionStepScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.visitDate,
    required this.visitTime,
    required this.reason,
    required this.symptoms,
    required this.diagnosis,
    required this.notes,
    required this.followUpDate,
    required this.medicines,
    required this.tests,
  });

  @override
  State<PrescriptionStepScreen> createState() =>
      _PrescriptionStepScreenState();
}

class _PrescriptionStepScreenState
    extends State<PrescriptionStepScreen>
    with WidgetsBindingObserver {

  // ========================================
  // SHARED ACCOUNT-BOUND VISIT DRAFT
  // ========================================

  VisitDraft? _draft;

  int? _draftGeneration;

  bool _draftInitialized = false;

  String? _draftError;

  // ========================================
  // MEDICAL VISIT SAVE SERVICE
  // ========================================

  final MedicalVisitSaveService _saveService =
      MedicalVisitSaveService.instance;

  // ========================================
  // PRESCRIPTION FORM
  // ========================================

  final TextEditingController
  _prescriptionNotesController =
  TextEditingController();

  String _prescriptionType = 'Not provided';

  // ========================================
  // PRESCRIPTION TYPE OPTIONS
  // ========================================

  static const List<String> _prescriptionTypes = [
    'Not provided',
    'Paper Prescription',
    'Digital Prescription',
  ];

  // ========================================
  // INITIALIZE SCREEN
  // ========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  // ========================================
  // RECEIVE ORIGINAL SHARED VISIT DRAFT
  // ========================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_draftInitialized) {
      return;
    }

    _draftInitialized = true;

    // ======================================
    // GET ROUTE ARGUMENTS
    // ======================================

    final arguments =
        ModalRoute.of(context)?.settings.arguments;

    // ======================================
    // REQUIRE ORIGINAL VISIT DRAFT
    // ======================================

    // Step 1 creates the original VisitDraft
    // and binds it to a Google account session.
    //
    // Steps 2-7 must use that SAME object.
    //
    // Never create a fallback VisitDraft here.

    if (arguments is! VisitDraft) {
      _draftError =
      'The original medical visit draft '
          'was not received. Please return '
          'to Add Visit and start again.';

      return;
    }

    final generation =
        AppDatabase.instance.sessionGeneration;

    try {
      // ====================================
      // VERIFY ACTIVE ACCOUNT SESSION
      // ====================================

      if (!AppDatabase.instance
          .isSessionCurrent(generation)) {
        throw StateError(
          'Medical storage is locked.',
        );
      }

      // ====================================
      // VERIFY VISIT DRAFT OWNERSHIP
      // ====================================

      // This verifies the original draft.
      // It does not register a new owner.

      _saveService.verifyDraftForCurrentSession(
        arguments,
      );

      // ====================================
      // STORE SHARED DRAFT
      // ====================================

      _draft = arguments;

      _draftGeneration = generation;

      // ====================================
      // RESTORE PRESCRIPTION TYPE
      // ====================================

      if (_prescriptionTypes.contains(
        arguments.prescriptionType,
      )) {
        _prescriptionType =
            arguments.prescriptionType;
      } else {
        _prescriptionType = 'Not provided';
      }

      // ====================================
      // RESTORE PRESCRIPTION NOTES
      // ====================================

      _prescriptionNotesController.text =
          arguments.prescriptionNotes;
    } catch (_) {
      // ====================================
      // REJECT INVALID SESSION
      // ====================================

      _draft = null;

      _draftGeneration = null;

      _draftError =
      'This visit draft belongs to an '
          'expired or different Google account '
          'session. Please start a new visit.';
    }
  }

  // ========================================
  // VERIFY ACCOUNT-BOUND VISIT DRAFT
  // ========================================

  bool get _isCurrentDraft {
    final draft = _draft;

    final generation = _draftGeneration;

    if (draft == null || generation == null) {
      return false;
    }

    // ======================================
    // CHECK ACCOUNT SESSION
    // ======================================

    if (!AppDatabase.instance
        .isSessionCurrent(generation)) {
      return false;
    }

    // ======================================
    // CHECK DRAFT OWNERSHIP
    // ======================================

    try {
      _saveService.verifyDraftForCurrentSession(
        draft,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  // ========================================
  // INVALIDATE EXPIRED VISIT DRAFT
  // ========================================

  void _invalidateDraft() {
    if (!mounted) {
      return;
    }

    // Clear unsaved information held by
    // the current prescription text field.

    _prescriptionNotesController.clear();

    setState(() {
      _draft = null;

      _draftGeneration = null;

      _prescriptionType = 'Not provided';

      _draftError =
      'Your Google account session '
          'has changed. This prescription '
          'form can no longer be continued. '
          'Please start a new visit.';
    });
  }

  // ========================================
  // VERIFY BEFORE FORM ACTION
  // ========================================

  bool _ensureCurrentDraft() {
    if (_isCurrentDraft) {
      return true;
    }

    if (_draft != null) {
      _invalidateDraft();
    }

    return false;
  }

  // ========================================
  // VERIFY AFTER APP RESUMES
  // ========================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _draft != null &&
        !_isCurrentDraft) {
      _invalidateDraft();
    }
  }

  // ========================================
  // DISPOSE CONTROLLERS
  // ========================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _prescriptionNotesController.dispose();

    super.dispose();
  }

  // ========================================
  // SHOW TEMPORARY MESSAGE
  // ========================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    final messenger =
    ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ========================================
  // UPDATE PRESCRIPTION DETAILS IN DRAFT
  // ========================================

  bool _updatePrescriptionDraft() {
    if (!_ensureCurrentDraft()) {
      return false;
    }

    final draft = _draft!;

    draft.prescriptionType =
        _prescriptionType;

    draft.prescriptionNotes =
        _prescriptionNotesController.text.trim();

    return true;
  }

  // ========================================
  // CHANGE PRESCRIPTION TYPE
  // ========================================

  void _onPrescriptionTypeChanged(
      String? value,
      ) {
    if (!_ensureCurrentDraft()) {
      return;
    }

    if (value == null ||
        !_prescriptionTypes.contains(value)) {
      return;
    }

    setState(() {
      _prescriptionType = value;

      // Update the same shared draft.
      _draft!.prescriptionType = value;
    });
  }

  // ========================================
  // CHANGE PRESCRIPTION NOTES
  // ========================================

  void _onPrescriptionNotesChanged(
      String value,
      ) {
    if (!_ensureCurrentDraft()) {
      return;
    }

    // Keep the original draft updated
    // as the user enters notes.

    _draft!.prescriptionNotes = value;
  }

  // ========================================
  // OPEN CAMERA
  // ========================================

  Future<void> _openCamera() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        _draft!.prescriptionNotes += '\n[Attached Photo: ${image.path}]';
        _showMessage('Prescription photo captured successfully!');
        setState(() {});
      }
    } catch (e) {
      _showMessage('Failed to capture photo: $e');
    }
  }

  // ========================================
  // OPEN GALLERY
  // ========================================

  Future<void> _openGallery() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _draft!.prescriptionNotes += '\n[Attached Gallery Image: ${image.path}]';
        _showMessage('Prescription image attached successfully!');
        setState(() {});
      }
    } catch (e) {
      _showMessage('Failed to pick image: $e');
    }
  }

  // ========================================
  // SELECT PDF / DOCUMENT
  // ========================================

  Future<void> _selectPdf() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
      );

      if (result != null && result.isNotEmpty) {
        final filePath = result.first.path ?? '';
        _draft!.prescriptionNotes += '\n[Attached File: $filePath]';
        _showMessage('Document attached successfully!');
        setState(() {});
      }
    } catch (e) {
      _showMessage('Failed to attach document: $e');
    }
  }

  // ========================================
  // CONVERT MEDICINES FOR REVIEW
  // ========================================

  // The ReviewSaveScreen constructor
  // currently accepts medicine maps.
  //
  // These maps are created from the
  // original shared VisitDraft.
  //
  // No separate draft is created.

  List<Map<String, Object?>> _medicineMaps(
      VisitDraft draft,
      ) {
    return draft.medicines
        .map<Map<String, Object?>>(
          (medicine) {
        return {
          'id': medicine.id,
          'name': medicine.name,
          'dose': medicine.dose,
          'frequency': medicine.frequency,
          'durationDays': medicine.durationDays,
          'mealTiming': medicine.mealTiming,
          'instructions': medicine.instructions,
        };
      },
    ).toList();
  }

  // ========================================
  // CONVERT MEDICAL TESTS FOR REVIEW
  // ========================================

  List<Map<String, Object?>> _testMaps(
      VisitDraft draft,
      ) {
    return draft.tests
        .map<Map<String, Object?>>(
          (test) {
        return {
          'id': test.id,
          'name': test.name,
          'status': test.status,
          'testDate': test.testDate,
          'resultNotes': test.resultNotes,
        };
      },
    ).toList();
  }

  // ========================================
  // CHECK UNSUPPORTED ATTACHMENTS
  // ========================================

  bool _hasUnsupportedAttachments(
      VisitDraft draft,
      ) {
    // The save service currently blocks
    // external image and PDF attachments.
    //
    // Prevent navigating to Review with
    // attachment references that cannot
    // be safely saved yet.

    if (draft.prescriptionAttachments.isNotEmpty) {
      return true;
    }

    for (final test in draft.tests) {
      if (test.reportAttachment != null) {
        return true;
      }
    }

    return false;
  }

  // ========================================
  // CONTINUE TO STEP 7 - REVIEW
  // ========================================

  void _continue() {
    // ======================================
    // VERIFY ACCOUNT SESSION
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // SAVE PRESCRIPTION INFORMATION
    // ======================================

    if (!_updatePrescriptionDraft()) {
      return;
    }

    final draft = _draft!;

    // ======================================
    // CHECK REQUIRED VISIT DATE AND TIME
    // ======================================

    final visitDate = draft.visitDate;

    final visitTime = draft.visitTime;

    if (visitDate == null || visitTime == null) {
      _showMessage(
        'Visit date or time is missing. '
            'Please return to Visit Information.',
      );

      return;
    }

    // ======================================
    // CHECK UNSUPPORTED ATTACHMENTS
    // ======================================

    if (_hasUnsupportedAttachments(draft)) {
      _showMessage(
        'This visit contains attachments '
            'that cannot be stored securely yet. '
            'Please remove unsupported attachments '
            'before continuing.',
      );

      return;
    }

    // ======================================
    // PREPARE MEDICINE AND TEST MAPS
    // ======================================

    final medicines = _medicineMaps(draft);

    final tests = _testMaps(draft);

    FocusScope.of(context).unfocus();

    // ======================================
    // VERIFY SESSION BEFORE NAVIGATION
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // OPEN FINAL REVIEW SCREEN
    // ======================================

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        // Pass the SAME original draft.
        settings: RouteSettings(
          arguments: draft,
        ),

        // Preserve existing ReviewSaveScreen
        // constructor parameters.
        builder: (_) => ReviewSaveScreen(
          // Doctor information
          doctorId: draft.doctorId,
          doctorName: draft.doctorName,
          hospitalName: draft.hospitalName,

          // Hospital location
          hospitalAddress:
          draft.hospitalAddress,

          // Visit date and time
          visitDate: visitDate,
          visitTime: visitTime,

          // Visit information
          reason: draft.reason,
          symptoms: draft.symptoms,
          diagnosis: draft.diagnosis,
          notes: draft.notes,

          followUpDate:
          draft.followUpDate,

          // Medicines and medical tests
          medicines: medicines,
          tests: tests,

          // Prescription information
          prescriptionType:
          draft.prescriptionType,

          prescriptionNotes:
          draft.prescriptionNotes,
        ),
      ),
    );
  }

  // ========================================
  // BACK TO STEP 5 - MEDICAL TESTS
  // ========================================

  void _goBack() {
    // Preserve prescription details only
    // when the account session is valid.

    if (_isCurrentDraft) {
      _updatePrescriptionDraft();
    }

    Navigator.of(context).maybePop();
  }

  // ========================================
  // REUSABLE ATTACHMENT BUTTON
  // ========================================

  Widget _buildAttachmentButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,

        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 14,
          ),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              icon,
              size: 24,
            ),

            const SizedBox(height: 6),

            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // DOCTOR AND VISIT SUMMARY
  // ========================================

  Widget _buildVisitSummary(
      VisitDraft draft,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor:
                  AppColors.doctorsLight,

                  child: Icon(
                    Icons.description_outlined,
                    color: AppColors.doctors,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        draft.doctorName,

                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        draft.hospitalName,

                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      if (draft.doctorSpecialization
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 5),

                        Text(
                          draft.doctorSpecialization,

                          style: const TextStyle(
                            fontSize: 12,
                            color:
                            AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            const Divider(),

            const SizedBox(height: 12),

            // ==================================
            // MEDICINE AND TEST COUNTS
            // ==================================

            Wrap(
              spacing: 20,
              runSpacing: 12,

              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.medication_outlined,
                      color: AppColors.medicines,
                      size: 20,
                    ),

                    const SizedBox(width: 7),

                    Text(
                      '${draft.medicines.length} Medicines',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.science_outlined,
                      color: AppColors.medicalTests,
                      size: 20,
                    ),

                    const SizedBox(width: 7),

                    Text(
                      '${draft.tests.length} Tests',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // PRESCRIPTION TYPE FIELD
  // ========================================

  Widget _buildPrescriptionTypeField() {
    return DropdownButtonFormField<String>(
      initialValue: _prescriptionType,

      isExpanded: true,

      decoration: const InputDecoration(
        labelText: 'Prescription Type',
        prefixIcon: Icon(
          Icons.article_outlined,
        ),
      ),

      items: _prescriptionTypes.map(
            (type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        },
      ).toList(),

      onChanged: _onPrescriptionTypeChanged,
    );
  }

  // ========================================
  // ATTACHMENT PLACEHOLDER
  // ========================================

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        const Text(
          'Attach Prescription',

          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        // ==================================
        // EMPTY ATTACHMENT PREVIEW
        // ==================================

        Container(
          width: double.infinity,

          padding: const EdgeInsets.all(24),

          decoration: BoxDecoration(
            color: AppColors.surface,

            borderRadius:
            BorderRadius.circular(16),

            border: Border.all(
              color: AppColors.border,
            ),
          ),

          child: const Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 42,
                color: AppColors.primary,
              ),

              SizedBox(height: 12),

              Text(
                'No files attached',

                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 7),

              Text(
                'Camera, gallery, and PDF upload '
                    'will be available after encrypted '
                    'attachment storage is implemented.',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ==================================
        // ATTACHMENT BUTTONS
        // ==================================

        Row(
          children: [
            _buildAttachmentButton(
              label: 'Camera',
              icon: Icons.camera_alt_outlined,
              onPressed: _openCamera,
            ),

            const SizedBox(width: 8),

            _buildAttachmentButton(
              label: 'Gallery',
              icon: Icons.photo_library_outlined,
              onPressed: _openGallery,
            ),

            const SizedBox(width: 8),

            _buildAttachmentButton(
              label: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: _selectPdf,
            ),
          ],
        ),

        const SizedBox(height: 12),

        const Text(
          'Attachment buttons are placeholders. '
              'No photo or PDF is collected or '
              'uploaded by these buttons.',

          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ========================================
  // INVALID ACCOUNT SESSION SCREEN
  // ========================================

  Widget _buildInvalidDraftScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Add Medical Visit',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                Container(
                  width: 76,
                  height: 76,

                  decoration: BoxDecoration(
                    color: AppColors.errorLight,

                    borderRadius:
                    BorderRadius.circular(22),
                  ),

                  child: const Icon(
                    Icons.lock_outline,
                    color: AppColors.error,
                    size: 38,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Prescription Draft Unavailable',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _draftError ??
                      'This prescription belongs '
                          'to an expired Google account '
                          'session. Please start '
                          'a new medical visit.',

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 22),

                OutlinedButton.icon(
                  onPressed: _goBack,

                  icon: const Icon(
                    Icons.arrow_back,
                  ),

                  label: const Text(
                    'Go Back',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================================
  // BUILD MAIN PRESCRIPTION SCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    // Never display doctor or prescription
    // information when the draft is invalid.

    if (!_isCurrentDraft) {
      return _buildInvalidDraftScreen();
    }

    final draft = _draft!;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Add Medical Visit',
        ),
      ),

      // ====================================
      // MAIN CONTENT
      // ====================================

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),

          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,

          children: [
            // ==============================
            // STEP PROGRESS
            // ==============================

            const Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  'Step 6 of 7',

                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  'Prescription',

                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const LinearProgressIndicator(
              value: 6 / 7,
              minHeight: 6,

              borderRadius: BorderRadius.all(
                Radius.circular(6),
              ),
            ),

            const SizedBox(height: 26),

            // ==============================
            // SCREEN INTRODUCTION
            // ==============================

            const Text(
              'Prescription & Documents',

              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Record prescription information '
                  'for this medical visit.',

              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 21),

            // ==============================
            // DOCTOR AND VISIT SUMMARY
            // ==============================

            _buildVisitSummary(draft),

            const SizedBox(height: 26),

            // ==============================
            // PRESCRIPTION TYPE
            // ==============================

            const Text(
              'Prescription Type',

              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            _buildPrescriptionTypeField(),

            const SizedBox(height: 24),

            // ==============================
            // PRESCRIPTION NOTES
            // ==============================

            TextFormField(
              controller:
              _prescriptionNotesController,

              minLines: 3,
              maxLines: 5,

              textCapitalization:
              TextCapitalization.sentences,

              decoration: const InputDecoration(
                labelText:
                'Prescription Notes (Optional)',

                hintText:
                'Enter notes written on '
                    'the prescription...',

                alignLabelWithHint: true,
              ),

              onChanged: _onPrescriptionNotesChanged,
            ),

            const SizedBox(height: 27),

            // ==============================
            // ATTACHMENTS
            // ==============================

            _buildAttachmentSection(),

            const SizedBox(height: 25),

            // ==============================
            // PRIVACY INFORMATION
            // ==============================

            const Card(
              child: Padding(
                padding: EdgeInsets.all(15),

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
                        'Prescription type and notes '
                            'will be saved in your '
                            'account-specific encrypted '
                            'SQLite database when you '
                            'finish the final review. '
                            'Photo/PDF attachments and '
                            'Google Drive backup are '
                            'not available yet.',

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

            const SizedBox(height: 25),
          ],
        ),
      ),

      // ====================================
      // BACK AND NEXT NAVIGATION
      // ====================================

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _goBack,

                  child: const Text(
                    'Back',
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: FilledButton(
                  onPressed: _continue,

                  child: const Text(
                    'Next: Review',
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

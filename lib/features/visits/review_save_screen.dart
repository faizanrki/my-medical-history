
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../models/visit_draft.dart';
import '../../services/medical_visit_save_service.dart';

// ============================================
// MY MEDICAL HISTORY
// STEP 44.17 - SECURE REVIEW AND SAVE
// STEP 7 OF 7
// ============================================
//
// FEATURES:
//
// 1. Require original account-bound draft.
// 2. Verify Google account session.
// 3. Review all medical visit details.
// 4. Save using the encrypted SQLite service.
// 5. Prevent repeated Save button taps.
// 6. Show success only after confirmed save.
// 7. Handle invalid and expired sessions.
// 8. Warn when save outcome is uncertain.
// 9. Preserve all review information.
// 10. Return to the application after saving.
//
// IMPORTANT:
//
// No medical records or encryption keys
// are deleted by this screen.
//
// Attachments and Google Drive backup
// are not implemented yet.
//
// ============================================

class ReviewSaveScreen extends StatefulWidget {
  // ========================================
  // EXISTING CONSTRUCTOR PARAMETERS
  // ========================================

  // These remain compatible with
  // PrescriptionStepScreen.

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

  final String prescriptionType;
  final String prescriptionNotes;

  const ReviewSaveScreen({
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
    required this.prescriptionType,
    required this.prescriptionNotes,
  });

  @override
  State<ReviewSaveScreen> createState() =>
      _ReviewSaveScreenState();
}

// ============================================
// REVIEW SCREEN STATE
// ============================================

class _ReviewSaveScreenState
    extends State<ReviewSaveScreen>
    with WidgetsBindingObserver {
  // ========================================
  // ACCOUNT-BOUND SHARED DRAFT
  // ========================================

  VisitDraft? _draft;

  int? _draftGeneration;

  bool _draftInitialized = false;

  String? _draftError;

  // ========================================
  // MEDICAL SAVE SERVICE
  // ========================================

  final MedicalVisitSaveService _saveService =
      MedicalVisitSaveService.instance;

  // ========================================
  // SAVE STATE
  // ========================================

  bool _isSaving = false;

  SavedVisitResult? _savedResult;

  String? _saveError;

  // An unexpected database error can occur
  // after a transaction was committed.
  //
  // We must not encourage a blind retry
  // that could create duplicate records.

  bool _saveOutcomeUncertain = false;

  // ========================================
  // MONTH NAMES
  // ========================================

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  // ========================================
  // INITIALIZE
  // ========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  // ========================================
  // RECEIVE ORIGINAL SHARED DRAFT
  // ========================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_draftInitialized) {
      return;
    }

    _draftInitialized = true;

    final arguments =
        ModalRoute.of(context)?.settings.arguments;

    // ======================================
    // REQUIRE ORIGINAL VISIT DRAFT
    // ======================================

    // Step 1 created the VisitDraft and
    // bound it to the current Google account.
    //
    // Steps 2-7 must preserve that object.
    //
    // Never construct a new VisitDraft
    // using the compatibility parameters.

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
      // VERIFY ACCOUNT SESSION
      // ====================================

      if (!AppDatabase.instance
          .isSessionCurrent(generation)) {
        throw StateError(
          'Medical account is locked.',
        );
      }

      // ====================================
      // VERIFY DRAFT OWNERSHIP
      // ====================================

      _saveService.verifyDraftForCurrentSession(
        arguments,
      );

      // ====================================
      // PRESERVE ORIGINAL DRAFT
      // ====================================

      _draft = arguments;

      _draftGeneration = generation;
    } catch (_) {
      _draft = null;

      _draftGeneration = null;

      _draftError =
      'This visit draft belongs to an '
          'expired or different Google '
          'account session. Please start '
          'a new medical visit.';
    }
  }

  // ========================================
  // VERIFY ACTIVE ACCOUNT AND DRAFT
  // ========================================

  bool get _isCurrentDraft {
    final draft = _draft;

    final generation = _draftGeneration;

    if (draft == null || generation == null) {
      return false;
    }

    // ======================================
    // ACCOUNT SESSION CHECK
    // ======================================

    if (!AppDatabase.instance
        .isSessionCurrent(generation)) {
      return false;
    }

    // ======================================
    // DRAFT OWNERSHIP CHECK
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
  // INVALIDATE EXPIRED DRAFT
  // ========================================

  void _invalidateDraft() {
    if (!mounted) {
      return;
    }

    setState(() {
      // Remove references to the previous
      // account's medical visit details.

      _draft = null;

      _draftGeneration = null;

      _savedResult = null;

      _saveError = null;

      _isSaving = false;

      _saveOutcomeUncertain = false;

      _draftError =
      'Your Google account session '
          'has changed. This medical visit '
          'can no longer be reviewed or saved. '
          'Please sign in and start a new visit.';
    });
  }

  // ========================================
  // VERIFY BEFORE SAVE ACTIONS
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
  // APP LIFECYCLE
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
  // DISPOSE
  // ========================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // ========================================
  // FORMAT DATE
  // ========================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not provided';
    }

    final day =
    date.day.toString().padLeft(2, '0');

    final month = _months[date.month - 1];

    return '$day $month ${date.year}';
  }

  // ========================================
  // DISPLAY OPTIONAL TEXT
  // ========================================

  String _displayText(String text) {
    if (text.trim().isEmpty) {
      return 'Not provided';
    }

    return text.trim();
  }

  // ========================================
  // SET SAVE ERROR
  // ========================================

  void _setSaveError(
      String message, {
        bool uncertain = false,
      }) {
    if (!mounted) {
      return;
    }

    if (!_isCurrentDraft) {
      _invalidateDraft();
      return;
    }

    setState(() {
      _saveError = message;
      _saveOutcomeUncertain = uncertain;
    });
  }

  // ========================================
  // SAVE MEDICAL VISIT
  // ========================================

  Future<void> _saveVisit() async {
    // ======================================
    // PREVENT DUPLICATE ACTIONS
    // ======================================

    if (_isSaving ||
        _savedResult != null ||
        _saveOutcomeUncertain) {
      return;
    }

    // ======================================
    // VERIFY DRAFT AND ACCOUNT
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    final draft = _draft!;

    final generation = _draftGeneration!;

    setState(() {
      _isSaving = true;

      _saveError = null;
    });

    try {
      // ====================================
      // VERIFY DRAFT AGAIN
      // ====================================

      _saveService.verifyDraftForCurrentSession(
        draft,
      );

      // ====================================
      // SAVE TO ENCRYPTED SQLITE
      // ====================================

      // The save service performs:
      //
      // - Validation
      // - Doctor creation or lookup
      // - Visit insertion
      // - Medicine insertion
      // - Test insertion
      // - Transaction management
      // - Session checks
      // - Duplicate-save prevention

      final result =
      await _saveService.saveVisit(draft);

      if (!mounted) {
        return;
      }

      // ====================================
      // VERIFY SESSION AFTER SAVE
      // ====================================

      // Never show an earlier account's
      // save result after switching accounts.

      if (!_isCurrentDraft ||
          _draftGeneration != generation) {
        _invalidateDraft();
        return;
      }

      // ====================================
      // CONFIRMED SUCCESS
      // ====================================

      setState(() {
        _savedResult = result;

        _saveError = null;

        _saveOutcomeUncertain = false;
      });
    } on FormatException catch (error) {
      // ====================================
      // USER INPUT VALIDATION FAILED
      // ====================================

      _setSaveError(error.message);
    } on UnsupportedError catch (error) {
      // ====================================
      // UNSUPPORTED FILE ATTACHMENT
      // ====================================

      _setSaveError(
        error.message?.toString() ??
            'This visit contains an '
                'unsupported item.',
      );
    } on StateError {
      // ====================================
      // SAVE STATUS NOT CONFIRMED
      // ====================================

      // Depending on when a session or
      // database error occurred, the visit
      // may already have been committed.
      //
      // Do not offer an immediate blind retry.

      _setSaveError(
        'The save could not be confirmed. '
            'Please check this account\'s History '
            'before trying to save the visit again. '
            'This helps prevent duplicate records.',
        uncertain: true,
      );
    } catch (_) {
      // ====================================
      // UNEXPECTED DATABASE ERROR
      // ====================================

      // Avoid exposing raw SQL exceptions,
      // file paths or encryption details.

      _setSaveError(
        'An unexpected error occurred while '
            'saving. The visit may or may not '
            'have been committed. Check History '
            'before creating another record.',
        uncertain: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ========================================
  // FINISH AND RETURN TO APPLICATION
  // ========================================

  void _finish() {
    if (_isSaving) {
      return;
    }

    // Preserve existing navigation behavior.
    //
    // Do not create a second Dashboard or
    // restart the Google sign-in process.

    Navigator.of(context).popUntil(
          (route) => route.isFirst,
    );
  }

  // ========================================
  // BACK TO PRESCRIPTION
  // ========================================

  void _goBack() {
    if (_isSaving || _savedResult != null) {
      return;
    }

    Navigator.of(context).maybePop();
  }

  // ========================================
  // REUSABLE REVIEW SECTION
  // ========================================

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: AppColors.primary,
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Text(
                    title,

                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            const Divider(height: 1),

            const SizedBox(height: 13),

            ...children,
          ],
        ),
      ),
    );
  }

  // ========================================
  // REUSABLE DETAIL FIELD
  // ========================================

  Widget _buildDetail({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            label,

            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            _displayText(value),

            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // MEDICINE / TEST COUNT CARD
  // ========================================

  Widget _buildCountCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 17,
        ),

        decoration: BoxDecoration(
          color: backgroundColor,

          borderRadius:
          BorderRadius.circular(14),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              icon,
              size: 27,
              color: color,
            ),

            const SizedBox(height: 9),

            Text(
              '$count',

              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              title,
              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // MEDICINE SUMMARY
  // ========================================

  Widget _buildMedicine(
      MedicineDraft medicine,
      int index,
      ) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(
        bottom: 12,
      ),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: AppColors.background,

        borderRadius:
        BorderRadius.circular(12),

        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            '${index + 1}. ${medicine.name}',

            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          _buildDetail(
            label: 'Dosage',
            value: medicine.dose,
          ),

          _buildDetail(
            label: 'Frequency',
            value: medicine.frequency,
          ),

          _buildDetail(
            label: 'Duration',
            value:
            '${medicine.durationDays} days',
          ),

          _buildDetail(
            label: 'Meal Timing',
            value: medicine.mealTiming,
          ),

          _buildDetail(
            label: 'Instructions',
            value: medicine.instructions,
          ),
        ],
      ),
    );
  }

  // ========================================
  // MEDICAL TEST SUMMARY
  // ========================================

  Widget _buildTest(
      MedicalTestDraft test,
      int index,
      ) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(
        bottom: 12,
      ),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: AppColors.background,

        borderRadius:
        BorderRadius.circular(12),

        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            '${index + 1}. ${test.name}',

            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          _buildDetail(
            label: 'Test Status',
            value: test.status,
          ),

          _buildDetail(
            label: 'Test Date',
            value: _formatDate(test.testDate),
          ),

          _buildDetail(
            label: 'Result Notes',
            value: test.resultNotes,
          ),

          _buildDetail(
            label: 'Report Attachment',

            value: test.reportAttachment == null
                ? 'Not attached'
                : test.reportAttachment!.fileName,
          ),
        ],
      ),
    );
  }

  // ========================================
  // PRESCRIPTION ATTACHMENT SUMMARY
  // ========================================

  Widget _buildAttachment(
      MedicalAttachmentDraft attachment,
      ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,

      leading: Icon(
        attachment.type ==
            MedicalAttachmentType.pdf
            ? Icons.picture_as_pdf_outlined
            : Icons.image_outlined,

        color: AppColors.primary,
      ),

      title: Text(
        attachment.fileName,
      ),

      subtitle: const Text(
        'Attachment reference in draft',
      ),
    );
  }

  // ========================================
  // SAVE STATUS
  // ========================================

  Widget _buildSaveStatus() {
    // ======================================
    // CONFIRMED SUCCESS
    // ======================================

    if (_savedResult != null) {
      final result = _savedResult!;

      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(17),

        decoration: BoxDecoration(
          color: AppColors.successLight,

          borderRadius:
          BorderRadius.circular(14),

          border: Border.all(
            color: AppColors.success
                .withValues(alpha: 0.20),
          ),
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 29,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Medical Visit Saved!',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            const Text(
              'Your medical visit was saved '
                  'to your account-specific '
                  'encrypted local database.',

              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 15),

            _buildDetail(
              label: 'Visit ID',
              value: result.visitId,
            ),

            _buildDetail(
              label: 'Doctor',

              value: result.doctorCreated
                  ? 'New doctor profile created'
                  : 'Existing doctor profile used',
            ),

            _buildDetail(
              label: 'Records Saved',

              value:
              '${result.medicineCount} medicines, '
                  '${result.testCount} medical tests',
            ),

            const SizedBox(height: 4),

            const Text(
              'Google Drive backup has not '
                  'been performed.',

              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // ======================================
    // SAVE ERROR
    // ======================================

    if (_saveError != null) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: AppColors.errorLight,

          borderRadius:
          BorderRadius.circular(14),
        ),

        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Text(
                    _saveOutcomeUncertain
                        ? 'Save Status Unconfirmed'
                        : 'Unable to Save',

                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _saveError!,

                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ======================================
    // NOT SAVED YET / SAVING
    // ======================================

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: AppColors.warningLight,

        borderRadius:
        BorderRadius.circular(13),
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.warning,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              _isSaving
                  ? 'Saving this medical visit. '
                  'Please wait until the '
                  'database operation finishes.'
                  : 'This visit has not been saved '
                  'yet. Check the information '
                  'below and tap Save Visit.',

              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
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
          'Review Medical Visit',
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
                  'Review Session Unavailable',

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
                      'Your Google account session '
                          'has expired or changed. '
                          'This visit can no longer '
                          'be reviewed or saved.',

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 13),

                const Text(
                  'If you had already tapped '
                      'Save Visit, check the original '
                      'account\'s History before '
                      'trying again.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 12,
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
  // MAIN REVIEW SCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    // ======================================
    // REJECT INVALID ACCOUNT
    // ======================================

    if (!_isCurrentDraft) {
      return _buildInvalidDraftScreen();
    }

    final draft = _draft!;

    return PopScope(
      // Do not leave while the SQLite
      // save operation is in progress.
      //
      // After a successful save, users
      // finish through the Done button.

      canPop:
      !_isSaving && _savedResult == null,

      child: Scaffold(
        backgroundColor: AppColors.background,

        // ====================================
        // APP BAR
        // ====================================

        appBar: AppBar(
          title: const Text(
            'Review Medical Visit',
          ),

          automaticallyImplyLeading:
          _savedResult == null,
        ),

        // ====================================
        // MAIN CONTENT
        // ====================================

        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),

            children: [
              // ==============================
              // STEP INDICATOR
              // ==============================

              const Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    'Step 7 of 7',

                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Text(
                    'Review & Save',

                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const LinearProgressIndicator(
                value: 1,
                minHeight: 6,

                borderRadius: BorderRadius.all(
                  Radius.circular(6),
                ),
              ),

              const SizedBox(height: 25),

              // ==============================
              // INTRODUCTION
              // ==============================

              const Text(
                'Review Your Medical Visit',

                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Please check your medical '
                    'information before saving.',

                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 21),

              // ==============================
              // SAVE STATUS
              // ==============================

              _buildSaveStatus(),

              const SizedBox(height: 22),

              // ==============================
              // SUMMARY COUNTS
              // ==============================

              Row(
                children: [
                  _buildCountCard(
                    title: 'Medicines',

                    count: draft.medicines.length,

                    icon:
                    Icons.medication_outlined,

                    color: AppColors.medicines,

                    backgroundColor:
                    AppColors.medicinesLight,
                  ),

                  const SizedBox(width: 12),

                  _buildCountCard(
                    title: 'Medical Tests',

                    count: draft.tests.length,

                    icon: Icons.science_outlined,

                    color: AppColors.medicalTests,

                    backgroundColor:
                    AppColors.medicalTestsLight,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ==============================
              // DOCTOR INFORMATION
              // ==============================

              _buildSection(
                title: 'Doctor Information',

                icon:
                Icons.medical_services_outlined,

                children: [
                  _buildDetail(
                    label: 'Doctor Name',
                    value: draft.doctorName,
                  ),

                  _buildDetail(
                    label: 'Specialization',
                    value:
                    draft.doctorSpecialization,
                  ),

                  _buildDetail(
                    label: 'Phone Number',
                    value: draft.doctorPhone,
                  ),

                  _buildDetail(
                    label: 'Hospital / Clinic',
                    value: draft.hospitalName,
                  ),

                  _buildDetail(
                    label: 'Doctor Type',

                    value: draft.isExistingDoctor
                        ? 'Existing Doctor'
                        : 'New Doctor',
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ==============================
              // HOSPITAL LOCATION
              // ==============================

              _buildSection(
                title: 'Hospital Location',

                icon: Icons.location_on_outlined,

                children: [
                  _buildDetail(
                    label: 'Hospital Address',

                    value: draft.hospitalAddress,
                  ),

                  _buildDetail(
                    label: 'GPS Coordinates',

                    value: draft.latitude == null ||
                        draft.longitude == null
                        ? 'Not selected'
                        : '${draft.latitude}, '
                        '${draft.longitude}',
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ==============================
              // VISIT INFORMATION
              // ==============================

              _buildSection(
                title: 'Visit Information',

                icon:
                Icons.calendar_month_outlined,

                children: [
                  _buildDetail(
                    label: 'Visit Date',

                    value: _formatDate(
                      draft.visitDate,
                    ),
                  ),

                  _buildDetail(
                    label: 'Visit Time',

                    value: draft.visitTime == null
                        ? 'Not provided'
                        : draft.visitTime!
                        .format(context),
                  ),

                  _buildDetail(
                    label: 'Reason for Visit',
                    value: draft.reason,
                  ),

                  _buildDetail(
                    label: 'Symptoms',
                    value: draft.symptoms,
                  ),

                  _buildDetail(
                    label: 'Diagnosis',
                    value: draft.diagnosis,
                  ),

                  _buildDetail(
                    label: "Doctor's Notes",
                    value: draft.notes,
                  ),

                  _buildDetail(
                    label: 'Follow-up Date',

                    value: draft.followUpDate == null
                        ? 'Not scheduled'
                        : _formatDate(
                      draft.followUpDate,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ==============================
              // PRESCRIBED MEDICINES
              // ==============================

              _buildSection(
                title: 'Prescribed Medicines',

                icon: Icons.medication_outlined,

                children: [
                  if (draft.medicines.isEmpty)
                    const Text(
                      'No medicines added.',
                      style: TextStyle(
                        color:
                        AppColors.textSecondary,
                      ),
                    ),

                  for (var i = 0;
                  i < draft.medicines.length;
                  i++)
                    _buildMedicine(
                      draft.medicines[i],
                      i,
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // ==============================
              // MEDICAL TESTS
              // ==============================

              _buildSection(
                title: 'Medical Tests',

                icon: Icons.science_outlined,

                children: [
                  if (draft.tests.isEmpty)
                    const Text(
                      'No medical tests added.',
                      style: TextStyle(
                        color:
                        AppColors.textSecondary,
                      ),
                    ),

                  for (var i = 0;
                  i < draft.tests.length;
                  i++)
                    _buildTest(
                      draft.tests[i],
                      i,
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // ==============================
              // PRESCRIPTION
              // ==============================

              _buildSection(
                title: 'Prescription',

                icon: Icons.description_outlined,

                children: [
                  _buildDetail(
                    label: 'Prescription Type',

                    value:
                    draft.prescriptionType,
                  ),

                  _buildDetail(
                    label: 'Prescription Notes',

                    value:
                    draft.prescriptionNotes,
                  ),

                  _buildDetail(
                    label: 'Attachments',

                    value: draft
                        .prescriptionAttachments
                        .isEmpty
                        ? 'No files attached'
                        : '${draft.prescriptionAttachments.length} '
                        'file(s) in draft',
                  ),

                  for (final attachment
                  in draft.prescriptionAttachments)
                    _buildAttachment(
                      attachment,
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // ==============================
              // EDITING REMINDER
              // ==============================

              if (_savedResult == null &&
                  !_saveOutcomeUncertain)
                const Text(
                  'Need to change something? '
                      'Use Back to edit earlier steps.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),

        // ====================================
        // BOTTOM ACTIONS
        // ====================================

        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),

            child: _savedResult != null
            // ==========================
            // SUCCESS: DONE
            // ==========================

                ? SizedBox(
              width: double.infinity,

              child: FilledButton.icon(
                onPressed: _finish,

                icon: const Icon(
                  Icons.check,
                ),

                label: const Text(
                  'Done',
                ),
              ),
            )

            // ==========================
            // UNCERTAIN SAVE: RETURN
            // ==========================

                : _saveOutcomeUncertain
                ? SizedBox(
              width: double.infinity,

              child: FilledButton.icon(
                onPressed: _finish,

                icon: const Icon(
                  Icons.history,
                ),

                label: const Text(
                  'Return to App',
                ),
              ),
            )

            // ======================
            // NORMAL: BACK AND SAVE
            // ======================

                : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : _goBack,

                    child: const Text(
                      'Back',
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  flex: 2,

                  child: FilledButton.icon(
                    onPressed: _isSaving
                        ? null
                        : _saveVisit,

                    icon: _isSaving
                        ? const SizedBox(
                      width: 18,
                      height: 18,

                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.save_outlined,
                      size: 18,
                    ),

                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : _saveError != null
                          ? 'Try Save Again'
                          : 'Save Visit',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../models/visit_draft.dart';
import '../../services/medical_visit_save_service.dart';

import 'prescription_step_screen.dart';

// ============================================
// MY MEDICAL HISTORY
// STEP 44.15 - SECURE MEDICAL TESTS
// STEP 5 OF 7
// ============================================
//
// FEATURES
//
// 1. Account-bound VisitDraft.
// 2. Google account session verification.
// 3. Add and edit medical tests.
// 4. Delete medical tests.
// 5. Test status selection.
// 6. Optional test date.
// 7. Result notes.
// 8. Unencrypted attachment blocking.
// 9. Preserve medicines and visit details.
// 10. Secure navigation to Prescription.
//
// ============================================

class MedicalTestsStepScreen extends StatefulWidget {
  // ========================================
  // EXISTING CONSTRUCTOR PARAMETERS
  // ========================================

  // These are preserved so Step 4 can
  // continue opening this screen.

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

  const MedicalTestsStepScreen({
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
  });

  @override
  State<MedicalTestsStepScreen> createState() =>
      _MedicalTestsStepScreenState();
}

class _MedicalTestsStepScreenState
    extends State<MedicalTestsStepScreen>
    with WidgetsBindingObserver {

  // ========================================
  // ACCOUNT-BOUND SHARED DRAFT
  // ========================================

  VisitDraft? _draft;

  int? _draftGeneration;

  bool _draftInitialized = false;

  String? _draftError;

  // ========================================
  // SAVE SERVICE
  // ========================================

  final MedicalVisitSaveService _saveService =
      MedicalVisitSaveService.instance;

  // ========================================
  // SHARED MEDICAL TESTS LIST
  // ========================================

  List<MedicalTestDraft> get _tests =>
      _draft!.tests;

  // ========================================
  // FORM AND SCROLL
  // ========================================

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final ScrollController _scrollController =
  ScrollController();

  // ========================================
  // TEXT CONTROLLERS
  // ========================================

  final TextEditingController _testNameController =
  TextEditingController();

  final TextEditingController _resultNotesController =
  TextEditingController();

  // ========================================
  // FORM VALUES
  // ========================================

  String _selectedStatus = 'Prescribed';

  DateTime? _selectedTestDate;

  int _nextTestId = 1;

  int? _editingTestId;

  int _formVersion = 0;

  // ========================================
  // TEST STATUS OPTIONS
  // ========================================

  static const List<String> _statusOptions = [
    'Prescribed',
    'Scheduled',
    'Completed',
    'Result Received',
  ];

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
  // RECEIVE ORIGINAL VISIT DRAFT
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
    // REQUIRE ORIGINAL DRAFT
    // ======================================

    // Do not create a new VisitDraft here.
    //
    // The original draft must come from
    // AddVisitScreen and remain unchanged
    // through all seven steps.

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
          'Medical account session is locked.',
        );
      }

      // ====================================
      // VERIFY ORIGINAL DRAFT OWNERSHIP
      // ====================================

      _saveService.verifyDraftForCurrentSession(
        arguments,
      );

      _draft = arguments;
      _draftGeneration = generation;

      // ====================================
      // FIND NEXT AVAILABLE TEST ID
      // ====================================

      for (final test in arguments.tests) {
        if (test.id >= _nextTestId) {
          _nextTestId = test.id + 1;
        }
      }
    } catch (_) {
      _draft = null;
      _draftGeneration = null;

      _draftError =
      'This medical visit belongs to an '
          'expired or different Google account '
          'session. Start a new visit.';
    }
  }

  // ========================================
  // CHECK CURRENT ACCOUNT AND DRAFT
  // ========================================

  bool get _isCurrentDraft {
    final draft = _draft;
    final generation = _draftGeneration;

    if (draft == null || generation == null) {
      return false;
    }

    if (!AppDatabase.instance
        .isSessionCurrent(generation)) {
      return false;
    }

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

    _testNameController.clear();
    _resultNotesController.clear();

    setState(() {
      _draft = null;
      _draftGeneration = null;

      _editingTestId = null;
      _selectedTestDate = null;
      _selectedStatus = 'Prescribed';

      _draftError =
      'Your Google account session changed. '
          'This medical test form can no longer '
          'be continued. Start a new visit.';
    });
  }

  // ========================================
  // VERIFY BEFORE FORM ACTIONS
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
  // APP LIFECYCLE CHECK
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

    _testNameController.dispose();
    _resultNotesController.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  // ========================================
  // SHOW MESSAGE
  // ========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ========================================
  // FORMAT DATE
  // ========================================

  String _formatDate(DateTime date) {
    final day =
    date.day.toString().padLeft(2, '0');

    final month = _months[date.month - 1];

    return '$day $month ${date.year}';
  }

  // ========================================
  // VALIDATE TEST NAME
  // ========================================

  String? _validateTestName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the test name';
    }

    return null;
  }

  // ========================================
  // SELECT TEST DATE
  // ========================================

  Future<void> _selectTestDate() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    final now = DateTime.now();

    final firstAllowed = DateTime(1900);

    final lastAllowed = DateTime(
      now.year + 10,
      12,
      31,
    );

    DateTime initial =
        _selectedTestDate ?? now;

    if (initial.isBefore(firstAllowed)) {
      initial = firstAllowed;
    }

    if (initial.isAfter(lastAllowed)) {
      initial = lastAllowed;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstAllowed,
      lastDate: lastAllowed,
      helpText: 'SELECT TEST DATE',
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    // The account might change while the
    // user is interacting with the picker.

    if (!_ensureCurrentDraft()) {
      return;
    }

    setState(() {
      _selectedTestDate = selectedDate;
    });
  }

  // ========================================
  // CLEAR TEST DATE
  // ========================================

  void _clearTestDate() {
    if (!_ensureCurrentDraft()) {
      return;
    }

    setState(() {
      _selectedTestDate = null;
    });
  }

  // ========================================
  // ADD OR UPDATE MEDICAL TEST
  // ========================================

  void _addOrUpdateTest() {
    // ======================================
    // VERIFY ACCOUNT
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // VALIDATE FORM
    // ======================================

    if (!(_formKey.currentState?.validate() ??
        false)) {
      return;
    }

    final isEditing =
        _editingTestId != null;

    final testId =
        _editingTestId ?? _nextTestId;

    // ======================================
    // LOOK UP EXISTING TEST
    // ======================================

    int existingIndex = -1;

    MedicalAttachmentDraft? existingAttachment;

    if (isEditing) {
      existingIndex = _tests.indexWhere(
            (test) => test.id == _editingTestId,
      );

      if (existingIndex == -1) {
        _showMessage(
          'The selected test could not '
              'be found. Please try again.',
        );

        _clearForm();
        return;
      }

      existingAttachment =
          _tests[existingIndex].reportAttachment;
    }

    // ======================================
    // CREATE UPDATED TEST DRAFT
    // ======================================

    final test = MedicalTestDraft(
      id: testId,

      name: _testNameController.text.trim(),

      status: _selectedStatus,

      testDate: _selectedTestDate,

      resultNotes:
      _resultNotesController.text.trim(),

      reportAttachment: existingAttachment,
    );

    // ======================================
    // VERIFY ACCOUNT AGAIN
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    if (isEditing) {
      // ====================================
      // UPDATE EXISTING TEST
      // ====================================

      setState(() {
        _tests[existingIndex] = test;
      });
    } else {
      // ====================================
      // ADD NEW TEST
      // ====================================

      setState(() {
        _tests.add(test);
        _nextTestId++;
      });
    }

    _clearForm();

    FocusScope.of(context).unfocus();

    _showMessage(
      isEditing
          ? 'Test updated in visit draft.'
          : 'Test added to visit draft.',
    );
  }

  // ========================================
  // CLEAR TEST ENTRY FORM
  // ========================================

  void _clearForm() {
    if (!_ensureCurrentDraft()) {
      return;
    }

    _formKey.currentState?.reset();

    _testNameController.clear();
    _resultNotesController.clear();

    setState(() {
      _editingTestId = null;

      _selectedStatus = 'Prescribed';
      _selectedTestDate = null;

      _formVersion++;
    });
  }

  // ========================================
  // EDIT EXISTING TEST
  // ========================================

  void _editTest(MedicalTestDraft test) {
    if (!_ensureCurrentDraft()) {
      return;
    }

    final exists = _tests.any(
          (item) => item.id == test.id,
    );

    if (!exists) {
      _showMessage(
        'Test no longer exists in this draft.',
      );

      return;
    }

    _testNameController.text = test.name;

    _resultNotesController.text =
        test.resultNotes;

    setState(() {
      _editingTestId = test.id;

      _selectedStatus =
      _statusOptions.contains(test.status)
          ? test.status
          : 'Prescribed';

      _selectedTestDate = test.testDate;

      _formVersion++;
    });

    // Scroll back to the entry form.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOut,
      );
    }
  }

  // ========================================
  // REMOVE EXISTING TEST
  // ========================================

  void _removeTest(int testId) {
    if (!_ensureCurrentDraft()) {
      return;
    }

    setState(() {
      _tests.removeWhere(
            (test) => test.id == testId,
      );
    });

    if (_editingTestId == testId) {
      _clearForm();
    }

    _showMessage(
      'Test removed from visit draft.',
    );
  }

  // ========================================
  // REPORT ATTACHMENT PLACEHOLDER
  // ========================================

  Future<void> _showAttachmentMessage() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png'],
      );

      if (result != null && result.isNotEmpty) {
        final file = result.first;
        final type = file.extension == 'pdf' ? MedicalAttachmentType.pdf : MedicalAttachmentType.image;
        final attachment = MedicalAttachmentDraft(
          fileName: file.name,
          filePath: file.path ?? '',
          type: type,
        );
        _showMessage('Test report "${attachment.fileName}" attached successfully!');
      }
    } catch (e) {
      _showMessage('Failed to attach report: $e');
    }
  }

  // ========================================
  // DETECT UNFINISHED TEST INPUT
  // ========================================

  bool get _hasPendingInput {
    return _editingTestId != null ||
        _testNameController.text.trim().isNotEmpty ||
        _resultNotesController.text
            .trim()
            .isNotEmpty ||
        _selectedTestDate != null ||
        _selectedStatus != 'Prescribed';
  }

  // ========================================
  // CONVERT MEDICINES FOR STEP 6
  // ========================================

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
  // CONVERT TESTS FOR STEP 6
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
  // CONTINUE TO STEP 6 - PRESCRIPTION
  // ========================================

  void _continue() {
    // ======================================
    // CHECK ACCOUNT AND DRAFT
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // CHECK UNFINISHED FORM
    // ======================================

    if (_hasPendingInput) {
      _showMessage(
        'Please add or update this test, '
            'or clear the form before continuing.',
      );

      return;
    }

    final draft = _draft!;

    final visitDate = draft.visitDate;
    final visitTime = draft.visitTime;

    if (visitDate == null || visitTime == null) {
      _showMessage(
        'The visit date or time is missing. '
            'Please return to Visit Information.',
      );

      return;
    }

    // ======================================
    // PREPARE STEP 6 DATA
    // ======================================

    final medicines = _medicineMaps(draft);
    final tests = _testMaps(draft);

    FocusScope.of(context).unfocus();

    // ======================================
    // FINAL ACCOUNT CHECK
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // OPEN PRESCRIPTION SCREEN
    // ======================================

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          arguments: draft,
        ),

        // Keep the original Step 6
        // constructor and navigation.
        builder: (_) => PrescriptionStepScreen(
          doctorId: draft.doctorId,
          doctorName: draft.doctorName,
          hospitalName: draft.hospitalName,
          hospitalAddress: draft.hospitalAddress,

          visitDate: visitDate,
          visitTime: visitTime,

          reason: draft.reason,
          symptoms: draft.symptoms,
          diagnosis: draft.diagnosis,
          notes: draft.notes,

          followUpDate: draft.followUpDate,

          medicines: medicines,
          tests: tests,
        ),
      ),
    );
  }

  // ========================================
  // BACK TO MEDICINES
  // ========================================

  void _goBack() {
    Navigator.of(context).maybePop();
  }

  // ========================================
  // DOCTOR AND VISIT SUMMARY
  // ========================================

  Widget _buildVisitSummary(VisitDraft draft) {
    final visitDate = draft.visitDate;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),

        leading: const CircleAvatar(
          backgroundColor:
          AppColors.medicalTestsLight,

          child: Icon(
            Icons.science_outlined,
            color: AppColors.medicalTests,
          ),
        ),

        title: Text(
          draft.doctorName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),

          child: Text(
            '${draft.hospitalName}\n'
                'Visit: ${visitDate == null ? 'Not selected' : _formatDate(visitDate)}',

            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        isThreeLine: true,
      ),
    );
  }

  // ========================================
  // BUILD TEST ENTRY FORM
  // ========================================

  Widget _buildTestForm() {
    return Form(
      key: _formKey,

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            _editingTestId == null
                ? 'Add a Test'
                : 'Edit Test',

            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          // ==================================
          // TEST NAME
          // ==================================

          TextFormField(
            controller: _testNameController,

            textCapitalization:
            TextCapitalization.words,

            decoration: const InputDecoration(
              labelText: 'Test Name *',
              hintText: 'e.g. CBC or X-ray',

              prefixIcon: Icon(
                Icons.science_outlined,
              ),
            ),

            validator: _validateTestName,
          ),

          const SizedBox(height: 16),

          // ==================================
          // TEST STATUS
          // ==================================

          DropdownButtonFormField<String>(
            key: ValueKey(
              'status_$_formVersion',
            ),

            initialValue: _selectedStatus,
            isExpanded: true,

            decoration: const InputDecoration(
              labelText: 'Test Status',

              prefixIcon: Icon(
                Icons.assignment_turned_in_outlined,
              ),
            ),

            items: _statusOptions.map(
                  (status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              },
            ).toList(),

            onChanged: (value) {
              if (!_ensureCurrentDraft()) {
                return;
              }

              if (value != null) {
                setState(() {
                  _selectedStatus = value;
                });
              }
            },
          ),

          const SizedBox(height: 18),

          // ==================================
          // TEST DATE
          // ==================================

          const Text(
            'Test Date (Optional)',

            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              onPressed: _selectTestDate,

              icon: const Icon(
                Icons.calendar_month_outlined,
              ),

              label: Text(
                _selectedTestDate == null
                    ? 'Select Test Date'
                    : _formatDate(
                  _selectedTestDate!,
                ),
              ),
            ),
          ),

          if (_selectedTestDate != null)
            Align(
              alignment: Alignment.centerRight,

              child: TextButton.icon(
                onPressed: _clearTestDate,

                icon: const Icon(
                  Icons.close,
                  size: 18,
                ),

                label: const Text(
                  'Clear Date',
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ==================================
          // RESULT NOTES
          // ==================================

          TextFormField(
            controller: _resultNotesController,

            minLines: 2,
            maxLines: 4,

            textCapitalization:
            TextCapitalization.sentences,

            decoration: const InputDecoration(
              labelText: 'Result Notes (Optional)',

              hintText:
              'Enter results or observations '
                  'from the test report...',

              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 20),

          // ==================================
          // REPORT ATTACHMENT
          // ==================================

          const Text(
            'Test Report',

            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 9),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              onPressed: _showAttachmentMessage,

              icon: const Icon(
                Icons.attach_file,
              ),

              label: const Text(
                'Attach Report (Coming Later)',
              ),
            ),
          ),

          const SizedBox(height: 9),

          const Text(
            'PDF and image uploads are disabled '
                'until encrypted attachment storage '
                'is implemented.',

            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // ==================================
          // ADD OR UPDATE
          // ==================================

          SizedBox(
            width: double.infinity,

            child: FilledButton.icon(
              onPressed: _addOrUpdateTest,

              icon: Icon(
                _editingTestId == null
                    ? Icons.add
                    : Icons.check,
              ),

              label: Text(
                _editingTestId == null
                    ? 'Add Test'
                    : 'Update Test',
              ),
            ),
          ),

          const SizedBox(height: 9),

          Center(
            child: TextButton(
              onPressed: _clearForm,

              child: const Text(
                'Clear Form',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // INVALID SESSION SCREEN
  // ========================================

  Widget _buildInvalidDraftScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Add Medical Visit'),
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
                    size: 38,
                    color: AppColors.error,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Visit Draft Unavailable',

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
                      'This medical visit belongs '
                          'to an expired account session. '
                          'Please start a new visit.',

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
  // MAIN MEDICAL TESTS SCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    // Do not display saved test details
    // after the account session expires.

    if (!_isCurrentDraft) {
      return _buildInvalidDraftScreen();
    }

    final draft = _draft!;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Add Medical Visit'),
      ),

      body: SafeArea(
        child: ListView(
          controller: _scrollController,

          padding: const EdgeInsets.all(18),

          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,

          children: [
            // =================================
            // STEP INDICATOR
            // =================================

            const Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  'Step 5 of 7',

                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  'Medical Tests',

                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const LinearProgressIndicator(
              value: 5 / 7,
              minHeight: 6,

              borderRadius: BorderRadius.all(
                Radius.circular(6),
              ),
            ),

            const SizedBox(height: 25),

            // =================================
            // SCREEN INTRODUCTION
            // =================================

            const Text(
              'Medical Tests',

              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Record medical tests prescribed '
                  'or performed during this visit.',

              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 19),

            // =================================
            // DOCTOR AND VISIT SUMMARY
            // =================================

            _buildVisitSummary(draft),

            const SizedBox(height: 13),

            Text(
              '${draft.medicines.length} medicines '
                  'in this visit draft',

              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // =================================
            // TEST ENTRY FORM
            // =================================

            _buildTestForm(),

            const SizedBox(height: 27),

            // =================================
            // TEST LIST TITLE
            // =================================

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tests Added',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                Text(
                  '${_tests.length} total',

                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // =================================
            // EMPTY TEST LIST
            // =================================

            if (_tests.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),

                  child: Column(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 42,
                        color: AppColors.textSecondary,
                      ),

                      SizedBox(height: 12),

                      Text(
                        'No medical tests added yet.',
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 7),

                      Text(
                        'You can continue if no '
                            'tests were prescribed.',

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // =================================
            // TEST CARDS
            // =================================

            for (final test in _tests) ...[
              _MedicalTestCard(
                key: ValueKey(test.id),

                test: test,

                formatDate: _formatDate,

                onEdit: () {
                  _editTest(test);
                },

                onDelete: () {
                  _removeTest(test.id);
                },
              ),

              const SizedBox(height: 10),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),

      // ===================================
      // BACK AND NEXT BUTTONS
      // ===================================

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _goBack,

                  child: const Text('Back'),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: FilledButton(
                  onPressed: _continue,

                  child: const Text(
                    'Next: Prescription',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
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

// ============================================
// REUSABLE MEDICAL TEST CARD
// ============================================

class _MedicalTestCard extends StatelessWidget {
  final MedicalTestDraft test;

  final String Function(DateTime) formatDate;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicalTestCard({
    super.key,
    required this.test,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
  });

  Color _statusColor() {
    switch (test.status) {
      case 'Completed':
      case 'Result Received':
        return AppColors.success;

      case 'Scheduled':
        return AppColors.primary;

      default:
        return AppColors.medicalTests;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                const CircleAvatar(
                  backgroundColor:
                  AppColors.medicalTestsLight,

                  child: Icon(
                    Icons.science_outlined,
                    color: AppColors.medicalTests,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 8,
                    ),

                    child: Text(
                      test.name,

                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Edit test',
                  onPressed: onEdit,

                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                  ),
                ),

                IconButton(
                  tooltip: 'Remove test',
                  onPressed: onDelete,

                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 11),

            // =================================
            // TEST STATUS
            // =================================

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 7,
              ),

              decoration: BoxDecoration(
                color: _statusColor().withValues(
                  alpha: 0.10,
                ),

                borderRadius:
                BorderRadius.circular(9),
              ),

              child: Text(
                test.status,

                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(),
                ),
              ),
            ),

            // =================================
            // TEST DATE
            // =================================

            if (test.testDate != null) ...[
              const SizedBox(height: 13),

              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),

                  const SizedBox(width: 8),

                  Flexible(
                    child: Text(
                      formatDate(test.testDate!),

                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // =================================
            // RESULT NOTES
            // =================================

            if (test.resultNotes
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 12),

              Text(
                test.resultNotes,

                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // =================================
            // REPORT ATTACHMENT STATUS
            // =================================

            Row(
              children: [
                Icon(
                  test.reportAttachment == null
                      ? Icons.insert_drive_file_outlined
                      : Icons.attach_file,

                  size: 16,
                  color: AppColors.textSecondary,
                ),

                const SizedBox(width: 7),

                Expanded(
                  child: Text(
                    test.reportAttachment == null
                        ? 'No report attached'
                        : test.reportAttachment!.fileName,

                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

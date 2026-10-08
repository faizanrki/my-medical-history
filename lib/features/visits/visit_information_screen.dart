
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../models/visit_draft.dart';
import '../../services/medical_visit_save_service.dart';

import 'medicines_step_screen.dart';

// ==========================================
// MY MEDICAL HISTORY
// STEP 44.13 - SECURE VISIT INFORMATION
// STEP 3 OF 7
// ==========================================
//
// FEATURES:
//
// 1. Account-bound shared VisitDraft.
// 2. Google account session verification.
// 3. Visit date and time selection.
// 4. Reason for visit.
// 5. Symptoms and diagnosis.
// 6. Doctor's notes.
// 7. Optional follow-up date.
// 8. Preserve data when going back.
// 9. Secure navigation to Step 4.
// 10. Prevent unbound draft creation.
//
// ==========================================

class VisitInformationScreen extends StatefulWidget {
  // Existing constructor parameters.
  // Kept for compatibility with Step 2.
  final String? doctorId;
  final String doctorName;
  final String hospitalName;
  final String hospitalAddress;

  const VisitInformationScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.hospitalName,
    required this.hospitalAddress,
  });

  @override
  State<VisitInformationScreen> createState() =>
      _VisitInformationScreenState();
}

class _VisitInformationScreenState
    extends State<VisitInformationScreen>
    with WidgetsBindingObserver {
  // ======================================
  // ACCOUNT-BOUND VISIT DRAFT
  // ======================================

  VisitDraft? _draft;

  int? _draftGeneration;

  bool _draftInitialized = false;

  String? _draftError;

  // ======================================
  // SAVE SERVICE
  // ======================================

  final MedicalVisitSaveService _saveService =
      MedicalVisitSaveService.instance;

  // ======================================
  // FORM KEY
  // ======================================

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  // ======================================
  // TEXT CONTROLLERS
  // ======================================

  final TextEditingController _reasonController =
  TextEditingController();

  final TextEditingController _symptomsController =
  TextEditingController();

  final TextEditingController _diagnosisController =
  TextEditingController();

  final TextEditingController _notesController =
  TextEditingController();

  // ======================================
  // VISIT DATE AND TIME
  // ======================================

  late DateTime _visitDate;

  late TimeOfDay _visitTime;

  DateTime? _followUpDate;

  // ======================================
  // MONTH NAMES
  // ======================================

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

  // ======================================
  // INITIALIZE
  // ======================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final now = DateTime.now();

    _visitDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _visitTime = TimeOfDay.now();
  }

  // ======================================
  // RECEIVE ORIGINAL SHARED VISIT DRAFT
  // ======================================

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

    // Do not create a fallback VisitDraft.
    //
    // Only Step 1 should create and bind
    // the shared draft to an account session.

    if (arguments is! VisitDraft) {
      _draftError =
      'The original visit draft was not '
          'received. Return to Add Visit '
          'and start a new form.';

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
      // VERIFY DRAFT OWNERSHIP
      // ====================================

      // This verifies the existing draft.
      // It does NOT bind an unregistered one.

      _saveService.verifyDraftForCurrentSession(
        arguments,
      );

      // ====================================
      // STORE ORIGINAL DRAFT
      // ====================================

      _draft = arguments;
      _draftGeneration = generation;

      // ====================================
      // RESTORE VISIT DATE
      // ====================================

      _visitDate =
          arguments.visitDate ?? _visitDate;

      // ====================================
      // RESTORE VISIT TIME
      // ====================================

      _visitTime =
          arguments.visitTime ?? _visitTime;

      // ====================================
      // RESTORE FOLLOW-UP DATE
      // ====================================

      _followUpDate = arguments.followUpDate;

      // ====================================
      // RESTORE EXISTING TEXT
      // ====================================

      _reasonController.text =
          arguments.reason;

      _symptomsController.text =
          arguments.symptoms;

      _diagnosisController.text =
          arguments.diagnosis;

      _notesController.text =
          arguments.notes;

      // ====================================
      // INITIALIZE DATE AND TIME IN DRAFT
      // ====================================

      arguments.visitDate = _visitDate;
      arguments.visitTime = _visitTime;
    } catch (_) {
      _draft = null;
      _draftGeneration = null;

      _draftError =
      'This medical visit belongs to '
          'an expired or different Google '
          'account session. Start a new visit.';
    }
  }

  // ======================================
  // CHECK ACCOUNT SESSION AND DRAFT
  // ======================================

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

  // ======================================
  // CLEAR EXPIRED FORM DATA
  // ======================================

  void _invalidateDraft() {
    if (!mounted) {
      return;
    }

    // Remove sensitive form content from
    // controllers and the current widget.

    _reasonController.clear();
    _symptomsController.clear();
    _diagnosisController.clear();
    _notesController.clear();

    setState(() {
      _draft = null;
      _draftGeneration = null;
      _followUpDate = null;

      _draftError =
      'Your Google account session '
          'has changed. This medical visit '
          'cannot be continued. Please '
          'start a new visit.';
    });
  }

  // ======================================
  // ENSURE DRAFT IS CURRENT
  // ======================================

  bool _ensureCurrentDraft() {
    if (_isCurrentDraft) {
      return true;
    }

    _invalidateDraft();

    return false;
  }

  // ======================================
  // REFRESH AFTER APP RESUMES
  // ======================================

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

  // ======================================
  // DISPOSE
  // ======================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _reasonController.dispose();
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  // ======================================
  // SHOW TEMPORARY MESSAGE
  // ======================================

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

  // ======================================
  // FORMAT DATE
  // ======================================

  String _formatDate(DateTime date) {
    final day =
    date.day.toString().padLeft(2, '0');

    final month = _months[date.month - 1];

    return '$day $month ${date.year}';
  }

  // ======================================
  // NORMALIZE DATE FOR COMPARISON
  // ======================================

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // ======================================
  // SELECT VISIT DATE
  // ======================================

  Future<void> _selectVisitDate() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    final today = _dateOnly(DateTime.now());

    final firstAllowed = DateTime(1900);

    // Ensure an old or unexpected stored
    // date cannot break the date picker.

    DateTime initial = _dateOnly(_visitDate);

    if (initial.isAfter(today)) {
      initial = today;
    }

    if (initial.isBefore(firstAllowed)) {
      initial = firstAllowed;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstAllowed,
      lastDate: today,
      helpText: 'SELECT VISIT DATE',
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    // The user may have signed out while
    // the date picker was open.

    if (!_ensureCurrentDraft()) {
      return;
    }

    final normalizedDate =
    _dateOnly(selectedDate);

    setState(() {
      _visitDate = normalizedDate;

      _draft!.visitDate = normalizedDate;

      // Clear a follow-up date that is now
      // earlier than the selected visit date.

      if (_followUpDate != null &&
          _dateOnly(_followUpDate!)
              .isBefore(normalizedDate)) {
        _followUpDate = null;
        _draft!.followUpDate = null;
      }
    });
  }

  // ======================================
  // SELECT VISIT TIME
  // ======================================

  Future<void> _selectVisitTime() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _visitTime,
      helpText: 'SELECT VISIT TIME',
    );

    if (!mounted || selectedTime == null) {
      return;
    }

    if (!_ensureCurrentDraft()) {
      return;
    }

    setState(() {
      _visitTime = selectedTime;

      _draft!.visitTime = selectedTime;
    });
  }

  // ======================================
  // SELECT FOLLOW-UP DATE
  // ======================================

  Future<void> _selectFollowUpDate() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    final firstAllowed =
    _dateOnly(_visitDate);

    final lastAllowed =
    _dateOnly(DateTime.now()).add(
      const Duration(days: 3650),
    );

    DateTime initial =
    _dateOnly(
      _followUpDate ?? DateTime.now(),
    );

    // Keep the initial date inside the
    // supported date-picker range.

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
      helpText: 'SELECT FOLLOW-UP DATE',
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    if (!_ensureCurrentDraft()) {
      return;
    }

    setState(() {
      _followUpDate =
          _dateOnly(selectedDate);

      _draft!.followUpDate =
          _followUpDate;
    });
  }

  // ======================================
  // CLEAR FOLLOW-UP DATE
  // ======================================

  void _clearFollowUpDate() {
    if (!_ensureCurrentDraft()) {
      return;
    }

    setState(() {
      _followUpDate = null;
      _draft!.followUpDate = null;
    });
  }

  // ======================================
  // SAVE TEXT CHANGES TO DRAFT
  // ======================================

  void _updateTextField(
      String field,
      String value,
      ) {
    if (!_ensureCurrentDraft()) {
      return;
    }

    final draft = _draft!;

    switch (field) {
      case 'reason':
        draft.reason = value;
        break;

      case 'symptoms':
        draft.symptoms = value;
        break;

      case 'diagnosis':
        draft.diagnosis = value;
        break;

      case 'notes':
        draft.notes = value;
        break;
    }
  }

  // ======================================
  // SAVE ALL VISIT INFORMATION TO DRAFT
  // ======================================

  bool _updateVisitDraft() {
    if (!_ensureCurrentDraft()) {
      return false;
    }

    final draft = _draft!;

    draft.visitDate = _visitDate;
    draft.visitTime = _visitTime;

    draft.reason =
        _reasonController.text.trim();

    draft.symptoms =
        _symptomsController.text.trim();

    draft.diagnosis =
        _diagnosisController.text.trim();

    draft.notes =
        _notesController.text.trim();

    draft.followUpDate = _followUpDate;

    return true;
  }

  // ======================================
  // CONTINUE TO STEP 4 - MEDICINES
  // ======================================

  void _continue() {
    // ====================================
    // VERIFY ACCOUNT AND DRAFT
    // ====================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ====================================
    // VALIDATE REASON FOR VISIT
    // ====================================

    if (!(_formKey.currentState?.validate() ??
        false)) {
      return;
    }

    // ====================================
    // UPDATE SHARED DRAFT
    // ====================================

    if (!_updateVisitDraft()) {
      return;
    }

    // ====================================
    // VERIFY AGAIN BEFORE NAVIGATION
    // ====================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    final draft = _draft!;

    FocusScope.of(context).unfocus();

    // ====================================
    // NAVIGATE TO MEDICINES
    // ====================================

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          arguments: draft,
        ),

        // Preserve Step 4 constructor.
        builder: (_) => MedicinesStepScreen(
          doctorId: draft.doctorId,
          doctorName: draft.doctorName,
          hospitalName: draft.hospitalName,
          hospitalAddress:
          draft.hospitalAddress,
          visitDate: _visitDate,
          visitTime: _visitTime,
          reason: draft.reason,
          symptoms: draft.symptoms,
          diagnosis: draft.diagnosis,
          notes: draft.notes,
          followUpDate:
          draft.followUpDate,
        ),
      ),
    );
  }

  // ======================================
  // GO BACK TO LOCATION
  // ======================================

  void _goBack() {
    // Preserve changes only if the
    // original account session is valid.

    if (_isCurrentDraft) {
      _updateVisitDraft();
    }

    Navigator.of(context).maybePop();
  }

  // ======================================
  // REUSABLE DATE AND TIME PICKER FIELD
  // ======================================

  Widget _buildPickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(14),

      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(
            Icons.arrow_drop_down,
          ),
        ),

        child: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ======================================
  // EXPIRED SESSION SCREEN
  // ======================================

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
              mainAxisSize:
              MainAxisSize.min,

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
                      'This visit belongs to an '
                          'expired account session. '
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

  // ======================================
  // MAIN VISIT INFORMATION SCREEN
  // ======================================

  @override
  Widget build(BuildContext context) {
    // Never render the doctor's information
    // if the session or draft has expired.

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

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: ListView(
            padding: const EdgeInsets.all(20),

            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,

            children: [
              // ==============================
              // STEP INDICATOR
              // ==============================

              const Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    'Step 3 of 7',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Text(
                    'Visit Information',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const LinearProgressIndicator(
                value: 3 / 7,
                minHeight: 6,
                borderRadius: BorderRadius.all(
                  Radius.circular(6),
                ),
              ),

              const SizedBox(height: 27),

              // ==============================
              // SCREEN TITLE
              // ==============================

              const Text(
                'Visit Details',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Record what happened during '
                    'your medical visit.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // ==============================
              // DOCTOR AND HOSPITAL SUMMARY
              // ==============================

              Card(
                child: Padding(
                  padding:
                  const EdgeInsets.all(16),

                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      const CircleAvatar(
                        backgroundColor:
                        AppColors.doctorsLight,

                        child: Icon(
                          Icons.medical_services_outlined,
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
                                fontSize: 15,
                                fontWeight:
                                FontWeight.w700,
                                color:
                                AppColors.textPrimary,
                              ),
                            ),

                            if (draft
                                .doctorSpecialization
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

                            const SizedBox(height: 8),

                            Text(
                              draft.hospitalName,
                              style: const TextStyle(
                                fontSize: 13,
                                color:
                                AppColors.textSecondary,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              draft.hospitalAddress,
                              maxLines: 3,
                              overflow:
                              TextOverflow.ellipsis,

                              style: const TextStyle(
                                fontSize: 12,
                                color:
                                AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ==============================
              // VISIT DATE
              // ==============================

              _buildPickerField(
                label: 'Visit Date',
                value: _formatDate(_visitDate),
                icon: Icons.calendar_today_outlined,
                onTap: _selectVisitDate,
              ),

              const SizedBox(height: 16),

              // ==============================
              // VISIT TIME
              // ==============================

              _buildPickerField(
                label: 'Visit Time',
                value: _visitTime.format(context),
                icon: Icons.access_time_outlined,
                onTap: _selectVisitTime,
              ),

              const SizedBox(height: 20),

              // ==============================
              // REASON FOR VISIT
              // ==============================

              TextFormField(
                controller: _reasonController,

                textCapitalization:
                TextCapitalization.sentences,

                decoration: const InputDecoration(
                  labelText: 'Reason for Visit *',
                  hintText: 'e.g. Routine consultation',
                  prefixIcon: Icon(
                    Icons.edit_note_outlined,
                  ),
                ),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter a reason '
                        'for your visit';
                  }
                  return null;
                },

                onChanged: (value) {
                  _updateTextField(
                    'reason',
                    value,
                  );
                },
              ),

              const SizedBox(height: 16),

              // ==============================
              // SYMPTOMS
              // ==============================

              TextFormField(
                controller: _symptomsController,

                minLines: 2,
                maxLines: 3,

                textCapitalization:
                TextCapitalization.sentences,

                decoration: const InputDecoration(
                  labelText: 'Symptoms',
                  hintText:
                  'Describe the symptoms '
                      'you experienced...',
                  alignLabelWithHint: true,
                ),

                onChanged: (value) {
                  _updateTextField(
                    'symptoms',
                    value,
                  );
                },
              ),

              const SizedBox(height: 16),

              // ==============================
              // DIAGNOSIS
              // ==============================

              TextFormField(
                controller: _diagnosisController,

                minLines: 2,
                maxLines: 3,

                textCapitalization:
                TextCapitalization.sentences,

                decoration: const InputDecoration(
                  labelText: 'Diagnosis',
                  hintText:
                  'Enter the diagnosis '
                      'given by the doctor...',
                  alignLabelWithHint: true,
                ),

                onChanged: (value) {
                  _updateTextField(
                    'diagnosis',
                    value,
                  );
                },
              ),

              const SizedBox(height: 16),

              // ==============================
              // DOCTOR'S NOTES
              // ==============================

              TextFormField(
                controller: _notesController,

                minLines: 2,
                maxLines: 4,

                textCapitalization:
                TextCapitalization.sentences,

                decoration: const InputDecoration(
                  labelText: "Doctor's Notes",
                  hintText:
                  'Additional instructions '
                      'or advice...',
                  alignLabelWithHint: true,
                ),

                onChanged: (value) {
                  _updateTextField(
                    'notes',
                    value,
                  );
                },
              ),

              const SizedBox(height: 24),

              // ==============================
              // FOLLOW-UP DATE
              // ==============================

              _buildPickerField(
                label:
                'Follow-up Date (Optional)',

                value: _followUpDate == null
                    ? 'Not scheduled'
                    : _formatDate(
                  _followUpDate!,
                ),

                icon: Icons.event_available_outlined,
                onTap: _selectFollowUpDate,
              ),

              if (_followUpDate != null) ...[
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,

                  child: TextButton.icon(
                    onPressed: _clearFollowUpDate,
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                    ),
                    label: const Text(
                      'Clear Follow-up',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // ====================================
      // BACK AND NEXT BUTTONS
      // ====================================

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
                    'Next: Medicines',
                    textAlign: TextAlign.center,
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


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../models/visit_draft.dart';
import '../../services/medical_visit_save_service.dart';

import 'medical_tests_step_screen.dart';

// ============================================
// MY MEDICAL HISTORY
// STEP 44.14 - ACCOUNT-BOUND MEDICINES
// STEP 4 OF 7
// ============================================

class MedicinesStepScreen extends StatefulWidget {
  // Existing constructor fields are preserved
  // for compatibility with Step 3.

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

  const MedicinesStepScreen({
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
  });

  @override
  State<MedicinesStepScreen> createState() =>
      _MedicinesStepScreenState();
}

class _MedicinesStepScreenState
    extends State<MedicinesStepScreen>
    with WidgetsBindingObserver {

  // ========================================
  // ACCOUNT-BOUND SHARED VISIT DRAFT
  // ========================================

  VisitDraft? _draft;

  int? _draftGeneration;

  bool _draftInitialized = false;

  String? _draftError;

  // ========================================
  // DATABASE SESSION SERVICE
  // ========================================

  final MedicalVisitSaveService _saveService =
      MedicalVisitSaveService.instance;

  // ========================================
  // SAVED MEDICINES IN SHARED DRAFT
  // ========================================

  List<MedicineDraft> get _medicines =>
      _draft!.medicines;

  // ========================================
  // FORM AND SCROLL CONTROLLERS
  // ========================================

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final ScrollController _scrollController =
  ScrollController();

  // ========================================
  // MEDICINE INPUT CONTROLLERS
  // ========================================

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _doseController =
  TextEditingController();

  final TextEditingController _durationController =
  TextEditingController();

  final TextEditingController
  _instructionsController =
  TextEditingController();

  // ========================================
  // SELECTED FREQUENCY AND MEAL TIMING
  // ========================================

  String _frequency = 'Once daily';

  String _mealTiming = 'Any time';

  // ========================================
  // MEDICINE IDs
  // ========================================

  int _nextId = 1;

  int? _editingMedicineId;

  int _formVersion = 0;

  // ========================================
  // FREQUENCY OPTIONS
  // ========================================

  static const List<String> _frequencyOptions = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Four times daily',
    'As needed',
  ];

  // ========================================
  // MEAL TIMING OPTIONS
  // ========================================

  static const List<String> _mealOptions = [
    'Any time',
    'Before meal',
    'After meal',
    'With meal',
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
  // RECEIVE SHARED VISIT DRAFT
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

    // Never create a replacement draft here.
    //
    // Step 1 creates the draft and binds
    // it to the current Google account.
    //
    // Creating a new draft at Step 4 would
    // bypass the ownership established
    // earlier in the visit form.

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
      // VERIFY ACTIVE ACCOUNT
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

      // This checks the original draft.
      // It does not register a new owner.

      _saveService.verifyDraftForCurrentSession(
        arguments,
      );

      _draft = arguments;
      _draftGeneration = generation;

      // ====================================
      // FIND NEXT AVAILABLE MEDICINE ID
      // ====================================

      // Existing medicines may already
      // be present when returning to Step 4.
      //
      // Never overwrite an existing ID.

      for (final medicine in arguments.medicines) {
        if (medicine.id >= _nextId) {
          _nextId = medicine.id + 1;
        }
      }
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
  // VERIFY CURRENT DRAFT
  // ========================================

  bool get _isCurrentDraft {
    final draft = _draft;
    final generation = _draftGeneration;

    if (draft == null || generation == null) {
      return false;
    }

    // Check if account changed or signed out.
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

    // Clear sensitive unsaved form input.
    _nameController.clear();
    _doseController.clear();
    _durationController.clear();
    _instructionsController.clear();

    setState(() {
      _draft = null;
      _draftGeneration = null;

      _editingMedicineId = null;
      _frequency = 'Once daily';
      _mealTiming = 'Any time';

      _draftError =
      'Your Google account session '
          'has changed. This medicine form '
          'cannot be continued. Please '
          'start a new medical visit.';
    });
  }

  // ========================================
  // CHECK BEFORE FORM ACTIONS
  // ========================================

  bool _ensureCurrentDraft() {
    if (_isCurrentDraft) {
      return true;
    }

    _invalidateDraft();

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

    _nameController.dispose();
    _doseController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();

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
  // REQUIRED FIELD VALIDATION
  // ========================================

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  // ========================================
  // DURATION VALIDATION
  // ========================================

  String? _validateDuration(String? value) {
    final days = int.tryParse(
      value?.trim() ?? '',
    );

    if (days == null || days <= 0) {
      return 'Enter a valid number of days';
    }

    return null;
  }

  // ========================================
  // ADD OR UPDATE MEDICINE
  // ========================================

  void _addOrUpdateMedicine() {
    // ======================================
    // VERIFY ACCOUNT FIRST
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // VALIDATE REQUIRED FIELDS
    // ======================================

    if (!(_formKey.currentState?.validate() ??
        false)) {
      return;
    }

    // ======================================
    // DETERMINE ADD OR EDIT
    // ======================================

    final isEditing =
        _editingMedicineId != null;

    final medicineId =
        _editingMedicineId ?? _nextId;

    // ======================================
    // CREATE MEDICINE DRAFT
    // ======================================

    final medicine = MedicineDraft(
      id: medicineId,

      name: _nameController.text.trim(),

      dose: _doseController.text.trim(),

      frequency: _frequency,

      durationDays: int.parse(
        _durationController.text.trim(),
      ),

      mealTiming: _mealTiming,

      instructions:
      _instructionsController.text.trim(),
    );

    // ======================================
    // CHECK ACCOUNT AGAIN
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    if (isEditing) {
      // ====================================
      // UPDATE EXISTING MEDICINE
      // ====================================

      final index = _medicines.indexWhere(
            (item) => item.id == _editingMedicineId,
      );

      if (index == -1) {
        _showMessage(
          'Medicine could not be found. '
              'Please try again.',
        );

        _clearForm();
        return;
      }

      setState(() {
        _medicines[index] = medicine;
      });
    } else {
      // ====================================
      // ADD NEW MEDICINE
      // ====================================

      setState(() {
        _medicines.add(medicine);

        _nextId++;
      });
    }

    // ======================================
    // RESET FORM
    // ======================================

    _clearForm();

    FocusScope.of(context).unfocus();

    _showMessage(
      isEditing
          ? 'Medicine updated in visit draft.'
          : 'Medicine added to visit draft.',
    );
  }

  // ========================================
  // CLEAR MEDICINE FORM
  // ========================================

  void _clearForm() {
    if (!_ensureCurrentDraft()) {
      return;
    }

    _formKey.currentState?.reset();

    _nameController.clear();
    _doseController.clear();
    _durationController.clear();
    _instructionsController.clear();

    setState(() {
      _editingMedicineId = null;

      _frequency = 'Once daily';
      _mealTiming = 'Any time';

      // Recreate dropdown fields so their
      // displayed values match the state.
      _formVersion++;
    });
  }

  // ========================================
  // EDIT EXISTING MEDICINE
  // ========================================

  void _editMedicine(
      MedicineDraft medicine,
      ) {
    if (!_ensureCurrentDraft()) {
      return;
    }

    // Locate the currently saved draft item.
    final exists = _medicines.any(
          (item) => item.id == medicine.id,
    );

    if (!exists) {
      _showMessage(
        'Medicine no longer exists '
            'in this draft.',
      );

      return;
    }

    _nameController.text = medicine.name;
    _doseController.text = medicine.dose;

    _durationController.text =
        medicine.durationDays.toString();

    _instructionsController.text =
        medicine.instructions;

    setState(() {
      _editingMedicineId = medicine.id;

      // Ensure older unexpected values
      // cannot cause dropdown assertions.
      _frequency =
      _frequencyOptions.contains(
        medicine.frequency,
      )
          ? medicine.frequency
          : 'Once daily';

      _mealTiming =
      _mealOptions.contains(
        medicine.mealTiming,
      )
          ? medicine.mealTiming
          : 'Any time';

      _formVersion++;
    });

    // ======================================
    // SCROLL TO ENTRY FORM
    // ======================================

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
  // REMOVE MEDICINE
  // ========================================

  void _removeMedicine(int medicineId) {
    if (!_ensureCurrentDraft()) {
      return;
    }

    final exists = _medicines.any(
          (medicine) => medicine.id == medicineId,
    );

    if (!exists) {
      return;
    }

    setState(() {
      _medicines.removeWhere(
            (medicine) => medicine.id == medicineId,
      );
    });

    // If removing the medicine currently
    // being edited, reset the entry form.
    if (_editingMedicineId == medicineId) {
      _clearForm();
    }

    _showMessage(
      'Medicine removed from visit draft.',
    );
  }

  // ========================================
  // CHECK UNFINISHED MEDICINE INPUT
  // ========================================

  bool get _hasPendingInput {
    return _editingMedicineId != null ||
        _nameController.text.trim().isNotEmpty ||
        _doseController.text.trim().isNotEmpty ||
        _durationController.text.trim().isNotEmpty ||
        _instructionsController.text
            .trim()
            .isNotEmpty ||
        _frequency != 'Once daily' ||
        _mealTiming != 'Any time';
  }

  // ========================================
  // CONTINUE TO MEDICAL TESTS
  // ========================================

  void _continue() {
    // ======================================
    // VERIFY DRAFT OWNERSHIP
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // PREVENT LOSING UNFINISHED ENTRY
    // ======================================

    if (_hasPendingInput) {
      _showMessage(
        'Please add or update this medicine, '
            'or clear the form before continuing.',
      );

      return;
    }

    final draft = _draft!;

    // ======================================
    // VALIDATE VISIT DATE AND TIME
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

    FocusScope.of(context).unfocus();

    // ======================================
    // PRESERVE STEP 5 COMPATIBILITY
    // ======================================

    // The existing MedicalTestsStepScreen
    // constructor expects medicine maps.
    //
    // The original VisitDraft remains the
    // source of truth for medicines.

    final medicineMaps = draft.medicines
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

    // ======================================
    // VERIFY SESSION BEFORE NAVIGATION
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // OPEN STEP 5 - MEDICAL TESTS
    // ======================================

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          arguments: draft,
        ),

        // Preserve Step 5 constructor.
        builder: (_) => MedicalTestsStepScreen(
          doctorId: draft.doctorId,
          doctorName: draft.doctorName,
          hospitalName: draft.hospitalName,
          hospitalAddress:
          draft.hospitalAddress,

          visitDate: visitDate,
          visitTime: visitTime,

          reason: draft.reason,
          symptoms: draft.symptoms,
          diagnosis: draft.diagnosis,
          notes: draft.notes,

          followUpDate: draft.followUpDate,

          medicines: medicineMaps,
        ),
      ),
    );
  }

  // ========================================
  // BACK TO VISIT INFORMATION
  // ========================================

  void _goBack() {
    Navigator.of(context).maybePop();
  }

  // ========================================
  // DOCTOR AND VISIT SUMMARY
  // ========================================

  Widget _buildVisitSummary(
      VisitDraft draft,
      ) {
    final visitDate = draft.visitDate;

    final dateText = visitDate == null
        ? 'Not selected'
        : '${visitDate.day.toString().padLeft(2, '0')}/'
        '${visitDate.month.toString().padLeft(2, '0')}/'
        '${visitDate.year}';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),

        leading: const CircleAvatar(
          backgroundColor: AppColors.doctorsLight,
          child: Icon(
            Icons.medical_services_outlined,
            color: AppColors.doctors,
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
                'Visit: $dateText',
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
  // BUILD MEDICINE ENTRY FORM
  // ========================================

  Widget _buildMedicineForm() {
    return Form(
      key: _formKey,

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            _editingMedicineId == null
                ? 'Add a Medicine'
                : 'Edit Medicine',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          // ==================================
          // MEDICINE NAME
          // ==================================

          TextFormField(
            controller: _nameController,

            textCapitalization:
            TextCapitalization.words,

            decoration: const InputDecoration(
              labelText: 'Medicine Name *',
              hintText: 'Enter medicine name',
              prefixIcon: Icon(
                Icons.medication_outlined,
              ),
            ),

            validator: _requiredField,
          ),

          const SizedBox(height: 14),

          // ==================================
          // DOSAGE
          // ==================================

          TextFormField(
            controller: _doseController,

            decoration: const InputDecoration(
              labelText: 'Dosage *',
              hintText: 'e.g. 500 mg or 1 tablet',
              prefixIcon: Icon(
                Icons.medical_information_outlined,
              ),
            ),

            validator: _requiredField,
          ),

          const SizedBox(height: 14),

          // ==================================
          // FREQUENCY
          // ==================================

          DropdownButtonFormField<String>(
            key: ValueKey(
              'frequency_$_formVersion',
            ),
            initialValue: _frequency,
            isExpanded: true,

            decoration: const InputDecoration(
              labelText: 'Frequency',
              prefixIcon: Icon(
                Icons.schedule_outlined,
              ),
            ),

            items: _frequencyOptions.map(
                  (option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              },
            ).toList(),

            onChanged: (value) {
              if (!_ensureCurrentDraft()) {
                return;
              }

              if (value != null) {
                setState(() {
                  _frequency = value;
                });
              }
            },
          ),

          const SizedBox(height: 14),

          // ==================================
          // DURATION
          // ==================================

          TextFormField(
            controller: _durationController,

            keyboardType: TextInputType.number,

            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],

            decoration: const InputDecoration(
              labelText: 'Duration (Days) *',
              hintText: 'Enter number of days',
              prefixIcon: Icon(
                Icons.calendar_today_outlined,
              ),
            ),

            validator: _validateDuration,
          ),

          const SizedBox(height: 14),

          // ==================================
          // MEAL TIMING
          // ==================================

          DropdownButtonFormField<String>(
            key: ValueKey(
              'meal_$_formVersion',
            ),
            initialValue: _mealTiming,
            isExpanded: true,

            decoration: const InputDecoration(
              labelText: 'Meal Timing',
              prefixIcon: Icon(
                Icons.restaurant_outlined,
              ),
            ),

            items: _mealOptions.map(
                  (option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              },
            ).toList(),

            onChanged: (value) {
              if (!_ensureCurrentDraft()) {
                return;
              }

              if (value != null) {
                setState(() {
                  _mealTiming = value;
                });
              }
            },
          ),

          const SizedBox(height: 14),

          // ==================================
          // INSTRUCTIONS
          // ==================================

          TextFormField(
            controller: _instructionsController,

            minLines: 2,
            maxLines: 3,

            textCapitalization:
            TextCapitalization.sentences,

            decoration: const InputDecoration(
              labelText: 'Instructions (Optional)',
              hintText:
              'Enter instructions from '
                  'the prescription',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 18),

          // ==================================
          // ADD OR UPDATE MEDICINE
          // ==================================

          SizedBox(
            width: double.infinity,

            child: FilledButton.icon(
              onPressed: _addOrUpdateMedicine,

              icon: Icon(
                _editingMedicineId == null
                    ? Icons.add
                    : Icons.check,
              ),

              label: Text(
                _editingMedicineId == null
                    ? 'Add Medicine'
                    : 'Update Medicine',
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: TextButton(
              onPressed: _clearForm,
              child: const Text('Clear Form'),
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
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================================
  // MAIN MEDICINES SCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    // Do not display saved doctor or medicine
    // details if the session has expired.

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

          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,

          padding: const EdgeInsets.all(18),

          children: [
            // =================================
            // STEP PROGRESS
            // =================================

            const Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  'Step 4 of 7',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  'Medicines',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const LinearProgressIndicator(
              value: 4 / 7,
              minHeight: 6,

              borderRadius: BorderRadius.all(
                Radius.circular(6),
              ),
            ),

            const SizedBox(height: 25),

            // =================================
            // PAGE TITLE
            // =================================

            const Text(
              'Prescribed Medicines',

              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Add medicines recorded on your '
                  'prescription. You can add more '
                  'than one medicine.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // =================================
            // DOCTOR AND VISIT SUMMARY
            // =================================

            _buildVisitSummary(draft),

            const SizedBox(height: 14),

            Text(
              '${_medicines.length} medicines '
                  'in this visit draft',

              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 25),

            // =================================
            // MEDICINE ENTRY
            // =================================

            _buildMedicineForm(),

            const SizedBox(height: 26),

            // =================================
            // ADDED MEDICINES HEADING
            // =================================

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Medicines Added',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                Text(
                  '${_medicines.length} total',
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
            // EMPTY MEDICINES STATE
            // =================================

            if (_medicines.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),

                  child: Column(
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 42,
                        color: AppColors.textSecondary,
                      ),

                      SizedBox(height: 12),

                      Text(
                        'No medicines added yet.',
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 7),

                      Text(
                        'You can continue if no '
                            'medicines were prescribed.',
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
            // EXISTING MEDICINE CARDS
            // =================================

            for (final medicine in _medicines) ...[
              _MedicineCard(
                key: ValueKey(medicine.id),
                medicine: medicine,

                onEdit: () {
                  _editMedicine(medicine);
                },

                onDelete: () {
                  _removeMedicine(medicine.id);
                },
              ),

              const SizedBox(height: 10),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),

      // ===================================
      // BACK AND NEXT NAVIGATION
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
                    'Next: Tests',
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

// ============================================
// PROFESSIONAL MEDICINE CARD
// ============================================

class _MedicineCard extends StatelessWidget {
  final MedicineDraft medicine;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicineCard({
    super.key,
    required this.medicine,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                const CircleAvatar(
                  backgroundColor:
                  AppColors.medicinesLight,

                  child: Icon(
                    Icons.medication_outlined,
                    color: AppColors.medicines,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Padding(
                    padding:
                    const EdgeInsets.only(top: 8),

                    child: Text(
                      medicine.name,

                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Edit medicine',
                  onPressed: onEdit,

                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                  ),
                ),

                IconButton(
                  tooltip: 'Remove medicine',
                  onPressed: onDelete,

                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            Wrap(
              spacing: 8,
              runSpacing: 7,

              children: [
                Chip(
                  label: Text(medicine.dose),
                ),

                Chip(
                  label: Text(
                    medicine.frequency,
                  ),
                ),

                Chip(
                  label: Text(
                    '${medicine.durationDays} days',
                  ),
                ),

                Chip(
                  label: Text(
                    medicine.mealTiming,
                  ),
                ),
              ],
            ),

            if (medicine.instructions
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 11),

              Text(
                medicine.instructions,

                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

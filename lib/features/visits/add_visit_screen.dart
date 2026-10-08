
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../models/visit_draft.dart';
import '../../services/medical_history_read_service.dart';
import '../../services/medical_visit_save_service.dart';

import 'location_step_screen.dart';

// ==========================================
// MY MEDICAL HISTORY
// STEP 44.11 - ACCOUNT-BOUND ADD VISIT
// ==========================================

class AddVisitScreen extends StatefulWidget {
  final String? initialDoctorId;

  const AddVisitScreen({
    super.key,
    this.initialDoctorId,
  });

  @override
  State<AddVisitScreen> createState() =>
      _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  // ======================================
  // SHARED SEVEN-STEP VISIT DRAFT
  // ======================================

  late final VisitDraft _draft;

  // The account session that created
  // this particular medical visit form.
  late final int _draftGeneration;

  bool get _isCurrentSession =>
      AppDatabase.instance.isSessionCurrent(
        _draftGeneration,
      );

  // ======================================
  // DATABASE SERVICES
  // ======================================

  final MedicalHistoryReadService _readService =
      MedicalHistoryReadService.instance;

  final MedicalVisitSaveService _saveService =
      MedicalVisitSaveService.instance;

  // ======================================
  // DOCTOR DATA
  // ======================================

  List<SavedDoctorRecord> _doctors = [];

  bool _isLoadingDoctors = true;
  String? _doctorsLoadError;

  bool _preselectedDoctorMissing = false;

  int _loadGeneration = 0;

  // ======================================
  // DOCTOR SELECTION
  // ======================================

  bool _useExistingDoctor = true;
  String? _selectedDoctorId;

  // ======================================
  // NEW DOCTOR FORM
  // ======================================

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController
  _specializationController =
  TextEditingController();

  final TextEditingController _phoneController =
  TextEditingController();

  final TextEditingController _hospitalController =
  TextEditingController();

  // ======================================
  // INITIALIZE
  // ======================================

  @override
  void initState() {
    super.initState();

    // Capture this account session once.
    _draftGeneration =
        AppDatabase.instance.sessionGeneration;

    // The same draft travels through
    // all seven steps.
    _draft = VisitDraft();

    if (_isCurrentSession) {
      // Bind draft ownership to this session.
      _saveService.bindDraftToCurrentSession(
        _draft,
      );

      // Load saved doctors from this account.
      _loadDoctors();
    } else {
      _isLoadingDoctors = false;
      _doctorsLoadError =
      'Medical storage is locked. '
          'Please sign in again.';
    }
  }

  // ======================================
  // DISPOSE
  // ======================================

  @override
  void dispose() {
    _loadGeneration++;

    _nameController.dispose();
    _specializationController.dispose();
    _phoneController.dispose();
    _hospitalController.dispose();

    super.dispose();
  }

  // ======================================
  // LOAD SAVED DOCTORS
  // ======================================

  Future<void> _loadDoctors() async {
    if (!mounted || !_isCurrentSession) {
      return;
    }

    final generation = ++_loadGeneration;

    setState(() {
      _isLoadingDoctors = true;
      _doctorsLoadError = null;
    });

    try {
      final savedDoctors =
      await _readService.getDoctors();

      // Reject an outdated load if the
      // account changed during the query.
      if (!mounted ||
          !_isCurrentSession ||
          generation != _loadGeneration) {
        return;
      }

      final requestedId =
      widget.initialDoctorId?.trim();

      final hasRequestedId =
          requestedId != null &&
              requestedId.isNotEmpty;

      final previousId = _selectedDoctorId;

      final previousIsValid =
          previousId != null &&
              savedDoctors.any(
                    (doctor) => doctor.id == previousId,
              );

      final requestedIsValid =
          hasRequestedId &&
              savedDoctors.any(
                    (doctor) => doctor.id == requestedId,
              );

      setState(() {
        _doctors = savedDoctors;

        if (previousIsValid) {
          _selectedDoctorId = previousId;
        } else if (requestedIsValid) {
          _selectedDoctorId = requestedId;
        } else {
          _selectedDoctorId = null;
        }

        _preselectedDoctorMissing =
            hasRequestedId &&
                !requestedIsValid &&
                _selectedDoctorId == null;

        if (savedDoctors.isEmpty &&
            !hasRequestedId) {
          _useExistingDoctor = false;
        }
      });
    } catch (_) {
      if (!mounted ||
          !_isCurrentSession ||
          generation != _loadGeneration) {
        return;
      }

      setState(() {
        _doctorsLoadError =
        'Unable to load saved doctors. '
            'Please try again.';
      });
    } finally {
      if (mounted &&
          _isCurrentSession &&
          generation == _loadGeneration) {
        setState(() {
          _isLoadingDoctors = false;
        });
      }
    }
  }

  // ======================================
  // SELECTED EXISTING DOCTOR
  // ======================================

  SavedDoctorRecord? get _selectedDoctor {
    for (final doctor in _doctors) {
      if (doctor.id == _selectedDoctorId) {
        return doctor;
      }
    }

    return null;
  }

  // ======================================
  // DOCTOR INITIALS
  // ======================================

  String _getInitials(String name) {
    final cleaned = name.trim().replaceFirst(
      RegExp(
        r'^(Dr\.?|Doctor)\s+',
        caseSensitive: false,
      ),
      '',
    );

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'DR';

    if (words.length == 1) {
      return words.first[0].toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'
        .toUpperCase();
  }

  // ======================================
  // MESSAGE HELPER
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
  // FORM VALIDATION
  // ======================================

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  // ======================================
  // VERIFY DRAFT ACCOUNT OWNERSHIP
  // ======================================

  bool _checkDraftSession() {
    if (!_isCurrentSession) {
      _showMessage(
        'Your Google account session changed. '
            'Close this form and start a new visit.',
      );

      return false;
    }

    return true;
  }

  // ======================================
  // EXISTING DOCTOR TO DRAFT
  // ======================================

  bool _saveExistingDoctorToDraft() {
    if (!_checkDraftSession()) return false;

    if (_isLoadingDoctors ||
        _doctorsLoadError != null) {
      _showMessage(
        'Please wait until your saved '
            'doctors load successfully.',
      );

      return false;
    }

    final doctor = _selectedDoctor;

    if (doctor == null) {
      _showMessage(
        'Please select a saved doctor.',
      );

      return false;
    }

    // Preserve the exact doctor ID
    // from the selected account database.
    _draft.doctorId = doctor.id;
    _draft.doctorName = doctor.name;

    _draft.doctorSpecialization =
        doctor.specialization;

    _draft.doctorPhone = doctor.phone;
    _draft.hospitalName = doctor.hospitalName;

    // Unencrypted photo storage
    // is not enabled yet.
    _draft.doctorPhotoPath = null;
    _draft.hospitalPhotoPath = null;

    return true;
  }

  // ======================================
  // NEW DOCTOR TO DRAFT
  // ======================================

  bool _saveNewDoctorToDraft() {
    if (!_checkDraftSession()) return false;

    if (!(_formKey.currentState?.validate() ??
        false)) {
      return false;
    }

    if (_isLoadingDoctors ||
        _doctorsLoadError != null) {
      _showMessage(
        'Please load the saved doctor '
            'list before continuing.',
      );

      return false;
    }

    final enteredName =
    _nameController.text.trim().toLowerCase();

    final enteredPhone =
    _phoneController.text.replaceAll(
      RegExp(r'\s+'),
      '',
    );

    // Avoid an exact duplicate doctor.
    final alreadySaved = _doctors.any((doctor) {
      final savedName =
      doctor.name.trim().toLowerCase();

      final savedPhone =
      doctor.phone.replaceAll(
        RegExp(r'\s+'),
        '',
      );

      return savedName == enteredName &&
          savedPhone == enteredPhone;
    });

    if (alreadySaved) {
      _showMessage(
        'This doctor is already saved. '
            'Select Existing Doctor instead.',
      );

      return false;
    }

    // The database save service creates
    // a new doctor ID at the final step.
    _draft.doctorId = null;

    _draft.doctorName =
        _nameController.text.trim();

    _draft.doctorSpecialization =
        _specializationController.text.trim();

    _draft.doctorPhone =
        _phoneController.text.trim();

    _draft.hospitalName =
        _hospitalController.text.trim();

    _draft.doctorPhotoPath = null;
    _draft.hospitalPhotoPath = null;

    return true;
  }

  // ======================================
  // CONTINUE TO STEP 2
  // ======================================

  void _continue() {
    if (!_checkDraftSession()) {
      return;
    }

    final isValid = _useExistingDoctor
        ? _saveExistingDoctorToDraft()
        : _saveNewDoctorToDraft();

    if (!isValid) return;

    // Final check before opening Step 2.
    if (!_checkDraftSession()) {
      return;
    }

    FocusScope.of(context).unfocus();

    // The same account-bound draft is
    // passed to the following screens.
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          arguments: _draft,
        ),
        builder: (_) => LocationStepScreen(
          doctorId: _draft.doctorId,
          doctorName: _draft.doctorName,
          hospitalName: _draft.hospitalName,
        ),
      ),
    );
  }

  // ======================================
  // DOCTOR INFORMATION DETAIL ROW
  // ======================================

  Widget _buildDoctorDetail(
      IconData icon,
      String label,
      String value,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
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
              const SizedBox(height: 4),
              Text(
                value.trim().isEmpty
                    ? 'Not provided'
                    : value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ======================================
  // EXISTING DOCTOR SECTION
  // ======================================

  Widget _buildExistingDoctorSection() {
    if (_isLoadingDoctors) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Loading saved doctors...',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_doctorsLoadError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(_doctorsLoadError!),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loadDoctors,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_doctors.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_search_outlined,
                color: AppColors.primary,
                size: 34,
              ),
              const SizedBox(height: 12),
              const Text(
                'No Saved Doctors',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No doctor profiles were found '
                    'in this account. Create a new '
                    'doctor to record your visit.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              if (_preselectedDoctorMissing) ...[
                const SizedBox(height: 12),
                const Text(
                  'The requested doctor is not '
                      'available in this account.',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  if (!_checkDraftSession()) {
                    return;
                  }
                  setState(() {
                    _useExistingDoctor = false;
                  });
                },
                icon: const Icon(
                  Icons.person_add_outlined,
                ),
                label: const Text('Enter New Doctor'),
              ),
            ],
          ),
        ),
      );
    }

    final doctor = _selectedDoctor;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Doctor',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        if (_preselectedDoctorMissing) ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The requested doctor was not '
                          'found. Please choose the '
                          'correct doctor manually.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        DropdownButtonFormField<String>(
          key: ValueKey<String>(
            _selectedDoctorId ?? 'no_doctor',
          ),
          initialValue: _selectedDoctorId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Existing Doctor',
            hintText: 'Choose a saved doctor',
            prefixIcon: Icon(
              Icons.medical_services_outlined,
            ),
          ),
          items: _doctors.map((savedDoctor) {
            return DropdownMenuItem<String>(
              value: savedDoctor.id,
              child: Text(
                savedDoctor.name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (!_checkDraftSession()) {
              return;
            }

            setState(() {
              _selectedDoctorId = value;
              _preselectedDoctorMissing = false;
            });
          },
        ),

        const SizedBox(height: 20),

        if (doctor != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor:
                        AppColors.doctorsLight,
                        child: Text(
                          _getInitials(doctor.name),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.doctors,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color:
                                AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              doctor.specialization,
                              style: const TextStyle(
                                color:
                                AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 15),
                  _buildDoctorDetail(
                    Icons.local_hospital_outlined,
                    'Hospital / Clinic',
                    doctor.hospitalName,
                  ),
                  const SizedBox(height: 16),
                  _buildDoctorDetail(
                    Icons.phone_outlined,
                    'Phone Number',
                    doctor.phone,
                  ),
                ],
              ),
            ),
          )
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select an existing doctor '
                          'to see their information.',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ======================================
  // NEW DOCTOR SECTION
  // ======================================

  Widget _buildNewDoctorSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'New Doctor Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Enter the doctor and hospital details.',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          TextFormField(
            controller: _nameController,
            textCapitalization:
            TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Doctor Name *',
              hintText: 'e.g. Dr. Ahmed Khan',
              prefixIcon: Icon(
                Icons.person_outline,
              ),
            ),
            validator: _requiredField,
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller:
            _specializationController,
            textCapitalization:
            TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Specialization *',
              hintText: 'e.g. Cardiologist',
              prefixIcon: Icon(
                Icons.medical_information_outlined,
              ),
            ),
            validator: _requiredField,
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              hintText: 'Enter doctor phone number',
              prefixIcon: Icon(
                Icons.phone_outlined,
              ),
            ),
            validator: _requiredField,
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _hospitalController,
            textCapitalization:
            TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Hospital / Clinic Name *',
              hintText: 'Enter hospital name',
              prefixIcon: Icon(
                Icons.local_hospital_outlined,
              ),
            ),
            validator: _requiredField,
          ),

          const SizedBox(height: 24),

          const Text(
            'Photos (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showMessage(
                      'Encrypted doctor photo '
                          'storage is not ready yet.',
                    );
                  },
                  icon: const Icon(
                    Icons.person_add_alt_1_outlined,
                  ),
                  label: const Text(
                    'Doctor Photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showMessage(
                      'Encrypted hospital photo '
                          'storage is not ready yet.',
                    );
                  },
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                  ),
                  label: const Text(
                    'Hospital Photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Text(
            'Photo uploads will become available '
                'when secure attachment storage '
                'has been implemented.',
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
  // INVALID ACCOUNT SESSION SCREEN
  // ======================================

  Widget _buildExpiredSessionScreen() {
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
                const Icon(
                  Icons.lock_outline,
                  color: AppColors.error,
                  size: 60,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Account Session Changed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This visit was started under '
                      'a different account session.\n\n'
                      'For your privacy, you cannot '
                      'continue this draft. Please '
                      'open a new visit after signing in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
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

  // ======================================
  // MAIN SCREEN
  // ======================================

  @override
  Widget build(BuildContext context) {
    // Do not show doctor information if the
    // account changed while this route existed.
    if (!_isCurrentSession) {
      return _buildExpiredSessionScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Add Medical Visit'),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // ================================
            // STEP INDICATOR
            // ================================

            const Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step 1 of 7',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Doctor Information',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const LinearProgressIndicator(
              value: 1 / 7,
              minHeight: 6,
              borderRadius: BorderRadius.all(
                Radius.circular(6),
              ),
            ),

            const SizedBox(height: 26),

            // ================================
            // PAGE TITLE
            // ================================

            const Text(
              'Doctor Information',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Choose an existing doctor or '
                  'enter a new doctor for this visit.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // ================================
            // EXISTING / NEW DOCTOR SELECTOR
            // ================================

            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Existing Doctor'),
                  icon: Icon(
                    Icons.person_search_outlined,
                  ),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('New Doctor'),
                  icon: Icon(
                    Icons.person_add_outlined,
                  ),
                ),
              ],
              selected: {_useExistingDoctor},
              onSelectionChanged: (selection) {
                if (!_checkDraftSession()) {
                  return;
                }

                setState(() {
                  _useExistingDoctor = selection.first;
                });
              },
            ),

            const SizedBox(height: 24),

            // ================================
            // ACTIVE FORM
            // ================================

            if (_useExistingDoctor)
              _buildExistingDoctorSection()
            else
              _buildNewDoctorSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),

      // ==================================
      // NEXT BUTTON
      // ==================================

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoadingDoctors ||
                  _doctorsLoadError != null ||
                  (_useExistingDoctor &&
                      _doctors.isEmpty)
                  ? null
                  : _continue,
              icon: const Icon(
                Icons.arrow_forward,
              ),
              label: const Text(
                'Next: Location',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

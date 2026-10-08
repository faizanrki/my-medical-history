
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../models/visit_draft.dart';
import '../../services/medical_visit_save_service.dart';

import 'visit_information_screen.dart';

// ============================================
// MY MEDICAL HISTORY
// STEP 44.12 - SECURE HOSPITAL LOCATION
// STEP 2 OF 7
// ============================================

class LocationStepScreen extends StatefulWidget {
  // Kept for compatibility with the
  // existing Step 1 constructor.
  final String? doctorId;
  final String doctorName;
  final String hospitalName;

  const LocationStepScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.hospitalName,
  });

  @override
  State<LocationStepScreen> createState() =>
      _LocationStepScreenState();
}

class _LocationStepScreenState
    extends State<LocationStepScreen>
    with WidgetsBindingObserver {

  // ========================================
  // SHARED VISIT DRAFT
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
  // FORM CONTROLS
  // ========================================

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final TextEditingController _addressController =
  TextEditingController();

  // ========================================
  // INITIALIZE
  // ========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  // ========================================
  // RECEIVE ORIGINAL ACCOUNT-BOUND DRAFT
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

    // IMPORTANT:
    // Do not create a replacement VisitDraft
    // if the original route argument is missing.
    //
    // A replacement draft would not preserve
    // the account ownership established
    // in Step 1.

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
      // The selected Google account must
      // still have an active database session.
      if (!AppDatabase.instance
          .isSessionCurrent(generation)) {
        throw StateError(
          'The medical account is locked.',
        );
      }

      // The draft must already have been
      // bound to this session by Step 1.
      //
      // This method does NOT bind a new draft.

      _saveService.verifyDraftForCurrentSession(
        arguments,
      );

      // Preserve the SAME VisitDraft.
      _draft = arguments;
      _draftGeneration = generation;

      // Restore an address when returning
      // from the next form step.
      _addressController.text =
          arguments.hospitalAddress;
    } catch (_) {
      _draft = null;
      _draftGeneration = null;

      _draftError =
      'This visit draft does not belong '
          'to the current Google account '
          'session. Please start a new visit.';
    }
  }

  // ========================================
  // CHECK CURRENT ACCOUNT SESSION
  // ========================================

  bool get _isCurrentDraft {
    final draft = _draft;
    final generation = _draftGeneration;

    if (draft == null || generation == null) {
      return false;
    }

    // Detect sign-out or account switching.
    if (!AppDatabase.instance
        .isSessionCurrent(generation)) {
      return false;
    }

    // Verify the draft is registered to
    // the currently active session.
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
  // PREVENT CONTINUING AN EXPIRED DRAFT
  // ========================================

  bool _ensureCurrentDraft() {
    if (_isCurrentDraft) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    // Hide information from an expired form.
    setState(() {
      _draft = null;
      _draftGeneration = null;

      _draftError =
      'Your Google account session '
          'has changed. This visit form '
          'can no longer be continued.';
    });

    _addressController.clear();

    return false;
  }

  // ========================================
  // REFRESH WHEN APP RESUMES
  // ========================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed &&
        mounted) {
      // Rebuild to show the locked-state
      // screen if the account has changed.
      setState(() {});
    }
  }

  // ========================================
  // DISPOSE
  // ========================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _addressController.dispose();

    super.dispose();
  }

  // ========================================
  // SHOW MESSAGE
  // ========================================

  void _showMessage(String message) {
    if (!mounted) return;

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
  // VALIDATE HOSPITAL ADDRESS
  // ========================================

  String? _validateAddress(String? value) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Please enter hospital address';
    }

    return null;
  }

  // ========================================
  // UPDATE SHARED DRAFT ADDRESS
  // ========================================

  void _onAddressChanged(String value) {
    if (!_ensureCurrentDraft()) {
      return;
    }

    // Update the SAME original draft.
    _draft!.hospitalAddress = value;

    // Refresh address preview.
    setState(() {});
  }

  // ========================================
  // CURRENT GPS LOCATION
  // ========================================

  Future<void> _useCurrentLocation() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Location services are disabled. Please enable GPS.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Location permissions are permanently denied.');
        return;
      }

      _showMessage('Fetching current GPS location...');
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final addressText = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)} (GPS Location)';
      _addressController.text = addressText;
      _draft!.hospitalAddress = addressText;
      setState(() {});
      _showMessage('GPS location acquired successfully!');
    } catch (e) {
      _showMessage('Failed to get current location: $e');
    }
  }

  // ========================================
  // OPEN GOOGLE MAPS
  // ========================================

  Future<void> _selectOnMap() async {
    if (!_ensureCurrentDraft()) {
      return;
    }

    final query = Uri.encodeComponent(_addressController.text.trim().isEmpty ? widget.hospitalName : _addressController.text.trim());
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('Could not open Google Maps.');
      }
    } catch (e) {
      _showMessage('Error launching map: $e');
    }
  }

  // ========================================
  // CONTINUE TO STEP 3
  // ========================================

  void _continue() {
    // ======================================
    // CHECK ACCOUNT OWNERSHIP
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    // ======================================
    // VALIDATE ADDRESS
    // ======================================

    if (!(_formKey.currentState?.validate() ??
        false)) {
      return;
    }

    // ======================================
    // UPDATE ORIGINAL DRAFT
    // ======================================

    final draft = _draft!;

    draft.hospitalAddress =
        _addressController.text.trim();

    // ======================================
    // RECHECK SESSION BEFORE NAVIGATION
    // ======================================

    if (!_ensureCurrentDraft()) {
      return;
    }

    FocusScope.of(context).unfocus();

    // ======================================
    // OPEN STEP 3
    // ======================================

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        // Pass the same account-bound draft.
        settings: RouteSettings(
          arguments: draft,
        ),

        // Preserve the existing
        // VisitInformationScreen constructor.
        builder: (_) => VisitInformationScreen(
          doctorId: draft.doctorId,
          doctorName: draft.doctorName,
          hospitalName: draft.hospitalName,
          hospitalAddress:
          draft.hospitalAddress,
        ),
      ),
    );
  }

  // ========================================
  // BACK TO STEP 1
  // ========================================

  void _goBack() {
    Navigator.of(context).maybePop();
  }

  // ========================================
  // REUSABLE INFORMATION ROW
  // ========================================

  Widget _buildInformationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 21,
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

              const SizedBox(height: 5),

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

  // ========================================
  // RESPONSIVE LOCATION BUTTONS
  // ========================================

  Widget _buildLocationMethods() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow =
            constraints.maxWidth < 350;

        final gpsButton = OutlinedButton.icon(
          onPressed: _useCurrentLocation,
          icon: const Icon(
            Icons.my_location,
            size: 18,
          ),
          label: const Text(
            'Current GPS',
            textAlign: TextAlign.center,
          ),
        );

        final mapButton = OutlinedButton.icon(
          onPressed: _selectOnMap,
          icon: const Icon(
            Icons.map_outlined,
            size: 18,
          ),
          label: const Text(
            'Select on Map',
            textAlign: TextAlign.center,
          ),
        );

        // Avoid horizontal overflow on
        // small phones or larger text sizes.
        if (narrow) {
          return Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              gpsButton,
              const SizedBox(height: 10),
              mapButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: gpsButton),
            const SizedBox(width: 10),
            Expanded(child: mapButton),
          ],
        );
      },
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
                    color: AppColors.error,
                    size: 37,
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
                      'Your account session changed. '
                          'Please return and start '
                          'a new medical visit.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
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
  // MAIN LOCATION SCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    // Never show the doctor's information
    // when the original draft is not valid.
    if (!_isCurrentDraft) {
      return _buildInvalidDraftScreen();
    }

    final draft = _draft!;

    return Scaffold(
      backgroundColor: AppColors.background,

      // ====================================
      // APP BAR
      // ====================================

      appBar: AppBar(
        title: const Text('Add Medical Visit'),
      ),

      // ====================================
      // MAIN FORM
      // ====================================

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: ListView(
            padding: const EdgeInsets.all(20),

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
                    'Step 2 of 7',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Text(
                    'Location',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const LinearProgressIndicator(
                value: 2 / 7,
                minHeight: 6,
                borderRadius: BorderRadius.all(
                  Radius.circular(6),
                ),
              ),

              const SizedBox(height: 27),

              // ==============================
              // PAGE INTRODUCTION
              // ==============================

              const Text(
                'Hospital Location',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Where did you visit your doctor?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 23),

              // ==============================
              // DOCTOR / HOSPITAL SUMMARY
              // ==============================

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(17),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      _buildInformationRow(
                        icon:
                        Icons.local_hospital_outlined,
                        label: 'Hospital / Clinic',
                        value: draft.hospitalName,
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      _buildInformationRow(
                        icon: Icons.person_outline,
                        label: 'Doctor',
                        value: draft.doctorName,
                      ),

                      if (draft.doctorSpecialization
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 16),

                        _buildInformationRow(
                          icon:
                          Icons.medical_information_outlined,
                          label: 'Specialization',
                          value:
                          draft.doctorSpecialization,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // ==============================
              // HOSPITAL ADDRESS
              // ==============================

              const Text(
                'Hospital / Clinic Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,

                minLines: 2,
                maxLines: 3,

                textCapitalization:
                TextCapitalization.sentences,

                decoration: const InputDecoration(
                  labelText: 'Hospital Address *',

                  hintText:
                  'Enter hospital or clinic address',

                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                  ),

                  alignLabelWithHint: true,
                ),

                validator: _validateAddress,

                onChanged: _onAddressChanged,
              ),

              const SizedBox(height: 25),

              // ==============================
              // LOCATION METHODS
              // ==============================

              const Text(
                'Choose Location Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              _buildLocationMethods(),

              const SizedBox(height: 25),

              // ==============================
              // MAP PREVIEW
              // ==============================

              const Text(
                'Map Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              const _MapPreview(),

              const SizedBox(height: 12),

              const Text(
                'The map is a preview placeholder. '
                    'GPS and real map selection are '
                    'not connected yet.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // ==============================
              // ENTERED ADDRESS PREVIEW
              // ==============================

              if (_addressController.text
                  .trim()
                  .isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15),

                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: AppColors.primary,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Entered Address',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                  AppColors.textSecondary,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                _addressController.text
                                    .trim(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color:
                                  AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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
                    'Next: Visit Info',
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
// MAP PREVIEW PLACEHOLDER
// ============================================

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,

      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              Icons.location_on_outlined,
              size: 48,
              color: AppColors.primary,
            ),

            SizedBox(height: 10),

            Text(
              'Map Preview',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            SizedBox(height: 6),

            Text(
              'Location not selected on map',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

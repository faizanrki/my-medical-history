
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/medical_history_read_service.dart';

import '../visits/add_visit_screen.dart';
import 'doctor_profile_screen.dart';

// =====================================
// DOCTORS SCREEN - STEP 37
// =====================================
//
// Displays real doctors saved in SQLite.
// No hardcoded sample doctors are used.

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() =>
      _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  // =====================================
  // DATABASE SERVICE
  // =====================================

  final MedicalHistoryReadService _readService =
      MedicalHistoryReadService.instance;

  // =====================================
  // SEARCH CONTROLLER
  // =====================================

  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  // =====================================
  // DOCTOR RECORDS
  // =====================================

  List<SavedDoctorRecord> _doctors = [];

  bool _isLoading = false;

  String? _errorMessage;

  // =====================================
  // INITIALIZE
  // =====================================

  @override
  void initState() {
    super.initState();

    _loadDoctors();
  }

  // =====================================
  // DISPOSE
  // =====================================

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  // =====================================
  // LOAD DOCTORS FROM SQLITE
  // =====================================

  Future<void> _loadDoctors() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _readService.getDoctors();

      if (!mounted) {
        return;
      }

      setState(() {
        _doctors = records;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
        'Unable to load saved doctors. '
            'Please check medical storage '
            'and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =====================================
  // SEARCH SAVED DOCTORS
  // =====================================

  List<SavedDoctorRecord> get _filteredDoctors {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _doctors;
    }

    return _doctors.where((doctor) {
      return doctor.name.toLowerCase().contains(query) ||
          doctor.specialization
              .toLowerCase()
              .contains(query) ||
          doctor.hospitalName
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  // =====================================
  // TOTAL NUMBER OF SAVED VISITS
  // =====================================

  int get _totalVisits {
    return _doctors.fold<int>(
      0,
          (total, doctor) => total + doctor.visitCount,
    );
  }

  // =====================================
  // DOCTOR INITIALS
  // =====================================

  String _getInitials(String name) {
    // Remove Dr. prefix for cleaner initials.
    final cleanName = name.trim().replaceFirst(
      RegExp(
        r'^(Dr\.?|Doctor)\s+',
        caseSensitive: false,
      ),
      '',
    );

    final words = cleanName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'DR';
    }

    if (words.length == 1) {
      return words.first
          .substring(0, 1)
          .toUpperCase();
    }

    final firstLetter =
    words.first.substring(0, 1);

    final lastLetter =
    words.last.substring(0, 1);

    return '$firstLetter$lastLetter'.toUpperCase();
  }

  // =====================================
  // FORMAT LAST VISIT DATE
  // =====================================

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'No visits recorded';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return MaterialLocalizations.of(context)
        .formatMediumDate(date);
  }

  // =====================================
  // OPEN DOCTOR PROFILE
  // =====================================

  Future<void> _openDoctorProfile(
      SavedDoctorRecord doctor,
      ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DoctorProfileScreen(
          doctorId: doctor.id,
          name: doctor.name,
          specialization: doctor.specialization,
          hospital: doctor.hospitalName,
          phone: doctor.phone,
          initials: _getInitials(doctor.name),
        ),
      ),
    );

    // Reload after returning from profile.
    if (!mounted) {
      return;
    }

    await _loadDoctors();
  }

  // =====================================
  // OPEN ADD MEDICAL VISIT
  // =====================================

  Future<void> _openAddVisit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
        const AddVisitScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    // A new doctor may have been created
    // while saving the medical visit.
    await _loadDoctors();
  }

  // =====================================
  // DOCTOR STATISTICS CARD
  // =====================================

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 42,
                height: 42,

                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2FF),
                  borderRadius:
                  BorderRadius.circular(12),
                ),

                child: Icon(
                  icon,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // DOCTOR INFORMATION FIELD
  // =====================================

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            size: 17,
            color: AppColors.textSecondary,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              text.trim().isEmpty
                  ? 'Not provided'
                  : text,

              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // BUILD SAVED DOCTOR CARD
  // =====================================

  Widget _buildDoctorCard(
      SavedDoctorRecord doctor,
      ) {
    final initials = _getInitials(
      doctor.name,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: () => _openDoctorProfile(doctor),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              // =================================
              // DOCTOR NAME AND AVATAR
              // =================================

              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor:
                    const Color(0xFFE6F2FF),

                    child: Text(
                      initials,

                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          doctor.name,

                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color:
                            const Color(0xFFE6F2FF),

                            borderRadius:
                            BorderRadius.circular(8),
                          ),

                          child: Text(
                            doctor.specialization.trim().isEmpty
                                ? 'Specialization not set'
                                : doctor.specialization,

                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),

              const SizedBox(height: 15),

              const Divider(height: 1),

              const SizedBox(height: 14),

              // =================================
              // HOSPITAL AND PHONE
              // =================================

              _buildInfoRow(
                icon: Icons.local_hospital_outlined,
                text: doctor.hospitalName,
              ),

              _buildInfoRow(
                icon: Icons.phone_outlined,
                text: doctor.phone,
              ),

              const SizedBox(height: 8),

              // =================================
              // VISIT COUNT
              // =================================

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: AppColors.background,

                  borderRadius:
                  BorderRadius.circular(10),

                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        '${doctor.visitCount} '
                            '${doctor.visitCount == 1 ? "visit" : "visits"} '
                            'recorded',

                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 13),

              Text(
                'Last Visit: '
                    '${_formatDate(doctor.lastVisitDate)}',

                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 12),

              // =================================
              // VIEW PROFILE BUTTON
              // =================================

              SizedBox(
                width: double.infinity,

                child: OutlinedButton.icon(
                  onPressed: () {
                    _openDoctorProfile(doctor);
                  },

                  icon: const Icon(
                    Icons.person_outline,
                    size: 19,
                  ),

                  label: const Text(
                    'View Doctor Profile',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // EMPTY DOCTORS STATE
  // =====================================

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 35,
        horizontal: 12,
      ),

      child: Column(
        children: [
          const Icon(
            Icons.medical_services_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),

          const SizedBox(height: 16),

          const Text(
            'No Saved Doctors Yet',

            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Doctors will appear here when '
                'you save a medical visit with '
                'their information.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _openAddVisit,

            icon: const Icon(Icons.add),

            label: const Text(
              'Add Medical Visit',
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // SEARCH EMPTY STATE
  // =====================================

  Widget _buildNoSearchResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 35,
      ),

      child: Column(
        children: [
          const Icon(
            Icons.search_off,
            size: 48,
            color: AppColors.textSecondary,
          ),

          const SizedBox(height: 12),

          const Text(
            'No Matching Doctors',

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Try searching with another '
                'doctor name, specialty or hospital.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 14),

          TextButton(
            onPressed: () {
              _searchController.clear();

              setState(() {
                _searchQuery = '';
              });
            },

            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  // =====================================
  // DATABASE ERROR STATE
  // =====================================

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 35,
            ),

            const SizedBox(height: 10),

            Text(
              _errorMessage ??
                  'Unable to load doctors.',

              textAlign: TextAlign.center,
            ),

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

  // =====================================
  // BUILD DOCTORS SCREEN
  // =====================================

  @override
  Widget build(BuildContext context) {
    final filteredDoctors = _filteredDoctors;

    return Scaffold(
      backgroundColor: AppColors.background,

      // =====================================
      // APP BAR
      // =====================================

      appBar: AppBar(
        title: const Text('My Doctors'),

        actions: [
          IconButton(
            tooltip: 'Refresh Doctors',

            onPressed:
            _isLoading ? null : _loadDoctors,

            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // =====================================
      // BODY
      // =====================================

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDoctors,

          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.all(16),

            children: [
              // =================================
              // SCREEN HEADING
              // =================================

              const Text(
                'Your Doctors',

                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'Find your saved doctors and '
                    'view their medical visit history.',

                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 22),

              // =================================
              // STATISTICS
              // =================================

              Row(
                children: [
                  _buildStatCard(
                    title: 'Saved Doctors',
                    count: _doctors.length,
                    icon: Icons.people_outline,
                  ),

                  const SizedBox(width: 12),

                  _buildStatCard(
                    title: 'Recorded Visits',
                    count: _totalVisits,
                    icon:
                    Icons.calendar_month_outlined,
                  ),
                ],
              ),

              const SizedBox(height: 23),

              // =================================
              // SEARCH BAR
              // =================================

              TextField(
                controller: _searchController,

                decoration: InputDecoration(
                  hintText: 'Search saved doctors...',

                  prefixIcon:
                  const Icon(Icons.search),

                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                    tooltip: 'Clear Search',

                    icon: const Icon(
                      Icons.close,
                    ),

                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                ),

                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),

              const SizedBox(height: 15),

              Text(
                'Showing ${filteredDoctors.length} '
                    'of ${_doctors.length} saved doctors',

                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // =================================
              // LOADING STATE
              // =================================

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(35),

                  child: Center(
                    child:
                    CircularProgressIndicator(),
                  ),
                ),

              // =================================
              // DATABASE ERROR
              // =================================

              if (!_isLoading &&
                  _errorMessage != null)
                _buildErrorState(),

              // =================================
              // EMPTY DATABASE
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  _doctors.isEmpty)
                _buildEmptyState(),

              // =================================
              // EMPTY SEARCH
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  _doctors.isNotEmpty &&
                  filteredDoctors.isEmpty)
                _buildNoSearchResults(),

              // =================================
              // SAVED DOCTOR CARDS
              // =================================

              if (!_isLoading &&
                  _errorMessage == null)
                for (final doctor in filteredDoctors)
                  _buildDoctorCard(doctor),

              const SizedBox(height: 90),
            ],
          ),
        ),
      ),

      // =====================================
      // ADD MEDICAL VISIT BUTTON
      // =====================================

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: _openAddVisit,

        icon: const Icon(Icons.add),

        label: const Text('Add Visit'),
      ),
    );
  }
}

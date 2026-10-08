
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/medical_history_read_service.dart';

import '../history/visit_details_screen.dart';
import '../visits/add_visit_screen.dart';

// ======================================
// DOCTOR PROFILE SCREEN - STEP 38
// ======================================
//
// Loads the doctor and their visits
// from the encrypted SQLite database.
//
// No hardcoded sample visits.

class DoctorProfileScreen extends StatefulWidget {
  // Keep all existing constructor fields
  // for compatibility with DoctorsScreen.

  final String doctorId;
  final String name;
  final String specialization;
  final String hospital;
  final String phone;
  final String initials;

  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
    required this.name,
    required this.specialization,
    required this.hospital,
    required this.phone,
    required this.initials,
  });

  @override
  State<DoctorProfileScreen> createState() =>
      _DoctorProfileScreenState();
}

class _DoctorProfileScreenState
    extends State<DoctorProfileScreen> {

  // ======================================
  // DATABASE SERVICE
  // ======================================

  final MedicalHistoryReadService _service =
      MedicalHistoryReadService.instance;

  static const int _pageSize = 20;

  // ======================================
  // SAVED DATA
  // ======================================

  SavedDoctorRecord? _doctor;

  final List<SavedVisitSummary> _visits = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;

  String? _errorMessage;
  String? _loadMoreError;

  // ======================================
  // INITIALIZE
  // ======================================

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  // ======================================
  // LOAD DOCTOR AND VISITS
  // ======================================

  Future<void> _loadProfile() async {
    if (_isLoading || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadMoreError = null;
    });

    try {
      // Read the selected doctor from SQLite.
      final doctor = await _service.getDoctorById(
        widget.doctorId,
      );

      // Do not query visits for a missing doctor.
      final records = doctor == null
          ? <SavedVisitSummary>[]
          : await _service.getVisitsByDoctor(
        widget.doctorId,
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _doctor = doctor;

        _visits
          ..clear()
          ..addAll(records);

        _hasMore = doctor != null &&
            records.isNotEmpty &&
            _visits.length < doctor.visitCount;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
        'Unable to load this doctor profile. '
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

  // ======================================
  // LOAD MORE DOCTOR VISITS
  // ======================================

  Future<void> _loadMoreVisits() async {
    if (_isLoading ||
        _isLoadingMore ||
        !_hasMore ||
        _doctor == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final records =
      await _service.getVisitsByDoctor(
        widget.doctorId,
        limit: _pageSize,
        offset: _visits.length,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        // Avoid showing the same visit twice.
        final loadedIds =
        _visits.map((v) => v.id).toSet();

        for (final record in records) {
          if (loadedIds.add(record.id)) {
            _visits.add(record);
          }
        }

        _hasMore = records.isNotEmpty &&
            records.length == _pageSize &&
            _visits.length < _doctor!.visitCount;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadMoreError =
        'Unable to load more visits. '
            'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // ======================================
  // FORMAT DATE
  // ======================================

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not scheduled';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return MaterialLocalizations.of(context)
        .formatMediumDate(date);
  }

  // ======================================
  // FORMAT TIME
  // ======================================

  String _formatTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return value;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return value;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    ).format(context);
  }

  // ======================================
  // DISPLAY EMPTY INFORMATION
  // ======================================

  String _display(String value) {
    return value.trim().isEmpty
        ? 'Not provided'
        : value.trim();
  }

  // ======================================
  // DOCTOR INITIALS
  // ======================================

  String _getInitials(String name) {
    final cleaned = name.replaceFirst(
      RegExp(
        r'^(Dr\.?|Doctor)\s+',
        caseSensitive: false,
      ),
      '',
    );

    final words = cleaned
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'DR';
    }

    if (words.length == 1) {
      return words.first[0].toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'
        .toUpperCase();
  }

  // ======================================
  // OPEN FULL VISIT DETAILS
  // ======================================

  Future<void> _openVisitDetails(
      SavedVisitSummary visit,
      ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            VisitDetailsScreen(
              visitId: visit.id,
            ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadProfile();
  }

  // ======================================
  // OPEN ADD VISIT
  // ======================================

  Future<void> _openAddVisit() async {
    // Pass doctor ID to the existing form.
    //
    // IMPORTANT:
    // Step 39 will update AddVisitScreen
    // to recognize all saved SQLite doctors.

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AddVisitScreen(
          initialDoctorId: widget.doctorId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    // Reload to include any newly saved visit.
    await _loadProfile();
  }

  // ======================================
  // REUSABLE PROFILE INFO ROW
  // ======================================

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            size: 21,
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
                  _display(value),

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
      ),
    );
  }

  // ======================================
  // DOCTOR PROFILE CARD
  // ======================================

  Widget _buildDoctorCard(
      SavedDoctorRecord doctor,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          children: [
            // =================================
            // DOCTOR AVATAR
            // =================================

            CircleAvatar(
              radius: 40,
              backgroundColor:
              const Color(0xFFE6F2FF),

              child: Text(
                _getInitials(doctor.name),

                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 15),

            Text(
              doctor.name,

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 9),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 7,
              ),

              decoration: BoxDecoration(
                color: const Color(0xFFE6F2FF),
                borderRadius:
                BorderRadius.circular(20),
              ),

              child: Text(
                _display(doctor.specialization),

                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 22),

            const Divider(),

            const SizedBox(height: 18),

            // =================================
            // SAVED DOCTOR INFORMATION
            // =================================

            _buildInfoRow(
              icon: Icons.local_hospital_outlined,
              label: 'Hospital / Clinic',
              value: doctor.hospitalName,
            ),

            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone Number',
              value: doctor.phone,
            ),

            _buildInfoRow(
              icon: Icons.calendar_month_outlined,
              label: 'Most Recent Visit',
              value: doctor.lastVisitDate == null
                  ? 'No visits recorded'
                  : _formatDate(
                doctor.lastVisitDate,
              ),
            ),

            const SizedBox(height: 8),

            // =================================
            // TOTAL VISITS
            // =================================

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(15),

              decoration: BoxDecoration(
                color: AppColors.background,

                borderRadius:
                BorderRadius.circular(12),

                border: Border.all(
                  color: AppColors.border,
                ),
              ),

              child: Row(
                children: [
                  const Icon(
                    Icons.history,
                    color: AppColors.primary,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      '${doctor.visitCount} '
                          '${doctor.visitCount == 1 ? "Medical Visit" : "Medical Visits"}',

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,

              child: FilledButton.icon(
                onPressed: _openAddVisit,

                icon: const Icon(
                  Icons.add_circle_outline,
                ),

                label: const Text(
                  'Add Visit for This Doctor',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================
  // SAVED VISIT CARD
  // ======================================

  Widget _buildVisitCard(
      SavedVisitSummary visit,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: () => _openVisitDetails(visit),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              // =================================
              // DATE / TIME
              // =================================

              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 19,
                    color: AppColors.primary,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      _formatDate(visit.visitDate),

                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),

              const SizedBox(height: 5),

              Padding(
                padding: const EdgeInsets.only(
                  left: 28,
                ),

                child: Text(
                  _formatTime(visit.visitTime),

                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              const Divider(height: 1),

              const SizedBox(height: 14),

              // =================================
              // REASON FOR VISIT
              // =================================

              const Text(
                'Reason for Visit',

                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                _display(visit.reason),

                maxLines: 3,
                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              // =================================
              // DIAGNOSIS
              // =================================

              if (visit.diagnosis.trim().isNotEmpty) ...[
                const SizedBox(height: 12),

                const Text(
                  'Diagnosis',

                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  visit.diagnosis,

                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],

              // =================================
              // FOLLOW-UP DATE
              // =================================

              if (visit.followUpDate != null) ...[
                const SizedBox(height: 13),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),

                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F2FF),

                    borderRadius:
                    BorderRadius.circular(8),
                  ),

                  child: Text(
                    'Follow-up: '
                        '${_formatDate(visit.followUpDate)}',

                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 15),

              // =================================
              // VIEW FULL RECORD BUTTON
              // =================================

              SizedBox(
                width: double.infinity,

                child: OutlinedButton.icon(
                  onPressed: () {
                    _openVisitDetails(visit);
                  },

                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 19,
                  ),

                  label: const Text(
                    'View Full Medical Record',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================
  // EMPTY VISIT HISTORY
  // ======================================

  Widget _buildEmptyVisits() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(25),

        child: Column(
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 55,
              color: AppColors.textSecondary,
            ),

            const SizedBox(height: 15),

            const Text(
              'No Visits Recorded',

              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'No medical visits have been '
                  'saved for this doctor yet.',

              textAlign: TextAlign.center,

              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _openAddVisit,

              icon: const Icon(Icons.add),

              label: const Text(
                'Add Medical Visit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================
  // ERROR / MISSING PROFILE
  // ======================================

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.textSecondary,
            ),

            const SizedBox(height: 15),

            Text(
              title,

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              message,
              textAlign: TextAlign.center,

              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 18),

            OutlinedButton.icon(
              onPressed: _loadProfile,

              icon: const Icon(Icons.refresh),

              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================
  // MAIN DOCTOR PROFILE SCREEN
  // ======================================

  @override
  Widget build(BuildContext context) {
    final doctor = _doctor;

    return Scaffold(
      backgroundColor: AppColors.background,

      // =================================
      // APP BAR
      // =================================

      appBar: AppBar(
        title: const Text('Doctor Profile'),

        actions: [
          IconButton(
            tooltip: 'Refresh Doctor Profile',

            onPressed: _isLoading || _isLoadingMore
                ? null
                : _loadProfile,

            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // =================================
      // MAIN CONTENT
      // =================================

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,

          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.all(16),

            children: [
              // =================================
              // LOADING
              // =================================

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 70,
                  ),

                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              // =================================
              // DATABASE ERROR
              // =================================

              if (!_isLoading &&
                  _errorMessage != null)
                _buildMessage(
                  icon: Icons.error_outline,
                  title: 'Unable to Load Profile',
                  message: _errorMessage!,
                ),

              // =================================
              // DOCTOR DOES NOT EXIST
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  doctor == null)
                _buildMessage(
                  icon: Icons.person_off_outlined,
                  title: 'Doctor Not Found',
                  message:
                  'This doctor profile could not '
                      'be found in your saved records.',
                ),

              // =================================
              // REAL SAVED DOCTOR PROFILE
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  doctor != null) ...[
                _buildDoctorCard(doctor),

                const SizedBox(height: 24),

                // =================================
                // VISIT HISTORY HEADER
                // =================================

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Medical Visit History',

                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F2FF),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),

                      child: Text(
                        '${doctor.visitCount} visits',

                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  'Every appointment is stored '
                      'as a separate medical record.',

                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Showing ${_visits.length} '
                      'of ${doctor.visitCount} saved visits',

                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 18),

                // =================================
                // NO SAVED VISITS
                // =================================

                if (_visits.isEmpty)
                  _buildEmptyVisits(),

                // =================================
                // REAL SQLITE VISITS
                // =================================

                for (final visit in _visits)
                  _buildVisitCard(visit),

                // =================================
                // LOAD MORE ERROR
                // =================================

                if (_loadMoreError != null) ...[
                  const SizedBox(height: 10),

                  Text(
                    _loadMoreError!,

                    textAlign: TextAlign.center,

                    style: const TextStyle(
                      color: AppColors.error,
                    ),
                  ),
                ],

                // =================================
                // PAGINATION
                // =================================

                if (_hasMore) ...[
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,

                    child: OutlinedButton.icon(
                      onPressed: _isLoadingMore
                          ? null
                          : _loadMoreVisits,

                      icon: _isLoadingMore
                          ? const SizedBox(
                        width: 18,
                        height: 18,

                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.expand_more,
                      ),

                      label: Text(
                        _isLoadingMore
                            ? 'Loading More...'
                            : 'Load More Visits',
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

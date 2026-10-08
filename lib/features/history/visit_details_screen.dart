
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/medical_history_read_service.dart';

// =====================================
// SAVED MEDICAL VISIT DETAILS SCREEN
// =====================================

// Displays one complete saved medical visit.
//
// Data is loaded using the visit ID.
// This screen does not edit or delete data.

class VisitDetailsScreen extends StatefulWidget {
  final String visitId;

  const VisitDetailsScreen({
    super.key,
    required this.visitId,
  });

  @override
  State<VisitDetailsScreen> createState() =>
      _VisitDetailsScreenState();
}

class _VisitDetailsScreenState
    extends State<VisitDetailsScreen> {

  // =====================================
  // DATABASE SERVICE
  // =====================================

  final MedicalHistoryReadService _service =
      MedicalHistoryReadService.instance;

  // =====================================
  // SCREEN STATE
  // =====================================

  SavedVisitDetails? _details;

  bool _isLoading = true;

  String? _errorMessage;

  // =====================================
  // INITIALIZE
  // =====================================

  @override
  void initState() {
    super.initState();

    _loadVisitDetails();
  }

  // =====================================
  // LOAD SAVED VISIT
  // =====================================

  Future<void> _loadVisitDetails() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Read complete visit details
      // from the encrypted database.

      final result = await _service.getVisitDetails(
        widget.visitId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _details = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      // Do not expose SQL errors,
      // passwords or database paths.

      setState(() {
        _details = null;
        _isLoading = false;

        _errorMessage =
        'Unable to load this medical visit. '
            'Please try again.';
      });
    }
  }

  // =====================================
  // DISPLAY EMPTY TEXT
  // =====================================

  String _displayText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not provided';
    }

    return value.trim();
  }

  // =====================================
  // FORMAT DATE
  // =====================================

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Not scheduled';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return MaterialLocalizations.of(context)
        .formatMediumDate(date);
  }

  // =====================================
  // FORMAT TIME
  // =====================================

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

  // =====================================
  // REUSABLE INFORMATION ROW
  // =====================================

  Widget _buildDetail({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

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

  // =====================================
  // REUSABLE SECTION CARD
  // =====================================

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: AppColors.primary,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    title,

                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(height: 1),

            const SizedBox(height: 14),

            ...children,
          ],
        ),
      ),
    );
  }

  // =====================================
  // MEDICINE CARD
  // =====================================

  Widget _buildMedicineCard(
      SavedMedicineRecord medicine,
      int index,
      ) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: AppColors.background,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.medication_outlined,
                color: AppColors.primary,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  '${index + 1}. ${medicine.name}',

                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

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
            value: '${medicine.durationDays} days',
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

  // =====================================
  // MEDICAL TEST CARD
  // =====================================

  Widget _buildTestCard(
      SavedMedicalTestRecord test,
      int index,
      ) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: AppColors.background,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                color: AppColors.primary,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  '${index + 1}. ${test.name}',

                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Chip(
            label: Text(test.status),
          ),

          const SizedBox(height: 12),

          _buildDetail(
            label: 'Test Date',
            value: _formatDate(test.testDate),
          ),

          _buildDetail(
            label: 'Result Notes',
            value: test.resultNotes,
          ),

          const Text(
            'Report files are not available '
                'in this version.',

            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // SUMMARY HEADER
  // =====================================

  Widget _buildSummaryHeader(
      SavedVisitDetails details,
      ) {
    final visit = details.summary;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFFE6F2FF),

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: AppColors.primary,
                size: 21,
              ),

              SizedBox(width: 8),

              Text(
                'Saved Medical Visit',

                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            visit.doctorName,

            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            visit.hospitalName,

            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 16,
            runSpacing: 10,

            children: [
              Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: AppColors.primary,
                  ),

                  const SizedBox(width: 7),

                  Text(
                    _formatDate(visit.visitDate),
                  ),
                ],
              ),

              Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(
                    Icons.access_time_outlined,
                    size: 17,
                    color: AppColors.primary,
                  ),

                  const SizedBox(width: 7),

                  Text(
                    _formatTime(visit.visitTime),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================
  // RECORD COUNT CARDS
  // =====================================

  Widget _buildCountCard({
    required String label,
    required int count,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: AppColors.surface,

          border: Border.all(
            color: AppColors.border,
          ),

          borderRadius: BorderRadius.circular(12),
        ),

        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
            ),

            const SizedBox(height: 7),

            Text(
              '$count',

              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            Text(
              label,
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

  // =====================================
  // ERROR / NOT FOUND MESSAGE
  // =====================================

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 50,
      ),

      child: Column(
        children: [
          Icon(
            icon,
            size: 58,
            color: AppColors.textSecondary,
          ),

          const SizedBox(height: 16),

          Text(
            title,
            textAlign: TextAlign.center,

            style: const TextStyle(
              fontSize: 19,
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

          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: _loadVisitDetails,

            icon: const Icon(Icons.refresh),

            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // =====================================
  // BUILD MAIN SCREEN
  // =====================================

  @override
  Widget build(BuildContext context) {
    final details = _details;

    return Scaffold(
      backgroundColor: AppColors.background,

      // =====================================
      // APP BAR
      // =====================================

      appBar: AppBar(
        title: const Text('Medical Visit Details'),

        actions: [
          IconButton(
            tooltip: 'Refresh visit',

            onPressed:
            _isLoading ? null : _loadVisitDetails,

            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // =====================================
      // MAIN CONTENT
      // =====================================

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadVisitDetails,

          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.all(16),

            children: [
              // =================================
              // LOADING STATE
              // =================================

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 75,
                  ),

                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              // =================================
              // ERROR STATE
              // =================================

              if (!_isLoading &&
                  _errorMessage != null)
                _buildMessage(
                  icon: Icons.error_outline,
                  title: 'Unable to Load Visit',
                  message: _errorMessage!,
                ),

              // =================================
              // RECORD NOT FOUND
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  details == null)
                _buildMessage(
                  icon: Icons.folder_off_outlined,
                  title: 'Visit Not Found',
                  message:
                  'No saved medical visit was '
                      'found for this reference.',
                ),

              // =================================
              // SAVED MEDICAL VISIT
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  details != null) ...[

                // =================================
                // SUMMARY HEADER
                // =================================

                _buildSummaryHeader(details),

                const SizedBox(height: 16),

                Row(
                  children: [
                    _buildCountCard(
                      label: 'Medicines',
                      count: details.medicines.length,
                      icon: Icons.medication_outlined,
                    ),

                    const SizedBox(width: 12),

                    _buildCountCard(
                      label: 'Medical Tests',
                      count: details.tests.length,
                      icon: Icons.science_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // =================================
                // DOCTOR INFORMATION
                // =================================

                _buildSection(
                  title: 'Doctor Information',
                  icon: Icons.medical_services_outlined,

                  children: [
                    _buildDetail(
                      label: 'Doctor Name',
                      value: details.summary.doctorName,
                    ),

                    _buildDetail(
                      label: 'Specialization',
                      value: details.doctorSpecialization,
                    ),

                    _buildDetail(
                      label: 'Phone Number',
                      value: details.doctorPhone,
                    ),

                    _buildDetail(
                      label: 'Hospital / Clinic',
                      value: details.summary.hospitalName,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // =================================
                // HOSPITAL LOCATION
                // =================================

                _buildSection(
                  title: 'Hospital Location',
                  icon: Icons.location_on_outlined,

                  children: [
                    _buildDetail(
                      label: 'Hospital Address',
                      value: details.hospitalAddress,
                    ),

                    _buildDetail(
                      label: 'GPS Coordinates',

                      value: details.latitude != null &&
                          details.longitude != null
                          ? '${details.latitude}, '
                          '${details.longitude}'
                          : 'Not recorded',
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // =================================
                // VISIT INFORMATION
                // =================================

                _buildSection(
                  title: 'Visit Information',
                  icon: Icons.calendar_month_outlined,

                  children: [
                    _buildDetail(
                      label: 'Visit Date',
                      value: _formatDate(
                        details.summary.visitDate,
                      ),
                    ),

                    _buildDetail(
                      label: 'Visit Time',
                      value: _formatTime(
                        details.summary.visitTime,
                      ),
                    ),

                    _buildDetail(
                      label: 'Reason for Visit',
                      value: details.summary.reason,
                    ),

                    _buildDetail(
                      label: 'Symptoms',
                      value: details.symptoms,
                    ),

                    _buildDetail(
                      label: 'Diagnosis',
                      value: details.summary.diagnosis,
                    ),

                    _buildDetail(
                      label: "Doctor's Notes",
                      value: details.notes,
                    ),

                    _buildDetail(
                      label: 'Follow-up Date',

                      value:
                      details.summary.followUpDate ==
                          null
                          ? 'Not scheduled'
                          : _formatDate(
                        details.summary.followUpDate,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // =================================
                // MEDICINES SECTION
                // =================================

                _buildSection(
                  title: 'Prescribed Medicines',
                  icon: Icons.medication_outlined,

                  children: [
                    if (details.medicines.isEmpty)
                      const Text(
                        'No medicines recorded for '
                            'this visit.',

                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),

                    for (var i = 0;
                    i < details.medicines.length;
                    i++)
                      _buildMedicineCard(
                        details.medicines[i],
                        i,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // =================================
                // MEDICAL TESTS SECTION
                // =================================

                _buildSection(
                  title: 'Medical Tests',
                  icon: Icons.science_outlined,

                  children: [
                    if (details.tests.isEmpty)
                      const Text(
                        'No medical tests recorded '
                            'for this visit.',

                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),

                    for (var i = 0;
                    i < details.tests.length;
                    i++)
                      _buildTestCard(
                        details.tests[i],
                        i,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // =================================
                // PRESCRIPTION SECTION
                // =================================

                _buildSection(
                  title: 'Prescription',
                  icon: Icons.description_outlined,

                  children: [
                    _buildDetail(
                      label: 'Prescription Type',
                      value: details.prescriptionType,
                    ),

                    _buildDetail(
                      label: 'Prescription Notes',
                      value: details.prescriptionNotes,
                    ),

                    const Text(
                      'Prescription image and PDF '
                          'viewing will be added after '
                          'secure attachment storage '
                          'is implemented.',

                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // =================================
                // SAVED RECORD REFERENCE
                // =================================

                _buildSection(
                  title: 'Record Information',
                  icon: Icons.folder_outlined,

                  children: [
                    const Text(
                      'Visit Reference',

                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    SelectableText(
                      details.summary.id,

                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'This record was loaded from '
                          'the local encrypted database. '
                          'Google Drive backup is separate '
                          'and is not confirmed here.',

                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

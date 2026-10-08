
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/medical_history_read_service.dart';
import '../history/visit_details_screen.dart';

// ==========================================
// MY MEDICAL HISTORY
// PROFESSIONAL MEDICAL REPORTS
// ==========================================

enum _ReportsMenuAction {
  refresh,
  about,
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() =>
      _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {

  // ======================================
  // DATABASE SERVICE
  // ======================================

  final MedicalHistoryReadService _readService =
      MedicalHistoryReadService.instance;

  // ======================================
  // SCREEN STATE
  // ======================================

  bool _isLoading = true;

  String? _errorMessage;

  MedicalHistoryCounts? _counts;

  List<SavedDoctorRecord> _doctors = [];

  List<SavedVisitSummary> _recentVisits = [];

  int _loadGeneration = 0;

  // ======================================
  // INITIALIZE
  // ======================================

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  // ======================================
  // LOAD REPORTS FROM SQLITE
  // ======================================

  Future<void> _loadReports() async {
    if (!mounted) return;

    final generation = ++_loadGeneration;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load real database statistics.
      final counts =
      await _readService.getHistoryCounts();

      // Load doctors and their visit counts.
      final doctors =
      await _readService.getDoctors();

      // Load latest 50 saved visits.
      final visits =
      await _readService.getAllVisits(
        limit: 50,
        offset: 0,
      );

      if (!mounted ||
          generation != _loadGeneration) {
        return;
      }

      // Sort doctors by visit count.
      final sortedDoctors =
      List<SavedDoctorRecord>.of(doctors);

      sortedDoctors.sort((a, b) {
        final comparison =
        b.visitCount.compareTo(a.visitCount);

        if (comparison != 0) {
          return comparison;
        }

        return a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        );
      });

      setState(() {
        _counts = counts;
        _doctors = sortedDoctors;
        _recentVisits = visits;
      });
    } catch (_) {
      if (!mounted ||
          generation != _loadGeneration) {
        return;
      }

      setState(() {
        _errorMessage =
        'Unable to load medical reports. '
            'Please try again.';
      });
    } finally {
      if (mounted &&
          generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ======================================
  // OPEN SAVED VISIT DETAILS
  // ======================================

  Future<void> _openVisit(
      SavedVisitSummary visit,
      ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VisitDetailsScreen(
          visitId: visit.id,
        ),
      ),
    );

    if (mounted) {
      await _loadReports();
    }
  }

  // ======================================
  // FORMAT VISIT DATE
  // ======================================

  String _formatDate(String text) {
    final parsed = DateTime.tryParse(text);

    if (parsed == null) {
      return text;
    }

    return MaterialLocalizations.of(context)
        .formatMediumDate(parsed);
  }

  // ======================================
  // THREE-DOT MENU ACTIONS
  // ======================================

  void _handleMenuAction(
      _ReportsMenuAction action,
      ) {
    switch (action) {
      case _ReportsMenuAction.refresh:
        _loadReports();
        break;

      case _ReportsMenuAction.about:
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text(
                'About Medical Reports',
              ),

              content: const Text(
                'Medical Reports provides a '
                    'summary of your saved doctors, '
                    'visits, medicines, and tests.\n\n'
                    'These statistics are calculated '
                    'from your current local '
                    'medical database.\n\n'
                    'They are for record organization '
                    'and are not medical diagnoses.',
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext)
                        .pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
        break;
    }
  }

  // ======================================
  // SECTION TITLE
  // ======================================

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: AppColors.primary,
            ),

            const SizedBox(width: 9),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ======================================
  // PROFESSIONAL STATISTICS CARD
  // ======================================

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color lightColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        // Natural card height prevents
        // fixed-grid overflow warnings.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Container(
              width: 43,
              height: 43,

              decoration: BoxDecoration(
                color: lightColor,
                borderRadius:
                BorderRadius.circular(13),
              ),

              child: Icon(
                icon,
                color: color,
                size: 23,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================
  // RESPONSIVE STATISTICS GRID
  // ======================================

  Widget _buildStatisticsGrid(
      MedicalHistoryCounts counts,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;

        final availableWidth =
            constraints.maxWidth;

        // One column for very narrow screens,
        // two columns for normal phone widths.
        final columns =
        availableWidth < 310 ? 1 : 2;

        final cardWidth = columns == 1
            ? availableWidth
            : (availableWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,

          children: [
            SizedBox(
              width: cardWidth,

              child: _buildStatCard(
                title: 'Total Visits',
                count: counts.visits,
                icon:
                Icons.calendar_month_outlined,
                color: AppColors.visits,
                lightColor: AppColors.visitsLight,
              ),
            ),

            SizedBox(
              width: cardWidth,

              child: _buildStatCard(
                title: 'Doctors',
                count: counts.doctors,
                icon:
                Icons.medical_services_outlined,
                color: AppColors.doctors,
                lightColor: AppColors.doctorsLight,
              ),
            ),

            SizedBox(
              width: cardWidth,

              child: _buildStatCard(
                title: 'Medicines',
                count: counts.medicines,
                icon: Icons.medication_outlined,
                color: AppColors.medicines,
                lightColor:
                AppColors.medicinesLight,
              ),
            ),

            SizedBox(
              width: cardWidth,

              child: _buildStatCard(
                title: 'Medical Tests',
                count: counts.tests,
                icon: Icons.science_outlined,
                color: AppColors.medicalTests,
                lightColor:
                AppColors.medicalTestsLight,
              ),
            ),
          ],
        );
      },
    );
  }

  // ======================================
  // DOCTORS BY VISITS
  // ======================================

  Widget _buildTopDoctors() {
    final topDoctors = _doctors
        .where((doctor) => doctor.visitCount > 0)
        .take(5)
        .toList();

    if (topDoctors.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.medical_services_outlined,
        title: 'No doctor statistics yet',
        subtitle:
        'Doctor visit statistics will '
            'appear after saving visits.',
      );
    }

    final maxVisits =
        topDoctors.first.visitCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            for (int index = 0;
            index < topDoctors.length;
            index++) ...[
              _buildDoctorReportRow(
                topDoctors[index],
                maxVisits,
                index + 1,
              ),

              if (index != topDoctors.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 18,
                  ),
                  child: Divider(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ======================================
  // DOCTOR STATISTICS ROW
  // ======================================

  Widget _buildDoctorReportRow(
      SavedDoctorRecord doctor,
      int maxVisits,
      int position,
      ) {
    final progress = maxVisits > 0
        ? doctor.visitCount / maxVisits
        : 0.0;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,

              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius:
                BorderRadius.circular(10),
              ),

              child: Text(
                '$position',

                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Text(
                    doctor.name,

                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    doctor.specialization
                        .trim()
                        .isEmpty
                        ? 'Specialization not provided'
                        : doctor.specialization,

                    style: const TextStyle(
                      fontSize: 12,
                      color:
                      AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),

              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius:
                BorderRadius.circular(10),
              ),

              child: Text(
                '${doctor.visitCount} '
                    '${doctor.visitCount == 1 ? 'visit' : 'visits'}',

                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 13),

        ClipRRect(
          borderRadius:
          BorderRadius.circular(8),

          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor:
            AppColors.surfaceSoft,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // ======================================
  // RECENT VISITS
  // ======================================

  Widget _buildRecentVisits() {
    if (_recentVisits.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.event_note_outlined,
        title: 'No medical visits yet',
        subtitle:
        'Your latest visits will '
            'appear here after saving.',
      );
    }

    final visits =
    _recentVisits.take(5).toList();

    return Column(
      children: [
        for (final visit in visits)
          Padding(
            padding:
            const EdgeInsets.only(bottom: 10),

            child: _buildVisitCard(visit),
          ),
      ],
    );
  }

  // ======================================
  // RECENT VISIT CARD
  // ======================================

  Widget _buildVisitCard(
      SavedVisitSummary visit,
      ) {
    final reason =
    visit.reason.trim().isEmpty
        ? 'Medical Visit'
        : visit.reason;

    return Card(
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: () => _openVisit(visit),

        child: Padding(
          padding: const EdgeInsets.all(15),

          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Container(
                width: 45,
                height: 45,

                decoration: BoxDecoration(
                  color: AppColors.visitsLight,
                  borderRadius:
                  BorderRadius.circular(13),
                ),

                child: const Icon(
                  Icons.event_note_outlined,
                  color: AppColors.visits,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      reason,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      visit.doctorName,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 13,
                        color:
                        AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: AppColors.primary,
                        ),

                        const SizedBox(width: 6),

                        Flexible(
                          child: Text(
                            _formatDate(
                              visit.visitDate,
                            ),

                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 5),

              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================
  // EMPTY STATE CARD
  // ======================================

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),

        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,

              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius:
                BorderRadius.circular(18),
              ),

              child: Icon(
                icon,
                color: AppColors.primary,
                size: 26,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              title,
              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              subtitle,
              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================
  // ERROR STATE
  // ======================================

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),

            const SizedBox(height: 16),

            Text(
              _errorMessage ??
                  'Unable to load reports.',

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: _loadReports,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================
  // REPORT CONTENT
  // ======================================

  Widget _buildReportContent() {
    final counts = _counts;

    if (counts == null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadReports,

      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(
          18,
          20,
          18,
          35,
        ),

        children: [
          // =================================
          // PAGE INTRODUCTION
          // =================================

          const Text(
            'Your medical overview',

            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'A clear summary of your saved '
                'medical information.',

            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // =================================
          // MEDICAL STATISTICS
          // =================================

          _buildSectionTitle(
            title: 'Medical statistics',
            subtitle:
            'Your actual saved record totals.',
            icon: Icons.bar_chart_outlined,
          ),

          const SizedBox(height: 14),

          _buildStatisticsGrid(counts),

          const SizedBox(height: 30),

          // =================================
          // DOCTORS BY VISITS
          // =================================

          _buildSectionTitle(
            title: 'Doctors by visits',
            subtitle:
            'Your five most visited doctors.',

            // FIXED: This icon exists in Flutter.
            icon:
            Icons.medical_services_outlined,
          ),

          const SizedBox(height: 14),

          _buildTopDoctors(),

          const SizedBox(height: 30),

          // =================================
          // RECENT MEDICAL VISITS
          // =================================

          _buildSectionTitle(
            title: 'Recent medical visits',
            subtitle:
            'Your five most recently saved visits.',
            icon: Icons.history,
          ),

          const SizedBox(height: 14),

          _buildRecentVisits(),

          const SizedBox(height: 24),

          // =================================
          // PRIVACY INFORMATION
          // =================================

          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),

              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 22,
                    color: AppColors.success,
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      'These reports use your '
                          'local medical database. '
                          'They are for record '
                          'organization and do not '
                          'provide medical diagnoses.',

                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================
  // MAIN REPORTS SCREEN
  // ======================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Medical Reports'),

        actions: [
          IconButton(
            tooltip: 'Refresh reports',

            onPressed:
            _isLoading ? null : _loadReports,

            icon: const Icon(Icons.refresh),
          ),

          // =================================
          // THREE-DOT MENU
          // =================================

          PopupMenuButton<_ReportsMenuAction>(
            tooltip: 'More report options',

            icon: const Icon(
              Icons.more_vert,
            ),

            onSelected: _handleMenuAction,

            itemBuilder: (_) => const [
              PopupMenuItem(
                value:
                _ReportsMenuAction.refresh,

                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 12),
                    Text('Refresh reports'),
                  ],
                ),
              ),

              PopupMenuItem(
                value: _ReportsMenuAction.about,

                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Text('About reports'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 4),
        ],
      ),

      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _errorMessage != null
          ? _buildErrorState()
          : _buildReportContent(),
    );
  }
}

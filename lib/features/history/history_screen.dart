
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/medical_history_read_service.dart';
import 'visit_details_screen.dart';

// =====================================
// MEDICAL HISTORY SCREEN
// STEP 35 - CONNECT VISIT DETAILS
// =====================================

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() =>
      _HistoryScreenState();
}

// =====================================
// HISTORY FILTER OPTIONS
// =====================================

enum _HistoryFilter {
  all,
  followUps,
  diagnosed,
}

// =====================================
// HISTORY SCREEN STATE
// =====================================

class _HistoryScreenState extends State<HistoryScreen> {
  // Number of records loaded per page.
  static const int _pageSize = 20;

  // SQLite read service.
  final MedicalHistoryReadService _service =
      MedicalHistoryReadService.instance;

  // =====================================
  // SEARCH
  // =====================================

  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';

  // =====================================
  // SAVED VISITS
  // =====================================

  final List<SavedVisitSummary> _visits = [];

  MedicalHistoryCounts? _counts;

  // =====================================
  // LOADING STATES
  // =====================================

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;

  String? _errorMessage;
  String? _loadMoreError;

  // =====================================
  // FILTER AND EXPANDED CARD
  // =====================================

  _HistoryFilter _selectedFilter =
      _HistoryFilter.all;

  String? _expandedVisitId;

  // =====================================
  // INITIALIZE
  // =====================================

  @override
  void initState() {
    super.initState();

    // Load saved appointments.
    _loadFirstPage();
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
  // LOAD FIRST PAGE
  // =====================================

  Future<void> _loadFirstPage() async {
    if (_isLoading || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadMoreError = null;
    });

    try {
      // Read real record counts.
      final counts =
      await _service.getHistoryCounts();

      // Load newest saved visits.
      final records = await _service.getAllVisits(
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _counts = counts;

        // Replace old loaded records.
        _visits
          ..clear()
          ..addAll(records);

        // Are more visits available?
        _hasMore = _visits.length < counts.visits &&
            records.isNotEmpty;

        // Reset expanded card.
        _expandedVisitId = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
        'Unable to load medical history. '
            'Please check your medical storage '
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
  // LOAD MORE SAVED VISITS
  // =====================================

  Future<void> _loadMore() async {
    if (_isLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final records = await _service.getAllVisits(
        limit: _pageSize,
        offset: _visits.length,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _visits.addAll(records);

        _hasMore = records.isNotEmpty &&
            (_counts == null ||
                _visits.length < _counts!.visits);
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

  // =====================================
  // OPEN COMPLETE VISIT DETAILS
  // =====================================

  Future<void> _openVisitDetails(
      SavedVisitSummary visit,
      ) async {
    // The selected saved visit has
    // its own permanent SQLite ID.

    final visitId = visit.id;

    // Open Step 34's Visit Details screen.
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => VisitDetailsScreen(
          visitId: visitId,
        ),
      ),
    );

    // User has returned from Visit Details.
    if (!mounted) {
      return;
    }

    // Reload database records so changes
    // made elsewhere can be reflected.
    await _loadFirstPage();
  }

  // =====================================
  // SEARCH AND FILTER
  // =====================================

  List<SavedVisitSummary> get _visibleVisits {
    final query =
    _searchText.trim().toLowerCase();

    return _visits.where((visit) {
      // Search across loaded records.
      final matchesSearch = query.isEmpty ||
          visit.doctorName
              .toLowerCase()
              .contains(query) ||
          visit.hospitalName
              .toLowerCase()
              .contains(query) ||
          visit.reason
              .toLowerCase()
              .contains(query) ||
          visit.diagnosis
              .toLowerCase()
              .contains(query) ||
          visit.visitDate.contains(query);

      if (!matchesSearch) {
        return false;
      }

      // Apply selected filter.
      switch (_selectedFilter) {
        case _HistoryFilter.all:
          return true;

        case _HistoryFilter.followUps:
          return visit.followUpDate != null;

        case _HistoryFilter.diagnosed:
          return visit.diagnosis.trim().isNotEmpty;
      }
    }).toList();
  }

  // =====================================
  // FORMAT SAVED DATE
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
  // FORMAT SAVED TIME
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
  // REUSABLE DETAIL FIELD
  // =====================================

  Widget _buildDetail({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

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
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // SAVED VISIT CARD
  // =====================================

  Widget _buildVisitCard(
      SavedVisitSummary visit,
      ) {
    final isExpanded =
        _expandedVisitId == visit.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        // Tap anywhere to expand the summary.
        onTap: () {
          setState(() {
            _expandedVisitId =
            isExpanded ? null : visit.id;
          });
        },

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              // =================================
              // DOCTOR DETAILS
              // =================================

              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor:
                    Color(0xFFE6F2FF),

                    child: Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          visit.doctorName,

                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          visit.hospitalName,

                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,

                    color: AppColors.textSecondary,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              const Divider(height: 1),

              const SizedBox(height: 14),

              // =================================
              // VISIT DATE AND TIME
              // =================================

              Wrap(
                spacing: 18,
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

                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
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

                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =================================
              // VISIT REASON
              // =================================

              Text(
                visit.reason,

                maxLines: isExpanded ? null : 2,

                overflow: isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),

              // =================================
              // FOLLOW-UP
              // =================================

              if (visit.followUpDate != null) ...[
                const SizedBox(height: 12),

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
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              // =================================
              // EXPANDED SUMMARY
              // =================================

              if (isExpanded) ...[
                const SizedBox(height: 18),

                const Divider(),

                const SizedBox(height: 14),

                _buildDetail(
                  label: 'Reason for Visit',
                  value: visit.reason,
                ),

                _buildDetail(
                  label: 'Diagnosis',
                  value: visit.diagnosis,
                ),

                _buildDetail(
                  label: 'Follow-up Date',

                  value: visit.followUpDate == null
                      ? 'Not scheduled'
                      : _formatDate(
                    visit.followUpDate,
                  ),
                ),

                // =================================
                // NEW: VIEW FULL DETAILS
                // =================================

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,

                  child: FilledButton.icon(
                    onPressed: () {
                      _openVisitDetails(visit);
                    },

                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 19,
                    ),

                    label: const Text(
                      'View Full Details',
                    ),
                  ),
                ),
              ] else ...[
                // Small hint below a collapsed card.
                const SizedBox(height: 12),

                const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.end,

                  children: [
                    Text(
                      'Tap to view summary',

                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),

                    SizedBox(width: 4),

                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 17,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // EMPTY HISTORY STATE
  // =====================================

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 40,
        horizontal: 12,
      ),

      child: Column(
        children: [
          const Icon(
            Icons.history_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),

          const SizedBox(height: 16),

          const Text(
            'No Medical Visits Yet',

            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Your saved appointments will '
                'appear here after you save '
                'your first medical visit.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: _loadFirstPage,

            icon: const Icon(Icons.refresh),

            label: const Text('Check Again'),
          ),
        ],
      ),
    );
  }

  // =====================================
  // NO SEARCH MATCHES
  // =====================================

  Widget _buildNoMatches() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),

      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AppColors.textSecondary,
          ),

          SizedBox(height: 12),

          Text(
            'No Matching Visits',

            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Try a different search or filter. '
                'You can also load more visits.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // ERROR STATE
  // =====================================

  Widget _buildErrorState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 38,
            ),

            const SizedBox(height: 12),

            Text(
              message,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _loadFirstPage,

              icon: const Icon(Icons.refresh),

              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // BUILD HISTORY SCREEN
  // =====================================

  @override
  Widget build(BuildContext context) {
    final visibleVisits = _visibleVisits;

    return Scaffold(
      backgroundColor: AppColors.background,

      // =====================================
      // APP BAR
      // =====================================

      appBar: AppBar(
        title: const Text('Medical History'),

        actions: [
          IconButton(
            tooltip: 'Refresh Medical History',

            onPressed: _isLoading || _isLoadingMore
                ? null
                : _loadFirstPage,

            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // =====================================
      // BODY
      // =====================================

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFirstPage,

          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.all(16),

            children: [
              // =================================
              // PAGE TITLE
              // =================================

              const Text(
                'Your Medical History',

                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'View your saved doctor visits '
                    'and appointment records.',

                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // =================================
              // TOTAL VISIT COUNT
              // =================================

              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2FF),

                  borderRadius:
                  BorderRadius.circular(14),
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_copy_outlined,
                      size: 32,
                      color: AppColors.primary,
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [
                          Text(
                            _counts == null
                                ? '--'
                                : '${_counts!.visits}',

                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),

                          const Text(
                            'Saved Medical Visits',

                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // =================================
              // SEARCH FIELD
              // =================================

              TextField(
                controller: _searchController,

                decoration: InputDecoration(
                  hintText:
                  'Search doctor, hospital, reason...',

                  prefixIcon:
                  const Icon(Icons.search),

                  suffixIcon: _searchText.isEmpty
                      ? null
                      : IconButton(
                    tooltip: 'Clear Search',

                    icon: const Icon(Icons.close),

                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _searchText = '';
                      });
                    },
                  ),
                ),

                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              ),

              const SizedBox(height: 14),

              // =================================
              // FILTER CHIPS
              // =================================

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,

                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All Visits'),

                      selected: _selectedFilter ==
                          _HistoryFilter.all,

                      onSelected: (_) {
                        setState(() {
                          _selectedFilter =
                              _HistoryFilter.all;
                        });
                      },
                    ),

                    const SizedBox(width: 8),

                    ChoiceChip(
                      label: const Text(
                        'Has Follow-up',
                      ),

                      selected: _selectedFilter ==
                          _HistoryFilter.followUps,

                      onSelected: (_) {
                        setState(() {
                          _selectedFilter =
                              _HistoryFilter.followUps;
                        });
                      },
                    ),

                    const SizedBox(width: 8),

                    ChoiceChip(
                      label: const Text(
                        'With Diagnosis',
                      ),

                      selected: _selectedFilter ==
                          _HistoryFilter.diagnosed,

                      onSelected: (_) {
                        setState(() {
                          _selectedFilter =
                              _HistoryFilter.diagnosed;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // =================================
              // RECORD INFORMATION
              // =================================

              Text(
                'Showing ${visibleVisits.length} '
                    'of ${_visits.length} loaded visits',

                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Search and filters apply to '
                    'currently loaded visits.',

                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // =================================
              // LOADING
              // =================================

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(35),

                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              // =================================
              // DATABASE ERROR
              // =================================

              if (!_isLoading &&
                  _errorMessage != null)
                _buildErrorState(_errorMessage!),

              // =================================
              // NO SAVED VISITS
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  _visits.isEmpty)
                _buildEmptyState(),

              // =================================
              // NO MATCHES
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  _visits.isNotEmpty &&
                  visibleVisits.isEmpty)
                _buildNoMatches(),

              // =================================
              // SAVED VISIT CARDS
              // =================================

              if (!_isLoading &&
                  _errorMessage == null)
                for (final visit in visibleVisits)
                  _buildVisitCard(visit),

              // =================================
              // LOAD MORE ERROR
              // =================================

              if (!_isLoading &&
                  _loadMoreError != null) ...[
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
              // LOAD MORE
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  _hasMore) ...[
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _isLoadingMore
                      ? null
                      : _loadMore,

                  icon: _isLoadingMore
                      ? const SizedBox(
                    width: 18,
                    height: 18,

                    child: CircularProgressIndicator(
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
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

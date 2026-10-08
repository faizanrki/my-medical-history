
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_database.dart';
import '../../services/medical_history_read_service.dart';

import '../auth/google_signin_screen.dart';
import '../doctors/doctors_screen.dart';
import '../history/history_screen.dart';
import '../history/visit_details_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../visits/add_visit_screen.dart';

// =========================================
// MY MEDICAL HISTORY
// PROFESSIONAL DASHBOARD
// =========================================

enum _HomeMenuAction {
  refresh,
  settings,
  about,
  signOut,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {

  // =====================================
  // DATABASE SERVICE
  // =====================================

  final MedicalHistoryReadService _readService =
      MedicalHistoryReadService.instance;

  // =====================================
  // STATE
  // =====================================

  int _selectedIndex = 0;
  int _loadGeneration = 0;

  MedicalHistoryCounts? _counts;

  List<SavedVisitSummary> _recentVisits = [];

  bool _isLoading = true;
  bool _isSigningOut = false;

  String? _errorMessage;

  // =====================================
  // INITIALIZE
  // =====================================

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // =====================================
  // LOAD DASHBOARD DATA
  // =====================================

  Future<void> _loadDashboard() async {
    if (_isSigningOut || !mounted) return;

    final generation = ++_loadGeneration;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get real medical record counts.
      final counts =
      await _readService.getHistoryCounts();

      // Load the latest 30 visits.
      final visits =
      await _readService.getAllVisits(
        limit: 30,
        offset: 0,
      );

      if (!mounted ||
          generation != _loadGeneration ||
          _isSigningOut) {
        return;
      }

      setState(() {
        _counts = counts;
        _recentVisits = visits;
      });
    } catch (_) {
      if (!mounted ||
          generation != _loadGeneration ||
          _isSigningOut) {
        return;
      }

      setState(() {
        _errorMessage =
        'Unable to refresh dashboard data. '
            'Please try again.';
      });
    } finally {
      if (mounted &&
          generation == _loadGeneration &&
          !_isSigningOut) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =====================================
  // CHANGE BOTTOM TAB
  // =====================================

  void _changeTab(int index) {
    if (!mounted || _isSigningOut) return;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      _loadDashboard();
    }
  }

  // =====================================
  // OPEN ADD VISIT
  // =====================================

  Future<void> _openAddVisit() async {
    if (_isSigningOut) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AddVisitScreen(),
      ),
    );

    if (mounted &&
        _selectedIndex == 0 &&
        !_isSigningOut) {
      await _loadDashboard();
    }
  }

  // =====================================
  // OPEN VISIT DETAILS
  // =====================================

  Future<void> _openVisitDetails(
      String visitId,
      ) async {
    if (_isSigningOut) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VisitDetailsScreen(
          visitId: visitId,
        ),
      ),
    );

    if (mounted &&
        _selectedIndex == 0 &&
        !_isSigningOut) {
      await _loadDashboard();
    }
  }

  // =====================================
  // DATE FORMATTING
  // =====================================

  String _formatDate(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Not scheduled';
    }

    final date = DateTime.tryParse(text);

    if (date == null) return text;

    return MaterialLocalizations.of(context)
        .formatMediumDate(date);
  }

  // =====================================
  // TIME FORMATTING
  // =====================================

  String _formatTime(String text) {
    final parts = text.split(':');

    if (parts.length != 2) return text;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return text;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    ).format(context);
  }

  // =====================================
  // UPCOMING FOLLOW-UPS
  // =====================================

  List<SavedVisitSummary> get _upcomingFollowUps {
    final today =
    DateUtils.dateOnly(DateTime.now());

    final upcoming = _recentVisits.where((visit) {
      final date = DateTime.tryParse(
        visit.followUpDate ?? '',
      );

      return date != null &&
          !DateUtils.dateOnly(date).isBefore(today);
    }).toList();

    upcoming.sort(
          (a, b) => a.followUpDate!.compareTo(
        b.followUpDate!,
      ),
    );

    return upcoming.take(3).toList();
  }

  // =====================================
  // THREE-DOT MENU ACTIONS
  // =====================================

  Future<void> _handleMenuAction(
      _HomeMenuAction action,
      ) async {
    switch (action) {
      case _HomeMenuAction.refresh:
        await _loadDashboard();
        return;

      case _HomeMenuAction.settings:
        _changeTab(4);
        return;

      case _HomeMenuAction.about:
        if (!mounted) return;

        showAboutDialog(
          context: context,
          applicationName: 'My Medical History',
          applicationIcon: const Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.primary,
            size: 36,
          ),
          children: const [
            Text(
              'Organize doctor visits, '
                  'medicines and medical tests.',
            ),
            SizedBox(height: 8),
            Text(
              'Google Drive backup '
                  'is not enabled yet.',
            ),
          ],
        );
        return;

      case _HomeMenuAction.signOut:
        await _signOutFromMenu();
        return;
    }
  }

  // =====================================
  // GOOGLE SIGN OUT
  // =====================================

  Future<void> _signOutFromMenu() async {
    if (_isSigningOut || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Sign out of Google?',
          ),
          content: const Text(
            'Access to this account\'s '
                'medical records will be locked.\n\n'
                'Your saved records will not '
                'be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isSigningOut = true;

      // Ignore older dashboard requests.
      _loadGeneration++;
    });

    // =====================================
    // LOCK MEDICAL STORAGE FIRST
    // =====================================

    try {
      await AppDatabase.instance.lockAccount();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Could not lock medical storage. '
                  'Sign-out was cancelled.',
            ),
          ),
        );
      }

      return;
    }

    // =====================================
    // GOOGLE SESSION SIGN OUT
    // =====================================

    String notice =
        'Signed out. Sign in again '
        'to access your records.';

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      notice =
      'Medical storage is locked, '
          'but Google sign-out could not '
          'be confirmed. Please check '
          'your Google account.';
    }

    if (!mounted) return;

    // =====================================
    // RETURN TO SIGN-IN SCREEN
    // =====================================

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => GoogleSignInScreen(
          skipAutomaticSignIn: true,
          notice: notice,
        ),
      ),
          (route) => false,
    );
  }

  // =====================================
  // PROFESSIONAL STATISTICS CARD
  // =====================================

  Widget _buildStatCard({
    required String title,
    required int? count,
    required IconData icon,
    required Color color,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _isSigningOut ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              // Icon box
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),

              // Actual database count
              Text(
                count?.toString() ?? '--',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                ),
              ),

              // Category label
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // RECENT VISIT CARD
  // =====================================

  Widget _buildRecentVisitCard(
      SavedVisitSummary visit,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            _openVisitDetails(visit.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.doctorsLight,
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: const Icon(
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
                        visit.doctorName,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        visit.reason,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                          AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        '${_formatDate(visit.visitDate)} '
                            ' • '
                            '${_formatTime(visit.visitTime)}',
                        maxLines: 2,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================
  // FOLLOW-UP CARD
  // =====================================

  Widget _buildFollowUpCard(
      SavedVisitSummary visit,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 8,
          ),

          leading: const CircleAvatar(
            backgroundColor:
            AppColors.successLight,
            child: Icon(
              Icons.event_available_outlined,
              color: AppColors.success,
            ),
          ),

          title: Text(
            visit.doctorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          subtitle: Text(
            'Follow-up: '
                '${_formatDate(visit.followUpDate)}',
          ),

          trailing:
          const Icon(Icons.chevron_right),

          onTap: () {
            _openVisitDetails(visit.id);
          },
        ),
      ),
    );
  }

  // =====================================
  // EMPTY STATE CARD
  // =====================================

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              icon,
              size: 33,
              color: AppColors.textMuted,
            ),

            const SizedBox(height: 10),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // HOME SCREEN
  // =====================================

  Widget _buildHomeScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,

      // =====================================
      // PROFESSIONAL APP BAR
      // =====================================

      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(9),
          child: Image.asset(
            'assets/images/'
                'my_medical_history_splash_icon.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.primary,
              );
            },
          ),
        ),

        title: const Text(
          'My Medical History',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        actions: [
          // Refresh button
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed:
            _isLoading || _isSigningOut
                ? null
                : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),

          // =====================================
          // PROFESSIONAL THREE-DOT MENU
          // =====================================

          PopupMenuButton<_HomeMenuAction>(
            tooltip: 'More options',
            enabled: !_isSigningOut,
            icon: const Icon(Icons.more_vert),

            onSelected: (value) {
              _handleMenuAction(value);
            },

            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HomeMenuAction.refresh,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh data'),
                ),
              ),

              PopupMenuItem(
                value: _HomeMenuAction.settings,
                child: ListTile(
                  dense: true,
                  leading:
                  Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),

              PopupMenuItem(
                value: _HomeMenuAction.about,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.info_outline),
                  title: Text('About app'),
                ),
              ),

              PopupMenuDivider(),

              PopupMenuItem(
                value: _HomeMenuAction.signOut,
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.logout,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Sign out',
                    style: TextStyle(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 4),
        ],
      ),

      // =====================================
      // DASHBOARD BODY
      // =====================================

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,

          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              30,
            ),

            children: [
              // =================================
              // WELCOME HEADER
              // =================================

              const Text(
                'Your health overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Your medical information, '
                    'organized in one place.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 22),

              // =================================
              // LOADING STATE
              // =================================

              if (_isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 18),
              ],

              // =================================
              // DATABASE ERROR
              // =================================

              if (_errorMessage != null) ...[
                Card(
                  child: Padding(
                    padding:
                    const EdgeInsets.all(16),

                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        TextButton.icon(
                          onPressed: _loadDashboard,
                          icon: const Icon(
                            Icons.refresh,
                          ),
                          label:
                          const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
              ],

              // =================================
              // MEDICAL OVERVIEW
              // =================================

              const Text(
                'Medical overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              // Fixed-height grid prevents
              // the previous card overflow.
              GridView(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),

                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 155,
                ),

                children: [
                  _buildStatCard(
                    title: 'Doctors',
                    count: _counts?.doctors,
                    icon: Icons.medical_services_outlined,
                    color: AppColors.doctors,
                    tint: AppColors.doctorsLight,
                    onTap: () => _changeTab(1),
                  ),

                  _buildStatCard(
                    title: 'Visits',
                    count: _counts?.visits,
                    icon: Icons.calendar_month_outlined,
                    color: AppColors.visits,
                    tint: AppColors.visitsLight,
                    onTap: () => _changeTab(2),
                  ),

                  _buildStatCard(
                    title: 'Medicines',
                    count: _counts?.medicines,
                    icon: Icons.medication_outlined,
                    color: AppColors.medicines,
                    tint: AppColors.medicinesLight,
                    onTap: () => _changeTab(2),
                  ),

                  _buildStatCard(
                    title: 'Medical Tests',
                    count: _counts?.tests,
                    icon: Icons.science_outlined,
                    color: AppColors.medicalTests,
                    tint: AppColors.medicalTestsLight,
                    onTap: () => _changeTab(2),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // =================================
              // QUICK ACTIONS
              // =================================

              const Text(
                'Quick actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSigningOut
                          ? null
                          : _openAddVisit,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        size: 20,
                      ),
                      label:
                      const Text('Add Visit'),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSigningOut
                          ? null
                          : () => _changeTab(2),
                      icon: const Icon(
                        Icons.history,
                        size: 20,
                      ),
                      label:
                      const Text('History'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // =================================
              // RECENT VISITS HEADER
              // =================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

                children: [
                  const Text(
                    'Recent visits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  TextButton(
                    onPressed: () => _changeTab(2),
                    child: const Text('View all'),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // =================================
              // RECENT VISITS LIST
              // =================================

              if (!_isLoading &&
                  _errorMessage == null &&
                  _recentVisits.isEmpty)
                _buildEmptyCard(
                  icon: Icons.folder_open_outlined,
                  title: 'No saved visits yet',
                  subtitle:
                  'Visits will appear here '
                      'after you save them.',
                ),

              if (!_isLoading &&
                  _errorMessage == null)
                for (final visit
                in _recentVisits.take(5))
                  _buildRecentVisitCard(visit),

              const SizedBox(height: 25),

              // =================================
              // UPCOMING FOLLOW-UPS
              // =================================

              const Text(
                'Upcoming follow-ups',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Based on follow-up dates '
                    'in your 30 most recent visits.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 12),

              if (!_isLoading &&
                  _errorMessage == null &&
                  _upcomingFollowUps.isEmpty)
                _buildEmptyCard(
                  icon:
                  Icons.event_available_outlined,
                  title: 'No upcoming follow-ups',
                  subtitle:
                  'Future follow-up appointments '
                      'will appear here.',
                ),

              if (!_isLoading &&
                  _errorMessage == null)
                for (final visit
                in _upcomingFollowUps)
                  _buildFollowUpCard(visit),

              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // SELECT CURRENT TAB
  // =====================================

  Widget _buildSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeScreen();

      case 1:
        return const DoctorsScreen();

      case 2:
        return const HistoryScreen();

      case 3:
        return const ReportsScreen();

      case 4:
        return SettingsScreen(
          onOpenDoctors: () {
            _changeTab(1);
          },
          onOpenHistory: () {
            _changeTab(2);
          },
        );

      default:
        return _buildHomeScreen();
    }
  }

  // =====================================
  // MAIN DASHBOARD WITH NAVIGATION
  // =====================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSigningOut,

      child: Scaffold(
        body: _buildSelectedScreen(),

        // =================================
        // BOTTOM NAVIGATION
        // =================================

        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,

          onDestinationSelected:
          _isSigningOut ? null : _changeTab,

          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),

            NavigationDestination(
              icon: Icon(
                Icons.medical_services_outlined,
              ),
              selectedIcon: Icon(
                Icons.medical_services,
              ),
              label: 'Doctors',
            ),

            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),

            NavigationDestination(
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment),
              label: 'Reports',
            ),

            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

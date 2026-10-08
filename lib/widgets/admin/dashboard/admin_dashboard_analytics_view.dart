import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../screens/admin/pets/admin_pets_screen.dart';
import '../../../screens/admin/reports/admin_reports_screen.dart';
import '../../../services/admin/admin_analytics_service.dart';
import 'admin_dashboard_kpi_cards.dart';
import 'admin_date_range_selector.dart';
import 'lost_vs_found_trend_chart.dart';
import 'pet_demographics_donut_charts.dart';
import 'user_registration_growth_chart.dart';

class AdminDashboardAnalyticsView extends StatefulWidget {
  final String adminBarangay;
  final List<Map<String, dynamic>>? pendingReports;
  final List<Map<String, dynamic>>? recentActivity;

  const AdminDashboardAnalyticsView({
    super.key,
    required this.adminBarangay,
    this.pendingReports,
    this.recentActivity,
  });

  @override
  State<AdminDashboardAnalyticsView> createState() =>
      _AdminDashboardAnalyticsViewState();
}

class _AdminDashboardAnalyticsViewState
    extends State<AdminDashboardAnalyticsView> {
  DashboardDateRange _selectedRange = DashboardDateRange.thisMonth;
  TrendGranularity _selectedGranularity = TrendGranularity.daily;
  bool _isLoading = true;
  DashboardAnalyticsData? _data;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void didUpdateWidget(covariant AdminDashboardAnalyticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminBarangay != widget.adminBarangay) {
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final data = await AdminAnalyticsService.instance.fetchDashboardAnalytics(
      barangay: widget.adminBarangay,
      dateRange: _selectedRange,
      granularity: _selectedGranularity,
    );
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  void _onRangeChanged(DashboardDateRange range) {
    TrendGranularity newGranularity = _selectedGranularity;
    if (range == DashboardDateRange.thisMonth) {
      newGranularity = TrendGranularity.daily;
    } else if (range == DashboardDateRange.last3Months) {
      newGranularity = TrendGranularity.weekly;
    } else if (range == DashboardDateRange.thisYear || range == DashboardDateRange.allTime) {
      newGranularity = TrendGranularity.monthly;
    }

    setState(() {
      _selectedRange = range;
      _selectedGranularity = newGranularity;
    });
    _loadAnalytics();
  }

  void _onGranularityChanged(TrendGranularity g) {
    setState(() => _selectedGranularity = g);
    _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _data ??
        DashboardAnalyticsData(
          activeLostReports: 0,
          foundThisMonth: 0,
          avgRecoveryHours: 0,
          recoveryTrendChangePercent: 0,
          collarPairingPercent: 0,
          totalPets: 0,
          pairedPets: 0,
          lostVsFoundTrends: [],
          aiConfidenceDistribution: {},
          userGrowth: [],
          catCount: 0,
          dogCount: 0,
          otherSpeciesCount: 0,
          activePetCount: 0,
          lostPetCount: 0,
          archivedPetCount: 0,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter bar header (responsive to avoid right overflow)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 680;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operations & Analytics',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.adminBarangay.isNotEmpty
                            ? 'Brgy. ${widget.adminBarangay} real-time reporting'
                            : 'Barangay real-time reporting',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: AdminDateRangeSelector(
                      selectedRange: _selectedRange,
                      onRangeChanged: _onRangeChanged,
                    ),
                  ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operations & Analytics',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.adminBarangay.isNotEmpty
                            ? 'Brgy. ${widget.adminBarangay} real-time reporting'
                            : 'Barangay real-time reporting',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AdminDateRangeSelector(
                  selectedRange: _selectedRange,
                  onRangeChanged: _onRangeChanged,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Section 1: Top 4 KPI Cards
        AdminDashboardKpiCards(
          data: analytics,
          isLoading: _isLoading,
          onActiveLostTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminReportsScreen(initialFilterIndex: 1),
            ),
          ),
          onFoundTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminReportsScreen(initialFilterIndex: 2),
            ),
          ),
          onCollarTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminPetsScreen()),
          ),
        ),
        const SizedBox(height: 12),

        // Section 2: 2-Column Responsive Operational Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column (flex 6): Lost vs Found Trend + Pet Demographics
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        LostVsFoundTrendChart(
                          trendData: analytics.lostVsFoundTrends,
                          currentGranularity: _selectedGranularity,
                          onGranularityChanged: _onGranularityChanged,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 12),
                        PetDemographicsDonutCharts(
                          catCount: analytics.catCount,
                          dogCount: analytics.dogCount,
                          otherSpeciesCount: analytics.otherSpeciesCount,
                          activePetCount: analytics.activePetCount,
                          lostPetCount: analytics.lostPetCount,
                          archivedPetCount: analytics.archivedPetCount,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right Column (flex 5): User Growth + Operations Hub
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        UserRegistrationGrowthChart(
                          growthData: analytics.userGrowth,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 12),
                        _DashboardOperationsHubCard(
                          adminBarangay: widget.adminBarangay,
                          pendingReports: widget.pendingReports ?? const [],
                          recentActivity: widget.recentActivity ?? const [],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Mobile / Narrow layout: Sequential
            return Column(
              children: [
                LostVsFoundTrendChart(
                  trendData: analytics.lostVsFoundTrends,
                  currentGranularity: _selectedGranularity,
                  onGranularityChanged: _onGranularityChanged,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 12),
                PetDemographicsDonutCharts(
                  catCount: analytics.catCount,
                  dogCount: analytics.dogCount,
                  otherSpeciesCount: analytics.otherSpeciesCount,
                  activePetCount: analytics.activePetCount,
                  lostPetCount: analytics.lostPetCount,
                  archivedPetCount: analytics.archivedPetCount,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 12),
                UserRegistrationGrowthChart(
                  growthData: analytics.userGrowth,
                  isLoading: _isLoading,
                ),
                if ((widget.pendingReports != null && widget.pendingReports!.isNotEmpty) ||
                    (widget.recentActivity != null && widget.recentActivity!.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  _DashboardOperationsHubCard(
                    adminBarangay: widget.adminBarangay,
                    pendingReports: widget.pendingReports ?? const [],
                    recentActivity: widget.recentActivity ?? const [],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Compact tabbed Operations Hub for Lost Pet Reports and Recent Activity
class _DashboardOperationsHubCard extends StatefulWidget {
  final String adminBarangay;
  final List<Map<String, dynamic>> pendingReports;
  final List<Map<String, dynamic>> recentActivity;

  const _DashboardOperationsHubCard({
    required this.adminBarangay,
    required this.pendingReports,
    required this.recentActivity,
  });

  @override
  State<_DashboardOperationsHubCard> createState() =>
      _DashboardOperationsHubCardState();
}

class _DashboardOperationsHubCardState
    extends State<_DashboardOperationsHubCard> {
  int _activeTab = 0; // 0: Lost Reports, 1: Activity

  String _formatRelativeTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tab Buttons + View All Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabPill(
                      index: 0,
                      label: 'Lost Reports',
                      countBadge: widget.pendingReports.length,
                    ),
                    _buildTabPill(
                      index: 1,
                      label: 'Recent Activity',
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
                ),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 13, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Content Box (~220px height)
          SizedBox(
            height: 220,
            child: _activeTab == 0
                ? _buildReportsList()
                : _buildActivityList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required int index,
    required String label,
    int? countBadge,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
            if (countBadge != null && countBadge > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$countBadge',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    if (widget.pendingReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 28, color: Colors.grey.shade400),
            const SizedBox(height: 4),
            Text(
              'No pending verification reports',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    final displayItems = widget.pendingReports.take(3).toList();
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayItems.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0x0F000000)),
      itemBuilder: (context, index) {
        final report = displayItems[index];
        final pet = report['pets'];
        final petName = pet is Map
            ? (pet['name']?.toString() ?? 'Unknown Pet')
            : 'Unknown Pet';
        final petPhoto =
            pet is Map ? (pet['photo_url']?.toString() ?? '') : '';
        final location =
            report['barangay']?.toString() ?? widget.adminBarangay;
        final status =
            (report['status']?.toString() ?? 'pending').toUpperCase();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage:
                    petPhoto.isNotEmpty ? NetworkImage(petPhoto) : null,
                child: petPhoto.isEmpty
                    ? const Icon(Icons.pets, size: 14, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            petName,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            location,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 26,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminReportsScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Review',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityList() {
    if (widget.recentActivity.isEmpty) {
      return Center(
        child: Text(
          'No recent activity',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: const Color(0xFF94A3B8),
          ),
        ),
      );
    }

    final displayItems = widget.recentActivity.take(3).toList();
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final act = displayItems[index];
        final desc = act['description']?.toString() ?? '';
        final color = (act['color'] as Color?) ?? AppColors.primary;
        final ts = act['timestamp']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ts.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        _formatRelativeTime(ts),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

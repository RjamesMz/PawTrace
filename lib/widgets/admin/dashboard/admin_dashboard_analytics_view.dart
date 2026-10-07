import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  const AdminDashboardAnalyticsView({
    super.key,
    required this.adminBarangay,
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
        const SizedBox(height: 20),

        // Section 2: Core Operational Charts
        LostVsFoundTrendChart(
          trendData: analytics.lostVsFoundTrends,
          currentGranularity: _selectedGranularity,
          onGranularityChanged: _onGranularityChanged,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 20),

        // Section 3: Community Demographics (Side-by-Side Donut charts)
        PetDemographicsDonutCharts(
          catCount: analytics.catCount,
          dogCount: analytics.dogCount,
          otherSpeciesCount: analytics.otherSpeciesCount,
          activePetCount: analytics.activePetCount,
          lostPetCount: analytics.lostPetCount,
          archivedPetCount: analytics.archivedPetCount,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 20),

        // Section 5: User Registration Growth
        UserRegistrationGrowthChart(
          growthData: analytics.userGrowth,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

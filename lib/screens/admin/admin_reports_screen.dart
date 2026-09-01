import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';

/// Admin Reports Screen — barangay-scoped lost pet reports with filter chips,
/// report cards, and a "Mark as Verified" review button.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _supabase = Supabase.instance.client;

  String _adminBarangay = '';
  bool _isLoading = true;
  int _filterIndex = 0;

  List<Map<String, dynamic>> _reports = [];

  static const List<String> _filterLabels = ['All', 'Recent', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    await _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('lost_reports')
          .select('*, pets(*), owner_id(*)')
          .eq('barangay', _adminBarangay)
          .order('reported_at', ascending: false);
      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list = List.from(_reports);
    switch (_filterIndex) {
      case 1: // Recent — last 7 days
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        list = list.where((r) {
          final ts = r['reported_at']?.toString() ?? '';
          if (ts.isEmpty) return false;
          try {
            return DateTime.parse(ts).isAfter(weekAgo);
          } catch (_) {
            return false;
          }
        }).toList();
        break;
      case 2: // Urgent — status pending or active
        list = list.where((r) {
          final status = (r['status'] ?? '').toString().toLowerCase();
          return status == 'pending' || status == 'active';
        }).toList();
        break;
    }
    return list;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _fetchReports,
                    color: AppColors.primary,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                            child: _buildFilterChips(),
                          ),
                        ),
                        _filtered.isEmpty
                            ? SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.description_outlined,
                                            size: 48,
                                            color: Colors.grey.shade300),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No reports found.',
                                          style: GoogleFonts.inter(
                                              color: AppColors.onSurfaceVariant
                                                  .withOpacity(0.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final report = _filtered[index];
                                    return Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          20,
                                          0,
                                          20,
                                          index == _filtered.length - 1
                                              ? 20
                                              : 16),
                                      child: _buildReportCard(report),
                                    );
                                  },
                                  childCount: _filtered.length,
                                ),
                              ),
                      ],
                    ),
                  ),
          ),
          const BottomNavBar(currentIndex: 2),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding:
          EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Lost Reports',
                  style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface)),
              Text('Brgy. $_adminBarangay',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_reports.length} Reports',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _filterIndex;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: active
                        ? Colors.transparent
                        : AppColors.outlineVariant.withOpacity(0.2)),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color:
                                AppColors.primaryContainer.withOpacity(0.25),
                            blurRadius: 8)
                      ]
                    : [],
              ),
              child: Text(
                _filterLabels[i],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.onPrimaryContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final petData = report['pets'] as Map<String, dynamic>?;
    final userData = report['owner_id'] is Map<String, dynamic>
        ? report['owner_id'] as Map<String, dynamic>
        : null;

    final petName = petData?['name'] as String? ?? 'Unknown';
    final breed = petData?['breed'] as String? ?? 'Unknown Breed';
    final imageUrl =
        report['photo_url'] as String? ?? petData?['photo_url'] as String? ?? '';
    final location = report['last_seen_address'] as String? ??
        report['barangay'] as String? ??
        'Calatagan';
    final note = report['description'] as String? ?? '';
    final timeAgo = _formatTimeAgo(report['reported_at']);

    final ownerName = userData != null
        ? [
            userData['first_name'],
            userData['middle_name'],
            userData['surname'],
            userData['suffix']
          ]
            .where((s) => s != null && s.toString().isNotEmpty)
            .join(' ')
        : 'Unknown Owner';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full-width pet photo
          SizedBox(
            height: 220,
            width: double.infinity,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Center(
                          child: Icon(Icons.pets,
                              size: 72,
                              color: AppColors.primaryContainer)),
                    ),
                  )
                : Container(
                    color: AppColors.surfaceContainerHigh,
                    child: const Center(
                        child: Icon(Icons.pets,
                            size: 72,
                            color: AppColors.primaryContainer)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pet name + LOST badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(petName,
                              style: GoogleFonts.montserrat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface)),
                          const SizedBox(height: 2),
                          Text(breed,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(
                          'LOST',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                              letterSpacing: 0.8)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Location
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(location,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant))),
                ]),
                const SizedBox(height: 10),
                // Owner
                Row(children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text('Owner: $ownerName',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant))),
                ]),
                const SizedBox(height: 10),
                // Time ago
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(timeAgo,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant)),
                ]),
                // Description
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(note,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.onSurfaceVariant)),
                ],
                const SizedBox(height: 16),
                // Contact Owner + View Map
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Contact Owner'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: AppColors.outlineVariant
                                .withOpacity(0.28)),
                        foregroundColor: AppColors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('View Map'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }
}

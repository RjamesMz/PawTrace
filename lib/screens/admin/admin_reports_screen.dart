import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_content_wrapper.dart';
import '../../widgets/admin_layout.dart';
import 'web/admin_web_layout.dart';

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
  UserRole _currentUserRole = UserRole.admin;
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
    _currentUserRole = await AuthService.instance.getCurrentUserRole();
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    await _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('lost_reports')
          .select('*, pets(*), owner_id(*)');

      if (_currentUserRole != UserRole.superAdmin && _adminBarangay.isNotEmpty) {
        query = query.eq('barangay', _adminBarangay);
      }

      final data = await query.order('reported_at', ascending: false);
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
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AdminLayout(
        currentIndex: 2,
        pageTitle: 'Lost Reports',
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    if (_isLoading) {
      return const AdminWebLayout(
        currentIndex: 2,
        pageTitle: 'Lost Reports',
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(60.0),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return AdminWebLayout(
      currentIndex: 2,
      pageTitle: 'Lost Reports',
      body: _buildDesktopContent(),
    );
  }

  Widget _buildDesktopContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips Row
        _buildFilterChips(),
        const SizedBox(height: 20),

        // PaginatedDataTable inside Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(
              cardColor: Colors.white,
              dividerColor: Colors.grey.shade200,
            ),
            child: PaginatedDataTable(
              header: Row(
                children: [
                  Text(
                    'Lost Pet Reports (${_filtered.length})',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _fetchReports,
                  ),
                ],
              ),
              rowsPerPage: 10,
              showFirstLastButtons: true,
              columns: const [
                DataColumn(label: Text('Photo')),
                DataColumn(label: Text('Pet Name')),
                DataColumn(label: Text('Owner')),
                DataColumn(label: Text('Location')),
                DataColumn(label: Text('Date Reported')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              source: _ReportsDataTableSource(
                _filtered,
                onContact: _showContactDialog,
                onViewMap: _showLocationDialog,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showContactDialog(Map<String, dynamic> report) {
    final owner = report['owner_id'];
    final ownerName = owner is Map
        ? '${owner['first_name'] ?? ''} ${owner['surname'] ?? ''}'.trim()
        : 'Unknown Owner';
    final phone = owner is Map ? (owner['phone']?.toString() ?? '') : '';
    final email = owner is Map ? (owner['email']?.toString() ?? '') : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.contact_phone_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text('Owner Contact',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $ownerName',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Phone: ${phone.isNotEmpty ? phone : 'Not provided'}',
                style: GoogleFonts.inter()),
            const SizedBox(height: 4),
            Text('Email: ${email.isNotEmpty ? email : 'Not provided'}',
                style: GoogleFonts.inter()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog(Map<String, dynamic> report) {
    final pet = report['pets'];
    final petName = pet is Map ? (pet['name']?.toString() ?? 'Pet') : 'Pet';
    final location = report['barangay']?.toString() ??
        report['last_seen_address']?.toString() ??
        'Catanduanes';
    final note = report['notes']?.toString() ??
        report['description']?.toString() ??
        '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.map_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text('Last Known Location',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pet: $petName',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location, style: GoogleFonts.inter()),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Notes: $note',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1200;
                      return isWide
                          ? _buildWideReports()
                          : _buildNarrowReports();
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNarrowReports() {
    return AdminContentWrapper(
      maxWidth: 1000,
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
                            index == _filtered.length - 1 ? 20 : 16),
                        child: _buildReportCard(report),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildWideReports() {
    return AdminContentWrapper(
      maxWidth: 1000,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: _buildFilterChips(),
            ),
          ),
          if (_filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No reports found.',
                          style: GoogleFonts.inter(
                              color:
                                  AppColors.onSurfaceVariant.withOpacity(0.5))),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 540,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 520,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildReportCard(_filtered[index]),
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    // Hidden on web — AdminLayout provides the top bar
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 800) return const SizedBox.shrink();
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = MediaQuery.of(context).size.width >= 800;
              final photoHeight = isWide ? 160.0 : 220.0;
              return SizedBox(
                height: photoHeight,
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
              );
            },
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
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant),
                  ),
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

/// DataTableSource for AdminReportsScreen on desktop web.
class _ReportsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> reports;
  final Function(Map<String, dynamic> report) onContact;
  final Function(Map<String, dynamic> report) onViewMap;

  _ReportsDataTableSource(
    this.reports, {
    required this.onContact,
    required this.onViewMap,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= reports.length) return null;
    final report = reports[index];

    final pet = report['pets'];
    final petName = pet is Map
        ? (pet['name']?.toString() ?? 'Unknown Pet')
        : 'Unknown Pet';
    final petPhoto = pet is Map ? (pet['photo_url']?.toString() ?? '') : '';

    final owner = report['owner_id'];
    final ownerName = owner is Map
        ? '${owner['first_name'] ?? ''} ${owner['surname'] ?? ''}'.trim()
        : 'Unknown Owner';

    final location = report['last_seen_address']?.toString() ??
        report['barangay']?.toString() ??
        '-';
    final reportedAt = report['reported_at']?.toString() ?? '';
    final status = (report['status']?.toString() ?? 'active').toLowerCase();

    String formattedDate = '';
    if (reportedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(reportedAt);
        formattedDate = '${dt.month}/${dt.day}/${dt.year}';
      } catch (_) {
        formattedDate = reportedAt;
      }
    }

    final isEven = index % 2 == 0;

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isEven ? Colors.white : const Color(0xFFF9FAFB),
      ),
      cells: [
        // Photo 40x40
        DataCell(
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: petPhoto.isNotEmpty
                ? Image.network(
                    petPhoto,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(),
                  )
                : _photoPlaceholder(),
          ),
        ),
        // Pet Name
        DataCell(Text(
          petName,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        )),
        // Owner
        DataCell(Text(
          ownerName.isNotEmpty ? ownerName : '-',
          style: GoogleFonts.inter(fontSize: 13),
        )),
        // Location
        DataCell(Text(
          location,
          style: GoogleFonts.inter(fontSize: 13),
        )),
        // Date Reported
        DataCell(Text(
          formattedDate,
          style: GoogleFonts.inter(fontSize: 13),
        )),
        // Status Chip
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'resolved'
                  ? const Color(0xFF22C55E).withOpacity(0.15)
                  : AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: status == 'resolved'
                    ? const Color(0xFF22C55E)
                    : AppColors.error,
              ),
            ),
          ),
        ),
        // Actions: Contact + View Map
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => onContact(report),
                icon: const Icon(Icons.call, size: 14),
                label: Text('Contact', style: GoogleFonts.inter(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                      color: AppColors.primary.withOpacity(0.5)),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => onViewMap(report),
                icon: const Icon(Icons.map_outlined, size: 14),
                label:
                    Text('View Map', style: GoogleFonts.inter(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.pets, color: AppColors.primary, size: 20),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => reports.length;

  @override
  int get selectedRowCount => 0;
}


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/export/file_export_service.dart';
import '../../../widgets/admin/admin_content_wrapper.dart';
import '../../../widgets/admin/admin_layout.dart';
import '../../../widgets/admin/reports/admin_report_card.dart';
import '../../../widgets/admin/reports/reports_data_table_source.dart';
import '../../../widgets/admin/web/admin_web_layout.dart';

/// Admin Reports Screen — barangay-scoped lost pet reports with filter chips,
/// report cards, and a "Mark as Verified" review button.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  String _adminBarangay = '';
  UserRole _currentUserRole = UserRole.admin;
  bool _isLoading = true;
  int _filterIndex = 0;

  List<Map<String, dynamic>> _reports = [];

  static const List<String> _filterLabels = [
    'All',
    'Active',
    'Found',
    'Archived',
    'Recent',
  ];

  bool _handledArgs = false;
  String? _targetReportId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handledArgs) {
      _handledArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final query = args['searchQuery']?.toString();
        final reportId = args['reportId']?.toString();
        _targetReportId = reportId;
        if (query != null && query.isNotEmpty) {
          _searchCtrl.text = query;
          _filterIndex = 0;
        } else if (reportId != null && reportId.isNotEmpty) {
          _searchCtrl.text = reportId;
          _filterIndex = 0;
        }
      } else if (args is String && args.isNotEmpty) {
        _searchCtrl.text = args;
        _targetReportId = args;
        _filterIndex = 0;
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      final fetched = List<Map<String, dynamic>>.from(data);

      if (_targetReportId != null && _targetReportId!.isNotEmpty) {
        final hasTarget =
            fetched.any((r) => r['report_id']?.toString() == _targetReportId);
        if (!hasTarget) {
          try {
            final single = await _supabase
                .from('lost_reports')
                .select('*, pets(*), owner_id(*)')
                .eq('report_id', _targetReportId!)
                .maybeSingle();
            if (single != null) {
              fetched.insert(0, Map<String, dynamic>.from(single));
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _reports = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static bool isReportFound(Map<String, dynamic> r) {
    // 1. Direct explicit flags or outcome
    final repType = (r['report_type'] ?? '').toString().toUpperCase();
    final outcome = (r['outcome'] ?? r['pet_status'] ?? r['condition'] ?? '')
        .toString()
        .toUpperCase();
    if (outcome == 'FOUND' || repType == 'FOUND') return true;
    if (outcome == 'LOST' || repType == 'LOST') return false;

    if (r['is_found'] == true || r['found_at'] != null) return true;

    // 2. Check report status & pet status
    final status = (r['status'] ?? '').toString().toLowerCase();
    final petData = r['pets'] as Map<String, dynamic>?;
    final petStatus = (petData?['status'] ?? '').toString().toLowerCase();

    if (status == 'resolved' ||
        status == 'found' ||
        status == 'archived' ||
        petStatus == 'found' ||
        (petStatus == 'active' && status == 'archived')) {
      return true;
    }

    return false;
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list = List.from(_reports);
    switch (_filterIndex) {
      case 1: // Active (currently lost)
        list = list.where((r) {
          final status = (r['status'] ?? 'active').toString().toLowerCase();
          return status == 'active' && !isReportFound(r);
        }).toList();
        break;
      case 2: // Found
        list = list.where((r) => isReportFound(r)).toList();
        break;
      case 3: // Archived
        list = list.where((r) {
          final status = (r['status'] ?? '').toString().toLowerCase();
          return status == 'archived' || status == 'resolved';
        }).toList();
        break;
      case 4: // Recent — last 7 days
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
    }

    // Apply search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        final pet = r['pets'];
        final petName = pet is Map ? (pet['name'] ?? '').toString().toLowerCase() : '';
        final breed = pet is Map ? (pet['breed'] ?? '').toString().toLowerCase() : '';
        final petSpecies = pet is Map ? (pet['species'] ?? '').toString().toLowerCase() : '';
        final rSpecies = (r['species'] ?? '').toString().toLowerCase();
        final location = (r['last_seen_address'] ?? r['barangay'] ?? '').toString().toLowerCase();
        final owner = r['owner_id'];
        final ownerName = owner is Map
            ? [owner['first_name'], owner['middle_name'], owner['surname'], owner['suffix']]
                .where((s) => s != null && s.toString().isNotEmpty)
                .join(' ')
                .toLowerCase()
            : '';
        final repId = (r['report_id'] ?? '').toString().toLowerCase();
        return repId == q ||
            petName.contains(q) ||
            ownerName.contains(q) ||
            breed.contains(q) ||
            petSpecies.contains(q) ||
            rSpecies.contains(q) ||
            location.contains(q);
      }).toList();
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
        // Search bar
        _buildSearchBar(),
        const SizedBox(height: 16),

        // Filter chips + Export button row
        Row(
          children: [
            Expanded(child: _buildFilterChips()),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _filtered.isEmpty ? null : _exportToExcel,
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: Text('Export to Excel',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D6F42),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
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
              showCheckboxColumn: false,
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
                DataColumn(label: Text('Time Reported')),
                DataColumn(label: Text('Pet Status')),
                DataColumn(label: Text('Report Status')),
                DataColumn(label: Text('Action')),
              ],
              source: ReportsDataTableSource(
                _filtered,
                onViewReport: _showReportDetailsDialog,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showReportDetailsDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: SingleChildScrollView(
            child: AdminReportCard(
              report: report,
              isDialog: true,
              onClose: () => Navigator.pop(ctx),
            ),
          ),
        ),
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

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded,
                    size: 18, color: AppColors.onSurfaceVariant),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
              )
            : null,
        hintText: 'Search by pet name, species, breed, location...',
        hintStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
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
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildFilterChips()),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _filtered.isEmpty ? null : _exportToExcel,
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        tooltip: 'Export to Excel',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1D6F42),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildFilterChips()),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _filtered.isEmpty ? null : _exportToExcel,
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        tooltip: 'Export to Excel',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1D6F42),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
          AppConstants.buildLogoGraphic(size: 24),
          const SizedBox(width: 8),
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
    return AdminReportCard(report: report);
  }

  /// Exports the currently filtered reports to an Excel (.xlsx) file.
  /// On web: triggers a browser download. On mobile: opens the share sheet.
  Future<void> _exportToExcel() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Lost Pet Reports'];
      excel.delete('Sheet1'); // Remove default sheet

      // ── Header row ──────────────────────────────────────────────
      const headers = [
        'Pet Name', 'Breed', 'Species', 'Owner', 'Owner Phone',
        'Barangay', 'Date Reported', 'Time Reported', 'Pet Status', 'Archive Status', 'Where Pet Last Seen',
      ];
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1D6F42'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
        sheet.setColumnWidth(c, c == 10 ? 32 : 20);
      }

      // ── Data rows ────────────────────────────────────────────────
      for (var r = 0; r < _filtered.length; r++) {
        final report = _filtered[r];
        final pet = report['pets'];
        final owner = report['owner_id'];

        final petName   = pet is Map ? (pet['name']?.toString() ?? '')  : '';
        final breed     = pet is Map ? (pet['breed']?.toString() ?? '') : '';
        final species   = pet is Map ? (pet['species']?.toString() ?? '') : '';
        final ownerName = owner is Map
            ? [owner['first_name'], owner['middle_name'], owner['surname'], owner['suffix']]
                .where((s) => s != null && s.toString().isNotEmpty).join(' ')
            : '';
        final phone     = owner is Map ? (owner['phone']?.toString() ?? '') : '';
        final barangay  = report['barangay']?.toString() ?? '';
        final reportStatus = (report['status']?.toString() ?? 'active').toLowerCase();

        final bool isFound = isReportFound(report);
        final String petCondition = isFound ? 'FOUND' : 'LOST';
        final archiveStatus = reportStatus == 'archived' ? 'ARCHIVED' : 'ACTIVE';

        final lastSeenRaw = report['last_seen_address']?.toString() ?? '';
        final whereLastSeen = lastSeenRaw.isNotEmpty
            ? lastSeenRaw
            : (barangay.isNotEmpty ? barangay : '-');

        String dateStr = '', timeStr = '';
        final raw = report['reported_at']?.toString() ?? '';
        if (raw.isNotEmpty) {
          try {
            final dt = DateTime.parse(raw).toLocal();
            const months = ['Jan','Feb','Mar','Apr','May','Jun',
                            'Jul','Aug','Sep','Oct','Nov','Dec'];
            dateStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
            final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
            final m = dt.minute.toString().padLeft(2, '0');
            timeStr = '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
          } catch (_) {}
        }

        final rowData = [
          petName,
          breed,
          species,
          ownerName,
          phone,
          barangay,
          dateStr,
          timeStr,
          petCondition,
          archiveStatus,
          whereLastSeen,
        ];
        final rowStyle = CellStyle(
          backgroundColorHex: r.isEven
              ? ExcelColor.fromHexString('#FFFFFF')
              : ExcelColor.fromHexString('#F0FDF4'),
        );
        for (var c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
          cell.value = TextCellValue(rowData[c]);
          cell.cellStyle = rowStyle;
        }
      }

      final bytes = excel.encode()!;
      final now = DateTime.now();
      final filename =
          'lost_reports_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';

      await saveAndShareFile(bytes, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported $filename successfully.',
              style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF1D6F42),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e', style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }
}


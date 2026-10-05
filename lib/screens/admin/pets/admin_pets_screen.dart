import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_toast.dart';
import '../../../services/alerts/alert_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../../widgets/admin/admin_content_wrapper.dart';
import '../../../widgets/admin/admin_layout.dart';
import 'admin_pet_detail_screen.dart';
import '../../../widgets/admin/web/admin_web_layout.dart';
import '../../../widgets/admin/pet_location_map_dialog.dart';
import '../../../widgets/admin/pets/admin_pet_card.dart';
import '../../../widgets/admin/pets/pets_data_table_source.dart';
import '../../../widgets/admin/pets/pets_export_service.dart';

export '../../../widgets/admin/pets/admin_pet_card.dart';
export '../../../widgets/admin/pets/pets_data_table_source.dart';

/// Admin Pets screen – fetches and displays ALL pets from Supabase
/// regardless of owner. Includes search, filter chips, and summary stats.
class AdminPetsScreen extends StatefulWidget {
  const AdminPetsScreen({super.key});

  @override
  State<AdminPetsScreen> createState() => _AdminPetsScreenState();
}

class _AdminPetsScreenState extends State<AdminPetsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> allPets = [];
  List<Map<String, dynamic>> filteredPets = [];
  bool isLoading = true;
  int _selectedChipIndex = 0;
  String _adminBarangay = '';
  UserRole _currentUserRole = UserRole.admin;
  String _selectedBarangayFilter = 'All';

  static const List<String> _chipLabels = ['All', 'Active', 'Lost', 'Archived'];

  List<String> get _availableBarangays {
    final set = <String>{'All'};
    for (final p in allPets) {
      final b =
          (p['barangay'] ?? p['users']?['barangay'] ?? '').toString().trim();
      if (b.isNotEmpty) set.add(b);
    }
    return set.toList();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUserRole = await AuthService.instance.getCurrentUserRole();
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    await fetchAllPets();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchAllPets({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => isLoading = true);
    }
    try {
      var query = _supabase.from('pets').select(
          '*, users(first_name, middle_name, surname, suffix, email, phone, barangay)');

      // If barangay admin, strictly scope to their assigned barangay.
      // Super admin sees all pets across all barangays.
      if (_currentUserRole != UserRole.superAdmin &&
          _adminBarangay.isNotEmpty) {
        query = query.eq('barangay', _adminBarangay);
      }

      final data = await query.order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        allPets = List<Map<String, dynamic>>.from(data);
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Error loading pets: $e');
    } finally {
      if (mounted && !isRefresh) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(allPets);

    // Apply barangay filter for super admin
    if (_currentUserRole == UserRole.superAdmin &&
        _selectedBarangayFilter != 'All') {
      result = result.where((p) {
        final b = (p['barangay'] ?? p['users']?['barangay'] ?? '')
            .toString()
            .toLowerCase();
        return b == _selectedBarangayFilter.toLowerCase();
      }).toList();
    }

    // Apply chip filter
    switch (_selectedChipIndex) {
      case 1: // Active
        result = result
            .where(
                (p) => (p['status'] ?? '').toString().toLowerCase() == 'active')
            .toList();
        break;
      case 2: // Lost
        result = result
            .where(
                (p) => (p['status'] ?? '').toString().toLowerCase() == 'lost')
            .toList();
        break;
      case 3: // Archived
        result = result
            .where((p) =>
                (p['status'] ?? '').toString().toLowerCase() == 'archived')
            .toList();
        break;
    }

    // Apply search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((p) {
        final petName = (p['name'] ?? '').toString().toLowerCase();
        final breed = (p['breed'] ?? '').toString().toLowerCase();
        final species = (p['species'] ?? '').toString().toLowerCase();
        final barangay = (p['barangay'] ?? p['users']?['barangay'] ?? '')
            .toString()
            .toLowerCase();
        final collarId = (p['gps_id'] ?? '').toString().toLowerCase();
        final u = p['users'];
        final ownerName = u != null
            ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']]
                .where((s) => s != null && s.toString().isNotEmpty)
                .join(' ')
                .toLowerCase()
            : '';
        return petName.contains(q) ||
            ownerName.contains(q) ||
            barangay.contains(q) ||
            breed.contains(q) ||
            species.contains(q) ||
            collarId.contains(q);
      }).toList();
    }

    filteredPets = result;
  }

  void _showContactDialog(Map<String, dynamic> pet) {
    final owner = pet['users'];
    final ownerName = owner is Map
        ? [
            owner['first_name'],
            owner['middle_name'],
            owner['surname'],
            owner['suffix']
          ].where((s) => s != null && s.toString().isNotEmpty).join(' ')
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
            Text('Name: ${ownerName.isNotEmpty ? ownerName : 'Not provided'}',
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

  Future<void> _showLocationDialog(Map<String, dynamic> pet) async {
    showPetLocationMapDialog(context, pet);
  }

  Future<void> _repostPetToNews(Map<String, dynamic> pet) async {
    final petName = pet['name']?.toString() ?? 'Pet';
    final barangay = pet['barangay']?.toString() ??
        pet['users']?['barangay']?.toString() ??
        'Catanduanes';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded,
                color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text('Broadcast to News?',
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'This will publish "$petName" directly as an urgent alert on the public News feed and notify all users across Catanduanes, regardless of their barangay.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Publish & Notify All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final petId = pet['pet_id'] ?? pet['id'];
      final photoUrl = pet['photo_url']?.toString() ?? '';
      final species = pet['species']?.toString() ?? 'Pet';
      final breed = pet['breed']?.toString() ?? '';
      final color = pet['color']?.toString() ?? '';
      final u = pet['users'];
      final ownerName = u is Map
          ? [u['first_name'], u['surname']]
              .where((s) => s != null && s.toString().isNotEmpty)
              .join(' ')
          : '';
      final ownerPhone = u is Map ? (u['phone']?.toString() ?? '') : '';

      final summary = [
        '$species • $breed',
        if (color.isNotEmpty) 'Color: $color',
        if (barangay.isNotEmpty) 'Location: Brgy. $barangay',
        if (ownerName.isNotEmpty) 'Owner: $ownerName',
        if (ownerPhone.isNotEmpty) 'Contact: $ownerPhone',
        'Please report sightings to the owner or barangay authorities immediately.',
      ].join('\n');

      if ((pet['status'] ?? '').toString().toLowerCase() != 'lost') {
        await _supabase
            .from('pets')
            .update({'status': 'lost'}).eq('pet_id', petId);
      }

      final postBarangay = (barangay.isNotEmpty && barangay != 'Catanduanes')
          ? barangay
          : (_adminBarangay.isNotEmpty ? _adminBarangay : 'Catanduanes');

      await _supabase.from('news').insert({
        'category': 'Lost & Found',
        'title': '🚨 MISSING PET: $petName',
        'source': 'PetTrace Admin Alert',
        'summary': summary,
        'image_url': photoUrl,
        'accent_color': '#BA1A1A',
        'barangay': postBarangay,
        'status': 'active',
      });

      final count = await AlertService.instance.broadcastLostPetNewsAlert(
        petName: petName,
        barangay: barangay,
      );

      if (mounted) {
        AppToast.success(
            context, '$petName posted to News! ($count users notified)');
        fetchAllPets();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Error reposting to news: $e');
    }
  }

  int get _totalCount => allPets.length;
  int get _activeCount => allPets
      .where((p) => (p['status'] ?? '').toString().toLowerCase() == 'active')
      .length;
  int get _lostCount => allPets
      .where((p) => (p['status'] ?? '').toString().toLowerCase() == 'lost')
      .length;
  int get _archivedCount => allPets
      .where((p) => (p['status'] ?? '').toString().toLowerCase() == 'archived')
      .length;

  int _sortColumnIndex = 1;
  bool _sortAscending = true;

  void _sort<T>(Comparable<T> Function(Map<String, dynamic> pet) getField,
      int columnIndex, bool ascending) {
    filteredPets.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Future<void> _exportToExcel() async {
    await PetsExportService.exportPetsToExcel(context, filteredPets);
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
        currentIndex: 1,
        pageTitle: 'All Pets',
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    if (isLoading) {
      return const AdminWebLayout(
        currentIndex: 1,
        pageTitle: 'All Pets',
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(60.0),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return AdminWebLayout(
      currentIndex: 1,
      pageTitle: 'All Pets',
      body: _buildDesktopContent(),
    );
  }

  Widget _buildDesktopContent() {
    final isSuperAdmin = _currentUserRole == UserRole.superAdmin;
    final barangays = _availableBarangays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary pills Row + Barangay Chip
        Row(
          children: [
            _buildSummaryRow(),
            const Spacer(),
            _buildBarangayChip(),
          ],
        ),
        const SizedBox(height: 16),

        // Search bar + optional Barangay dropdown for Super Admin
        Row(
          children: [
            Expanded(child: _buildSearchBar()),
            if (isSuperAdmin && barangays.length > 1) ...[
              const SizedBox(width: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: barangays.contains(_selectedBarangayFilter)
                        ? _selectedBarangayFilter
                        : 'All',
                    icon: const Icon(Icons.arrow_drop_down,
                        color: AppColors.primary),
                    items: barangays.map((b) {
                      return DropdownMenuItem<String>(
                        value: b,
                        child: Text(
                          b == 'All' ? 'All Barangays' : 'Brgy. $b',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedBarangayFilter = val;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Filter chips Row
        _buildFilterChips(),
        const SizedBox(height: 20),

        // Card with PaginatedDataTable
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
                    'Pets Registry (${filteredPets.length})',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: filteredPets.isEmpty ? null : _exportToExcel,
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: Text('Export to Excel',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D6F42),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: fetchAllPets,
                  ),
                ],
              ),
              rowsPerPage: 10,
              showFirstLastButtons: true,
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              columns: [
                const DataColumn(label: Text('Photo')),
                DataColumn(
                  label: const Text('Pet Name'),
                  onSort: (columnIndex, ascending) {
                    _sort<String>(
                      (p) => (p['name'] ?? '').toString().toLowerCase(),
                      columnIndex,
                      ascending,
                    );
                  },
                ),
                DataColumn(
                  label: const Text('Breed'),
                  onSort: (columnIndex, ascending) {
                    _sort<String>(
                      (p) => (p['breed'] ?? '').toString().toLowerCase(),
                      columnIndex,
                      ascending,
                    );
                  },
                ),
                DataColumn(
                  label: const Text('Species'),
                  onSort: (columnIndex, ascending) {
                    _sort<String>(
                      (p) => (p['species'] ?? '').toString().toLowerCase(),
                      columnIndex,
                      ascending,
                    );
                  },
                ),
                DataColumn(
                  label: const Text('Owner'),
                  onSort: (columnIndex, ascending) {
                    _sort<String>(
                      (p) {
                        final u = p['users'];
                        return u is Map
                            ? '${u['first_name'] ?? ''} ${u['surname'] ?? ''}'
                                .toLowerCase()
                            : '';
                      },
                      columnIndex,
                      ascending,
                    );
                  },
                ),
                DataColumn(
                  label: const Text('Barangay'),
                  onSort: (columnIndex, ascending) {
                    _sort<String>(
                      (p) => (p['barangay'] ?? '').toString().toLowerCase(),
                      columnIndex,
                      ascending,
                    );
                  },
                ),
                DataColumn(
                  label: const Text('Status'),
                  onSort: (columnIndex, ascending) {
                    _sort<String>(
                      (p) => (p['status'] ?? '').toString().toLowerCase(),
                      columnIndex,
                      ascending,
                    );
                  },
                ),
                DataColumn(
                  label: const Text('Registered Date'),
                  onSort: (columnIndex, ascending) {
                    _sort<String>(
                      (p) => (p['created_at'] ?? '').toString(),
                      columnIndex,
                      ascending,
                    );
                  },
                ),
                DataColumn(
                  label: const Text('Last Modified'),
                  onSort: (columnIndex, ascending) {
                    _sort<String>(
                      (p) => (p['updated_at'] ??
                              p['modified_at'] ??
                              p['created_at'] ??
                              '')
                          .toString(),
                      columnIndex,
                      ascending,
                    );
                  },
                ),
                const DataColumn(label: Text('Actions')),
              ],
              source: PetsDataTableSource(
                filteredPets,
                context,
                onContact: _showContactDialog,
                onViewMap: _showLocationDialog,
                onRepost: _repostPetToNews,
                onViewLogs: (pet) => showPetAuditLogDialog(context, pet),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildAppBar(context),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1200;
                    return isWide ? _buildWideContent() : _buildNarrowContent();
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNarrowContent() {
    return AdminContentWrapper(
      maxWidth: 1100,
      child: RefreshIndicator(
        onRefresh: () => fetchAllPets(isRefresh: true),
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            _buildBarangayChip(),
            const SizedBox(height: 12),
            _buildSummaryRow(),
            const SizedBox(height: 14),
            _buildSearchBar(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildFilterChips()),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: filteredPets.isEmpty ? null : _exportToExcel,
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
            const SizedBox(height: 16),
            ...filteredPets.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPetCard(p),
                )),
            if (filteredPets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text('No pets found',
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.onSurfaceVariant)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideContent() {
    return AdminContentWrapper(
      maxWidth: 1100,
      child: RefreshIndicator(
        onRefresh: () => fetchAllPets(isRefresh: true),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBarangayChip(),
                    const SizedBox(height: 12),
                    _buildSummaryRow(),
                    const SizedBox(height: 14),
                    _buildSearchBar(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _buildFilterChips()),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: filteredPets.isEmpty ? null : _exportToExcel,
                          icon: const Icon(Icons.table_chart_outlined, size: 18),
                          label: Text('Export to Excel',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D6F42),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (filteredPets.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No pets found',
                        style: GoogleFonts.inter(
                            fontSize: 15, color: AppColors.onSurfaceVariant)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPetCard(filteredPets[index]),
                    childCount: filteredPets.length,
                  ),
                ),
              ),
          ],
        ),
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          AppConstants.buildLogoGraphic(size: 24),
          const SizedBox(width: 8),
          Text('All Pets',
              style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          const Spacer(),
          const Icon(Icons.admin_panel_settings,
              color: AppColors.primary, size: 24),
        ],
      ),
    );
  }

  Widget _buildBarangayChip() {
    final isSuperAdmin = _currentUserRole == UserRole.superAdmin;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isSuperAdmin ? const Color(0xFFFF6600) : AppColors.primary)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  (isSuperAdmin ? const Color(0xFFFF6600) : AppColors.primary)
                      .withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuperAdmin ? Icons.shield_rounded : Icons.location_on,
                size: 14,
                color:
                    isSuperAdmin ? const Color(0xFFFF6600) : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                isSuperAdmin
                    ? (_selectedBarangayFilter == 'All'
                        ? 'All Barangays (Super Admin)'
                        : 'Brgy. $_selectedBarangayFilter')
                    : (_adminBarangay.isNotEmpty
                        ? 'Brgy. $_adminBarangay'
                        : 'Barangay Admin'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSuperAdmin
                      ? const Color(0xFFFF6600)
                      : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _summaryPill('Total: $_totalCount', AppColors.primary),
          const SizedBox(width: 8),
          _summaryPill('Active: $_activeCount', const Color(0xFF22C55E)),
          const SizedBox(width: 8),
          _summaryPill('Lost: $_lostCount', AppColors.error),
          const SizedBox(width: 8),
          _summaryPill('Archived: $_archivedCount', const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _summaryPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() => _applyFilters()),
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
        hintText: 'Search by pet name, species, breed, owner...',
        hintStyle: GoogleFonts.inter(
            fontSize: 15, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_chipLabels.length, (i) {
          final isSelected = i == _selectedChipIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(_chipLabels[i]),
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant,
              ),
              selectedColor: AppColors.primaryContainer,
              backgroundColor: AppColors.surfaceContainerHighest,
              checkmarkColor: AppColors.onPrimaryContainer,
              side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : AppColors.outlineVariant.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              onSelected: (_) {
                setState(() {
                  _selectedChipIndex = i;
                  _applyFilters();
                });
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPetCard(Map<String, dynamic> pet) {
    return AdminPetCard(
      pet: pet,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminPetDetailScreen(pet: pet)),
        );
        // Refresh list when returning from detail screen
        fetchAllPets();
      },
      onContact: () => _showContactDialog(pet),
      onViewMap: () => _showLocationDialog(pet),
      onRepost: () => _repostPetToNews(pet),
      onViewLogs: () => showPetAuditLogDialog(context, pet),
    );
  }
}


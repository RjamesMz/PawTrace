import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_toast.dart';
import '../../../services/alerts/alert_service.dart';
import '../../../services/audit/pet_audit_service.dart';
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
  List<Map<String, dynamic>> filteredActivePets = [];
  List<Map<String, dynamic>> filteredArchivedPets = [];
  bool isLoading = true;
  int _selectedChipIndex = 0;
  int _tableSegmentIndex =
      0; // 0: Active & Lost Pets, 1: Archived Pets, 2: View Both Tables
  String _adminBarangay = '';
  UserRole _currentUserRole = UserRole.admin;
  String _selectedBarangayFilter = 'All';

  int _unifiedSortColumnIndex = 1;
  bool _unifiedSortAscending = true;

  List<String> get _currentChipLabels {
    if (_tableSegmentIndex == 2) {
      return [
        'All ($_totalCount)',
        'Active ($_activeCount)',
        'Lost ($_lostCount)',
        'Archived ($_archivedCount)'
      ];
    } else if (_tableSegmentIndex == 0) {
      return [
        'All (${_activeCount + _lostCount})',
        'Active ($_activeCount)',
        'Lost ($_lostCount)'
      ];
    } else {
      return ['All Archived ($_archivedCount)'];
    }
  }

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
      final petsList = List<Map<String, dynamic>>.from(data);

      // Backfill updated_at from pet_audit_logs if updated_at is null or matches created_at
      try {
        final auditLogsRes = await _supabase
            .from('pet_audit_logs')
            .select('pet_id, created_at, action')
            .neq('action', 'Pet Registered')
            .order('created_at', ascending: false);

        final Map<String, String> latestAuditByPet = {};
        for (final row in auditLogsRes) {
          final pid = (row['pet_id'] ?? '').toString();
          final ts = (row['created_at'] ?? '').toString();
          if (pid.isNotEmpty &&
              ts.isNotEmpty &&
              !latestAuditByPet.containsKey(pid)) {
            latestAuditByPet[pid] = ts;
          }
        }

        for (final p in petsList) {
          final pid = (p['pet_id'] ?? p['id'] ?? '').toString();
          final curUpdated = p['updated_at'] ?? p['modified_at'];
          final isUntouched = curUpdated == null ||
              curUpdated.toString().trim().isEmpty ||
              curUpdated.toString() == (p['created_at'] ?? '').toString();

          if (isUntouched) {
            if (latestAuditByPet.containsKey(pid)) {
              p['updated_at'] = latestAuditByPet[pid];
            } else {
              final localLatest =
                  PetAuditService.getLatestModificationForPet(pid);
              if (localLatest != null) {
                p['updated_at'] = localLatest.timestamp.toIso8601String();
              }
            }
          }
        }
      } catch (err) {
        debugPrint('[AdminPetsScreen] Notice backfilling audit dates: $err');
        for (final p in petsList) {
          final pid = (p['pet_id'] ?? p['id'] ?? '').toString();
          final curUpdated = p['updated_at'] ?? p['modified_at'];
          if (curUpdated == null || curUpdated.toString().trim().isEmpty) {
            final localLatest =
                PetAuditService.getLatestModificationForPet(pid);
            if (localLatest != null) {
              p['updated_at'] = localLatest.timestamp.toIso8601String();
            }
          }
        }
      }

      setState(() {
        allPets = petsList;
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
    List<Map<String, dynamic>> base = List.from(allPets);

    // Apply barangay filter for super admin
    if (_currentUserRole == UserRole.superAdmin &&
        _selectedBarangayFilter != 'All') {
      base = base.where((p) {
        final b = (p['barangay'] ?? p['users']?['barangay'] ?? '')
            .toString()
            .toLowerCase();
        return b == _selectedBarangayFilter.toLowerCase();
      }).toList();
    }

    // Apply search filter across name, owner, breed, species, collar, or archive reason
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      base = base.where((p) {
        final petName = (p['name'] ?? '').toString().toLowerCase();
        final breed = (p['breed'] ?? '').toString().toLowerCase();
        final species = (p['species'] ?? '').toString().toLowerCase();
        final barangay = (p['barangay'] ?? p['users']?['barangay'] ?? '')
            .toString()
            .toLowerCase();
        final collarId = (p['gps_id'] ?? '').toString().toLowerCase();
        final reason =
            (p['archive_reason'] ?? p['archived_reason'] ?? p['reason'] ?? '')
                .toString()
                .toLowerCase();
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
            collarId.contains(q) ||
            reason.contains(q);
      }).toList();
    }

    // Partition into Archived vs Active/Lost
    filteredArchivedPets = base
        .where(
            (p) => (p['status'] ?? '').toString().toLowerCase() == 'archived')
        .toList();

    var activeList = base
        .where(
            (p) => (p['status'] ?? '').toString().toLowerCase() != 'archived')
        .toList();

    if (_selectedChipIndex == 1) {
      activeList = activeList
          .where(
              (p) => (p['status'] ?? '').toString().toLowerCase() == 'active')
          .toList();
    } else if (_selectedChipIndex == 2) {
      activeList = activeList
          .where((p) => (p['status'] ?? '').toString().toLowerCase() == 'lost')
          .toList();
    }

    filteredActivePets = activeList;

    if (_tableSegmentIndex == 1) {
      filteredPets = filteredArchivedPets;
    } else if (_tableSegmentIndex == 0) {
      filteredPets = filteredActivePets;
    } else {
      // _tableSegmentIndex == 2 (View Both Tables)
      if (_selectedChipIndex == 1) {
        filteredPets = base
            .where(
                (p) => (p['status'] ?? '').toString().toLowerCase() == 'active')
            .toList();
      } else if (_selectedChipIndex == 2) {
        filteredPets = base
            .where(
                (p) => (p['status'] ?? '').toString().toLowerCase() == 'lost')
            .toList();
      } else if (_selectedChipIndex == 3) {
        filteredPets = filteredArchivedPets;
      } else {
        filteredPets = base;
      }
    }
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

  int _activeSortColumnIndex = 1;
  bool _activeSortAscending = true;
  int _archivedSortColumnIndex = 1;
  bool _archivedSortAscending = true;

  void _sortActive<T>(Comparable<T> Function(Map<String, dynamic> pet) getField,
      int columnIndex, bool ascending) {
    int comparator(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    }

    filteredActivePets.sort(comparator);
    setState(() {
      _activeSortColumnIndex = columnIndex;
      _activeSortAscending = ascending;
    });
  }

  void _sortArchived<T>(
      Comparable<T> Function(Map<String, dynamic> pet) getField,
      int columnIndex,
      bool ascending) {
    int comparator(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    }

    filteredArchivedPets.sort(comparator);
    setState(() {
      _archivedSortColumnIndex = columnIndex;
      _archivedSortAscending = ascending;
    });
  }

  void _sortUnified<T>(
      Comparable<T> Function(Map<String, dynamic> pet) getField,
      int columnIndex,
      bool ascending) {
    int comparator(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    }

    filteredPets.sort(comparator);
    setState(() {
      _unifiedSortColumnIndex = columnIndex;
      _unifiedSortAscending = ascending;
    });
  }

  List<Map<String, dynamic>> get _currentExportPets {
    if (_tableSegmentIndex == 0) return filteredActivePets;
    if (_tableSegmentIndex == 1) return filteredArchivedPets;
    return filteredPets;
  }

  Future<void> _exportCurrentToExcel() async {
    await PetsExportService.exportPetsToExcel(context, _currentExportPets);
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

        // Table View Segmented Switcher + Barangay Chip
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSegmentTab(
                      index: 0,
                      icon: Icons.pets_rounded,
                      label: 'Registered',
                      count: filteredActivePets.length,
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    _buildSegmentTab(
                      index: 1,
                      icon: Icons.archive_outlined,
                      label: 'Archived Pets',
                      count: filteredArchivedPets.length,
                      activeColor: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            _buildBarangayChip(),
          ],
        ),
        const SizedBox(height: 18),

        // Filter chips + Export button row (matching Report Management)
        Row(
          children: [
            Expanded(child: _buildFilterChips()),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed:
                  _currentExportPets.isEmpty ? null : _exportCurrentToExcel,
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
        const SizedBox(height: 16),

        if (_tableSegmentIndex == 0)
          _buildActivePetsTableCard()
        else if (_tableSegmentIndex == 1)
          _buildArchivedPetsTableCard()
        else
          _buildUnifiedAllPetsTableCard(),
      ],
    );
  }

  Widget _buildSegmentTab({
    required int index,
    required IconData icon,
    required String label,
    required int count,
    required Color activeColor,
  }) {
    final isSelected = _tableSegmentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _tableSegmentIndex = index;
          _selectedChipIndex = 0;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withOpacity(0.12)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePetsTableCard() {
    return Card(
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
          key: ValueKey(
              'active_table_${_tableSegmentIndex}_${_selectedChipIndex}_${filteredActivePets.length}_${_activeSortColumnIndex}_$_activeSortAscending'),
          header: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pets_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Active Pets Registry (${filteredActivePets.length})',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Active and missing pets currently managed in the barangay',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: fetchAllPets,
              ),
            ],
          ),
          rowsPerPage: filteredActivePets.length > 5 ? 10 : 5,
          showFirstLastButtons: true,
          sortColumnIndex: _activeSortColumnIndex,
          sortAscending: _activeSortAscending,
          columns: [
            const DataColumn(label: Text('Photo')),
            DataColumn(
              label: const Text('Pet Name'),
              onSort: (columnIndex, ascending) {
                _sortActive<String>(
                  (p) => (p['name'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Breed'),
              onSort: (columnIndex, ascending) {
                _sortActive<String>(
                  (p) => (p['breed'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Species'),
              onSort: (columnIndex, ascending) {
                _sortActive<String>(
                  (p) => (p['species'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Owner'),
              onSort: (columnIndex, ascending) {
                _sortActive<String>(
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
                _sortActive<String>(
                  (p) => (p['barangay'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Status'),
              onSort: (columnIndex, ascending) {
                _sortActive<String>(
                  (p) => (p['status'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Registered Date'),
              onSort: (columnIndex, ascending) {
                _sortActive<String>(
                  (p) => (p['created_at'] ?? '').toString(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Last Modified'),
              onSort: (columnIndex, ascending) {
                _sortActive<String>(
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
            filteredActivePets,
            context,
            onContact: _showContactDialog,
            onViewMap: _showLocationDialog,
            onRepost: _repostPetToNews,
            onViewLogs: (pet) => showPetAuditLogDialog(context, pet),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedAllPetsTableCard() {
    return Card(
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
          key: ValueKey(
              'unified_table_${_tableSegmentIndex}_${_selectedChipIndex}_${filteredPets.length}_${_unifiedSortColumnIndex}_$_unifiedSortAscending'),
          header: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_rows_rounded,
                    size: 18, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'All Pets Registry (${filteredPets.length})',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Complete registry of active, lost, and archived pets',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: fetchAllPets,
              ),
            ],
          ),
          rowsPerPage: filteredPets.length > 5 ? 10 : 5,
          showFirstLastButtons: true,
          sortColumnIndex: _unifiedSortColumnIndex,
          sortAscending: _unifiedSortAscending,
          columns: [
            const DataColumn(label: Text('Photo')),
            DataColumn(
              label: const Text('Pet Name'),
              onSort: (columnIndex, ascending) {
                _sortUnified<String>(
                  (p) => (p['name'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Breed'),
              onSort: (columnIndex, ascending) {
                _sortUnified<String>(
                  (p) => (p['breed'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Species'),
              onSort: (columnIndex, ascending) {
                _sortUnified<String>(
                  (p) => (p['species'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Owner'),
              onSort: (columnIndex, ascending) {
                _sortUnified<String>(
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
                _sortUnified<String>(
                  (p) => (p['barangay'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Status'),
              onSort: (columnIndex, ascending) {
                _sortUnified<String>(
                  (p) => (p['status'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Registered Date'),
              onSort: (columnIndex, ascending) {
                _sortUnified<String>(
                  (p) => (p['created_at'] ?? '').toString(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Last Modified'),
              onSort: (columnIndex, ascending) {
                _sortUnified<String>(
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
    );
  }

  Widget _buildArchivedPetsTableCard() {
    return Card(
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
          key: ValueKey(
              'archived_table_${_tableSegmentIndex}_${filteredArchivedPets.length}_${_archivedSortColumnIndex}_$_archivedSortAscending'),
          header: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.archive_outlined,
                    size: 18, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Archived Pets Archive (${filteredArchivedPets.length})',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  Text(
                    'Historical pet profiles removed by owner',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: fetchAllPets,
              ),
            ],
          ),
          rowsPerPage: filteredArchivedPets.length > 5 ? 10 : 5,
          showFirstLastButtons: true,
          sortColumnIndex: _archivedSortColumnIndex,
          sortAscending: _archivedSortAscending,
          columns: [
            const DataColumn(label: Text('Photo')),
            DataColumn(
              label: const Text('Pet Name'),
              onSort: (columnIndex, ascending) {
                _sortArchived<String>(
                  (p) => (p['name'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Breed'),
              onSort: (columnIndex, ascending) {
                _sortArchived<String>(
                  (p) => (p['breed'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Species'),
              onSort: (columnIndex, ascending) {
                _sortArchived<String>(
                  (p) => (p['species'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Owner'),
              onSort: (columnIndex, ascending) {
                _sortArchived<String>(
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
                _sortArchived<String>(
                  (p) => (p['barangay'] ?? '').toString().toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Archive Reason'),
              onSort: (columnIndex, ascending) {
                _sortArchived<String>(
                  (p) => (p['archive_reason'] ??
                          p['archived_reason'] ??
                          p['reason'] ??
                          '')
                      .toString()
                      .toLowerCase(),
                  columnIndex,
                  ascending,
                );
              },
            ),
            DataColumn(
              label: const Text('Date Archived'),
              onSort: (columnIndex, ascending) {
                _sortArchived<String>(
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
          source: ArchivedPetsDataTableSource(
            filteredArchivedPets,
            context,
            onContact: _showContactDialog,
            onViewLogs: (pet) => showPetAuditLogDialog(context, pet),
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
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildBarangayChip(),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSegmentTab(
                      index: 0,
                      icon: Icons.pets_rounded,
                      label: 'Active & Lost',
                      count: filteredActivePets.length,
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    _buildSegmentTab(
                      index: 1,
                      icon: Icons.archive_outlined,
                      label: 'Archived',
                      count: filteredArchivedPets.length,
                      activeColor: const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    _buildSegmentTab(
                      index: 2,
                      icon: Icons.table_rows_rounded,
                      label: 'All Pets',
                      count: filteredActivePets.length +
                          filteredArchivedPets.length,
                      activeColor: const Color(0xFF0F172A),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildFilterChips()),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _currentExportPets.isEmpty
                      ? null
                      : _exportCurrentToExcel,
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
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildBarangayChip(),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSegmentTab(
                              index: 0,
                              icon: Icons.pets_rounded,
                              label: 'Active & Lost',
                              count: filteredActivePets.length,
                              activeColor: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            _buildSegmentTab(
                              index: 1,
                              icon: Icons.archive_outlined,
                              label: 'Archived',
                              count: filteredArchivedPets.length,
                              activeColor: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            _buildSegmentTab(
                              index: 2,
                              icon: Icons.table_rows_rounded,
                              label: 'All Pets',
                              count: filteredActivePets.length +
                                  filteredArchivedPets.length,
                              activeColor: const Color(0xFF0F172A),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _buildFilterChips()),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _currentExportPets.isEmpty
                              ? null
                              : _exportCurrentToExcel,
                          icon:
                              const Icon(Icons.table_chart_outlined, size: 18),
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
    final labels = _currentChipLabels;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == _selectedChipIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(labels[i]),
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

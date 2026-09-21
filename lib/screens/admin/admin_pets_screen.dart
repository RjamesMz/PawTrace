import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_content_wrapper.dart';
import '../../widgets/admin_layout.dart';
import 'admin_pet_detail_screen.dart';
import 'web/admin_web_layout.dart';

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

  static const List<String> _chipLabels = ['All', 'Active', 'Lost', 'Dog', 'Cat'];

  List<String> get _availableBarangays {
    final set = <String>{'All'};
    for (final p in allPets) {
      final b = (p['barangay'] ?? p['users']?['barangay'] ?? '').toString().trim();
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

  Future<void> fetchAllPets() async {
    setState(() => isLoading = true);
    try {
      var query = _supabase
          .from('pets')
          .select('*, users(first_name, middle_name, surname, suffix, email, phone, barangay)');

      // If barangay admin, strictly scope to their assigned barangay.
      // Super admin sees all pets across all barangays.
      if (_currentUserRole != UserRole.superAdmin && _adminBarangay.isNotEmpty) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading pets: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(allPets);

    // Apply barangay filter for super admin
    if (_currentUserRole == UserRole.superAdmin && _selectedBarangayFilter != 'All') {
      result = result.where((p) {
        final b = (p['barangay'] ?? p['users']?['barangay'] ?? '').toString().toLowerCase();
        return b == _selectedBarangayFilter.toLowerCase();
      }).toList();
    }

    // Apply chip filter
    switch (_selectedChipIndex) {
      case 1: // Active
        result = result.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'active').toList();
        break;
      case 2: // Lost
        result = result.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'lost').toList();
        break;
      case 3: // Dog
        result = result.where((p) => (p['species'] ?? '').toString().toLowerCase() == 'dog').toList();
        break;
      case 4: // Cat
        result = result.where((p) => (p['species'] ?? '').toString().toLowerCase() == 'cat').toList();
        break;
    }

    // Apply search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((p) {
        final petName = (p['name'] ?? '').toString().toLowerCase();
        final breed = (p['breed'] ?? '').toString().toLowerCase();
        final species = (p['species'] ?? '').toString().toLowerCase();
        final barangay = (p['barangay'] ?? p['users']?['barangay'] ?? '').toString().toLowerCase();
        final collarId = (p['collar_id'] ?? '').toString().toLowerCase();
        final u = p['users'];
        final ownerName = u != null
            ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']].where((s) => s != null && s.toString().isNotEmpty).join(' ').toLowerCase()
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

  int get _totalCount => allPets.length;
  int get _activeCount => allPets.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'active').length;
  int get _lostCount => allPets.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'lost').length;

  int _sortColumnIndex = 1;
  bool _sortAscending = true;

  void _sort<T>(
      Comparable<T> Function(Map<String, dynamic> pet) getField,
      int columnIndex,
      bool ascending) {
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
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
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
                    onPressed: () async {
                      await Navigator.pushNamed(
                          context, AppRoutes.profilePetRegistration);
                      fetchAllPets();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      'Add Pet',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                const DataColumn(label: Text('Actions')),
              ],
              source: _PetsDataTableSource(filteredPets, context),
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
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1200;
                    return isWide
                        ? _buildWideContent()
                        : _buildNarrowContent();
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNarrowContent() {
    return AdminContentWrapper(
      maxWidth: 1100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          _buildBarangayChip(),
          const SizedBox(height: 12),
          _buildSummaryRow(),
          const SizedBox(height: 14),
          _buildSearchBar(),
          const SizedBox(height: 14),
          _buildFilterChips(),
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
    );
  }

  Widget _buildWideContent() {
    return AdminContentWrapper(
      maxWidth: 1100,
      child: CustomScrollView(
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
                  _buildFilterChips(),
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
    );
  }

  Widget _buildAppBar(BuildContext context) {
    // Hidden on web — AdminLayout provides the top bar
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 800) return const SizedBox.shrink();
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Text('All Pets', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const Spacer(),
          const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 24),
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
            color: (isSuperAdmin ? const Color(0xFFFF6600) : AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (isSuperAdmin ? const Color(0xFFFF6600) : AppColors.primary).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuperAdmin ? Icons.shield_rounded : Icons.location_on,
                size: 14,
                color: isSuperAdmin ? const Color(0xFFFF6600) : AppColors.primary,
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
                  color: isSuperAdmin ? const Color(0xFFFF6600) : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _summaryPill('Total: $_totalCount', AppColors.primary),
        const SizedBox(width: 8),
        _summaryPill('Active: $_activeCount', const Color(0xFF22C55E)),
        const SizedBox(width: 8),
        _summaryPill('Lost: $_lostCount', AppColors.error),
      ],
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
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color),
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
        hintText: 'Search by pet or owner name...',
        hintStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
                color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
              ),
              selectedColor: AppColors.primaryContainer,
              backgroundColor: AppColors.surfaceContainerHighest,
              checkmarkColor: AppColors.onPrimaryContainer,
              side: BorderSide(color: isSelected ? Colors.transparent : AppColors.outlineVariant.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
    final isLost = (pet['status'] ?? 'active').toString().toLowerCase() == 'lost';
    final name = pet['name'] ?? 'Unknown';
    final breed = pet['breed'] ?? '';
    final species = pet['species'] ?? '';
    final barangay = pet['barangay'] ?? '';
    final photoUrl = pet['photo_url'] ?? '';
    final u = pet['users'];
    final ownerName = u != null
        ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']].where((s) => s != null && s.toString().isNotEmpty).join(' ')
        : 'Unknown Owner';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminPetDetailScreen(pet: pet)),
        );
        // Refresh list when returning from detail screen
        fetchAllPets();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
                child: photoUrl.toString().isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface), overflow: TextOverflow.ellipsis),
                Text('$breed • $species', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text('Owner: $ownerName', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                if (barangay.toString().isNotEmpty)
                  Text(barangay, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant.withOpacity(0.7))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLost ? AppColors.errorContainer : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isLost ? 'Lost' : 'Active',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isLost ? AppColors.error : const Color(0xFF065F46),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppColors.primaryContainer.withOpacity(0.2),
      child: const Center(child: Icon(Icons.pets, color: AppColors.primaryContainer, size: 32)),
    );
  }
}

/// DataTableSource for AdminPetsScreen on desktop web.
class _PetsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> pets;
  final BuildContext context;

  _PetsDataTableSource(this.pets, this.context);

  @override
  DataRow? getRow(int index) {
    if (index >= pets.length) return null;
    final p = pets[index];

    final petName = p['name']?.toString() ?? 'Unnamed';
    final species = p['species']?.toString() ?? '';
    final breed = p['breed']?.toString() ?? '';
    final photoUrl = p['photo_url']?.toString() ?? '';
    final barangay = p['barangay']?.toString() ?? '';
    final status = (p['status']?.toString() ?? 'active').toLowerCase();

    final u = p['users'];
    final ownerName = u != null
        ? [u['first_name'], u['surname']]
            .where((s) => s != null && s.toString().isNotEmpty)
            .join(' ')
        : 'Unknown Owner';

    final isEven = index % 2 == 0;

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isEven ? Colors.white : const Color(0xFFF9FAFB),
      ),
      cells: [
        // Photo: Image.network pet photo 40x40 rounded
        DataCell(
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(),
                  )
                : _photoPlaceholder(),
          ),
        ),
        // Pet Name bold
        DataCell(
          Text(
            petName,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.onSurface,
            ),
          ),
        ),
        // Breed gray
        DataCell(
          Text(
            breed.isNotEmpty ? breed : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Species gray
        DataCell(
          Text(
            species.isNotEmpty ? species : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Owner name orange
        DataCell(
          Text(
            ownerName.isNotEmpty ? ownerName : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        // Barangay gray
        DataCell(
          Text(
            barangay.isNotEmpty ? barangay : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Colored status chip
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'active'
                  ? const Color(0xFF22C55E).withOpacity(0.15)
                  : AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: status == 'active'
                    ? const Color(0xFF22C55E)
                    : AppColors.error,
              ),
            ),
          ),
        ),
        // View button
        DataCell(
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminPetDetailScreen(pet: p),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'View',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
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
  int get rowCount => pets.length;

  @override
  int get selectedRowCount => 0;
}


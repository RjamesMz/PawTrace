import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/navigation_helpers.dart';
import '../../services/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'admin_pet_detail_screen.dart';

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

  static const List<String> _chipLabels = ['All', 'Active', 'Lost', 'Dog', 'Cat'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    fetchAllPets();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchAllPets() async {
    setState(() => isLoading = true);
    try {
      final data = await _supabase
          .from('pets')
          .select('*, users(first_name, middle_name, surname, suffix, email, phone, barangay)')
          .eq('barangay', _adminBarangay)
          .order('created_at', ascending: false);
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
        final u = p['users'];
        final ownerName = u != null
            ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']].where((s) => s != null && s.toString().isNotEmpty).join(' ').toLowerCase()
            : '';
        return petName.contains(q) || ownerName.contains(q);
      }).toList();
    }

    filteredPets = result;
  }

  int get _totalCount => allPets.length;
  int get _activeCount => allPets.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'active').length;
  int get _lostCount => allPets.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'lost').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
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
                            child: Text('No pets found', style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurfaceVariant)),
                          ),
                        ),
                    ],
                  ),
          ),
          const BottomNavBar(currentIndex: 1),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Brgy. $_adminBarangay',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
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

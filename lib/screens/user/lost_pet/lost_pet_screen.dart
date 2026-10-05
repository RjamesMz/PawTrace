import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../widgets/user/lost_pet/lost_pet_card.dart';

export '../../../widgets/user/lost_pet/contact_owner_sheet.dart';
export '../../../widgets/user/lost_pet/lost_pet_card.dart';
export 'lost_pet_map_screen.dart';

/// Lost Pet screen – full overview of the current lost-pet reports.
class LostPetScreen extends StatefulWidget {
  const LostPetScreen({super.key});

  @override
  State<LostPetScreen> createState() => _LostPetScreenState();
}

class _LostPetScreenState extends State<LostPetScreen> {
  List<Map<String, dynamic>> _lostPetsList = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  // 0 = Recent (last 48h), 1 = This Week, 2 = This Month, 3 = Archived
  int _filterIndex = 0;

  static const List<String> _filterLabels = [
    'Recent',
    'This Week',
    'This Month',
    'Archived',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list;
    if (_filterIndex == 3) {
      // Archived reports
      list = _lostPetsList.where((r) {
        final st = (r['status'] ?? '').toString().toLowerCase();
        return st == 'archived' || st == 'resolved';
      }).toList();
    } else {
      // Active reports for emergency feeds:
      final activeList = _lostPetsList.where((r) {
        final st = (r['status'] ?? 'active').toString().toLowerCase();
        return st == 'active';
      }).toList();

      final now = DateTime.now();
      DateTime cutoff;
      switch (_filterIndex) {
        case 1: // This Week — last 7 days
          cutoff = now.subtract(const Duration(days: 7));
          break;
        case 2: // This Month — last 30 days
          cutoff = now.subtract(const Duration(days: 30));
          break;
        default: // Recent — last 48 hours
          cutoff = now.subtract(const Duration(hours: 48));
      }
      list = activeList.where((r) {
        final ts = r['reported_at']?.toString() ?? '';
        if (ts.isEmpty) return true;
        try {
          return DateTime.parse(ts).isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return list;

    return list.where((r) {
      final pet = r['pets'];
      final petMap = pet is Map ? pet : null;

      final name =
          (petMap?['name'] ?? r['pet_name'] ?? '').toString().toLowerCase();
      final species =
          (petMap?['species'] ?? r['species'] ?? '').toString().toLowerCase();
      final breed =
          (petMap?['breed'] ?? r['breed'] ?? '').toString().toLowerCase();
      final address = (r['last_seen_address'] ?? r['barangay'] ?? '')
          .toString()
          .toLowerCase();
      final desc = (r['description'] ?? petMap?['description'] ?? '')
          .toString()
          .toLowerCase();

      final owner = r['owner_id'] is Map
          ? r['owner_id'] as Map
          : (r['users'] is Map ? r['users'] as Map : null);
      final ownerName = owner != null
          ? [owner['first_name'], owner['surname']]
              .where((s) => s != null)
              .join(' ')
              .toLowerCase()
          : '';

      return name.contains(query) ||
          species.contains(query) ||
          breed.contains(query) ||
          address.contains(query) ||
          desc.contains(query) ||
          ownerName.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchLostPets();
  }

  Future<void> _fetchLostPets() async {
    try {
      final data = await Supabase.instance.client
          .from('lost_reports')
          .select('*, pets(*), owner_id(*)')
          .order('reported_at', ascending: false);
      if (mounted) {
        setState(() {
          _lostPetsList = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lost reports: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filtered;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchLostPets,
                color: AppColors.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Search Bar on top of pills ──────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: _buildSearchBar(),
                      ),
                    ),

                    // ── Time-filter pill row ────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filterLabels.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final active = i == _filterIndex;
                              return GestureDetector(
                                onTap: () => setState(() => _filterIndex = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.primaryContainer
                                        : AppColors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: active
                                          ? Colors.transparent
                                          : AppColors.outlineVariant
                                              .withOpacity(0.2),
                                    ),
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primaryContainer
                                                  .withOpacity(0.30),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Text(
                                    _filterLabels[i],
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: active
                                          ? AppColors.onPrimaryContainer
                                          : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // ── Content ────────────────────────────────────────────────────
                    if (_isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primaryContainer)),
                        ),
                      )
                    else if (displayList.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 48,
                                    color: AppColors.onSurfaceVariant
                                        .withOpacity(0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  _searchCtrl.text.trim().isNotEmpty
                                      ? 'No lost pets found matching "${_searchCtrl.text.trim()}".'
                                      : 'No reports for this period.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: AppColors.onSurfaceVariant
                                        .withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final pet = displayList[index];
                            return Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20,
                                  index == displayList.length - 1 ? 120 : 16),
                              child: LostPetCard(pet: pet),
                            );
                          },
                          childCount: displayList.length,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.primaryContainer, size: 22),
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
          hintText: 'Search by name, species, breed, location...',
          hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant.withOpacity(0.55)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.outlineVariant.withOpacity(0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.outlineVariant.withOpacity(0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primaryContainer,
              width: 1.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding:
          EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Lost Pets',
                    style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
              ],
            ),
          ),
          IconButton(
              onPressed: _fetchLostPets,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

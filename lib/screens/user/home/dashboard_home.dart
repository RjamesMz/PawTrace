import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../services/auth/auth_service.dart';
import '../../../widgets/common/notification_bell_button.dart';
import '../../../widgets/user/lost_pet/lost_pet_card.dart';

/// User Dashboard Home screen – surfaces active and recent lost pet reports,
/// with search filtering, time filter pills, and quick access to My Pets and Settings.
class DashboardHomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const DashboardHomeScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  String? _photoUrl;
  List<Map<String, dynamic>> _lostPetsList = [];
  bool _isLoadingLostPets = true;

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
  void initState() {
    super.initState();
    AuthService.instance.profileNotifier.addListener(_onProfileChanged);
    _loadProfile();
    _fetchLostPets();
  }

  @override
  void dispose() {
    AuthService.instance.profileNotifier.removeListener(_onProfileChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    final profile = AuthService.instance.profileNotifier.value;
    if (profile != null && mounted) {
      setState(() {
        _photoUrl = profile['photo_url'] as String?;
      });
    }
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.instance.getCurrentUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _photoUrl = profile['photo_url'];
      });
    }
  }

  Future<void> _fetchLostPets() async {
    setState(() => _isLoadingLostPets = true);
    try {
      final data = await Supabase.instance.client
          .from('lost_reports')
          .select('*, pets(*), owner_id(*)')
          .order('reported_at', ascending: false);
      if (mounted) {
        setState(() {
          _lostPetsList = List<Map<String, dynamic>>.from(data);
          _isLoadingLostPets = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lost reports: $e');
      if (mounted) {
        setState(() => _isLoadingLostPets = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadProfile(),
      _fetchLostPets(),
    ]);
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

      final owner = r['owner_id'] is Map ? r['owner_id'] as Map : null;
      final ownerFirst = (owner?['first_name'] ?? '').toString().toLowerCase();
      final ownerSurname = (owner?['surname'] ?? '').toString().toLowerCase();
      final ownerPhone = (owner?['phone'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          species.contains(query) ||
          breed.contains(query) ||
          address.contains(query) ||
          desc.contains(query) ||
          ownerFirst.contains(query) ||
          ownerSurname.contains(query) ||
          ownerPhone.contains(query);
    }).toList();
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
            _TopBar(
              photoUrl: _photoUrl,
              onSettings: () async {
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(4);
                } else {
                  await Navigator.pushNamed(context, AppRoutes.settings);
                  if (mounted) {
                    _loadProfile();
                  }
                }
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                color: AppColors.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Search Bar ──────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: _buildSearchBar(),
                      ),
                    ),

                    // ── Time-filter pill row ─────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
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

                    // ── Content ──────────────────────────────────────────────
                    if (_isLoadingLostPets)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    else if (displayList.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 20),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: AppColors.onSurfaceVariant
                                      .withOpacity(0.35),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No lost pet reports found',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try adjusting your search or time filter.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: AppColors.onSurfaceVariant
                                        .withOpacity(0.6),
                                    fontSize: 13,
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
                              padding: EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                index == displayList.length - 1 ? 120 : 16,
                              ),
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
}

class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final String? photoUrl;

  const _TopBar({
    required this.onSettings,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 8, 12, 8),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppConstants.buildLogoGraphic(
                  size: 32,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    AppConstants.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NotificationBellButton(size: 20),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 36),
                onPressed: onSettings,
                icon: ClipOval(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: photoUrl != null && photoUrl!.isNotEmpty
                        ? Image.network(
                            photoUrl!,
                            key: ValueKey(photoUrl),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surfaceContainerHighest,
                              child: const Icon(Icons.person,
                                  size: 16, color: AppColors.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceContainerHighest,
                            child: const Icon(Icons.person,
                                size: 16, color: AppColors.onSurfaceVariant),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

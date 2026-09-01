import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../widgets/bottom_nav_bar.dart';

/// Lost Pet screen – full overview of the current lost-pet reports.
class LostPetDetailsScreen extends StatefulWidget {
  const LostPetDetailsScreen({super.key});

  @override
  State<LostPetDetailsScreen> createState() => _LostPetDetailsScreenState();
}

class _LostPetDetailsScreenState extends State<LostPetDetailsScreen> {
  List<Map<String, dynamic>> _lostPetsList = [];
  bool _isLoading = true;

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
          .eq('status', 'active')
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  _FilterChip(label: 'All', active: true),
                  SizedBox(width: 10),
                  _FilterChip(label: 'Recent'),
                  SizedBox(width: 10),
                  _FilterChip(label: 'Urgent'),
                ],
              ),
            ),
          ),
          _isLoading
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)),
                  ),
                )
              : _lostPetsList.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No active lost reports found.',
                            style: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pet = _lostPetsList[index];
                          return Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, index == _lostPetsList.length - 1 ? 120 : 16),
                            child: _LostPetCard(pet: pet),
                          );
                        },
                        childCount: _lostPetsList.length,
                      ),
                    ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Current Lost Pets', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                Text('${_lostPetsList.length} active reports', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.search, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;

  const _FilterChip({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? Colors.transparent : AppColors.outlineVariant.withOpacity(0.22)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.onSurfaceVariant)),
    );
  }
}

class _LostPetCard extends StatelessWidget {
  final Map<String, dynamic> pet;

  const _LostPetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final petData = pet['pets'] as Map<String, dynamic>?;
    // 'owner_id' is the FK-hint alias used in the select query
    final userData = (pet['owner_id'] is Map<String, dynamic>
            ? pet['owner_id'] as Map<String, dynamic>
            : null) ??
        (pet['users'] as Map<String, dynamic>?);

    final petName = petData?['name'] as String? ?? 'Unknown';
    final breed = petData?['breed'] as String? ?? 'Unknown Breed';
    final imageUrl = pet['photo_url'] as String? ?? petData?['photo_url'] as String? ?? '';
    final location = pet['last_seen_address'] as String? ?? pet['barangay'] as String? ?? 'Calatagan';
    final note = pet['description'] as String? ?? '';
    final timeAgo = _formatTimeAgo(pet['reported_at']);
    
    final ownerName = userData != null
        ? [userData['first_name'], userData['middle_name'], userData['surname'], userData['suffix']].where((s) => s != null && s.toString().isNotEmpty).join(' ')
        : 'Unknown Owner';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Center(child: Icon(Icons.pets, size: 72, color: AppColors.primaryContainer)),
                    ),
                  )
                : Container(
                    color: AppColors.surfaceContainerHigh,
                    child: const Center(child: Icon(Icons.pets, size: 72, color: AppColors.primaryContainer)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(petName, style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                          const SizedBox(height: 2),
                          Text(breed, style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(999)),
                      child: Text('LOST', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error, letterSpacing: 0.8)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(child: Text(location, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(child: Text('Owner: $ownerName', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(timeAgo, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(note, style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.onSurfaceVariant)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Contact owner'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.28)),
                          foregroundColor: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('View map'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Local Helper Functions ──────────────────────────────────────────────────

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

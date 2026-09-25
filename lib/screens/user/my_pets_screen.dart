import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'pet_profile_detail.dart';

/// My Pets screen – fetches and displays only the logged-in user's pets
/// from Supabase.
class MyPetsScreen extends StatefulWidget {
  const MyPetsScreen({super.key});

  @override
  State<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends State<MyPetsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> myPets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyPets();
  }

  Future<void> fetchMyPets() async {
    setState(() => isLoading = true);
    try {
      final data = await _supabase
          .from('pets')
          .select()
          .eq('owner_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => myPets = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Error loading pets: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(child: _buildBody()),
          const BottomNavBar(currentIndex: 3),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Text('My Pets',
                  style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface)),
              const Spacer(),
              if (!isLoading && myPets.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('${myPets.length} Pets',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimaryContainer)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Beautiful "Add New Pet" banner ───────────────────────────────
          GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(
                  context, AppRoutes.profilePetRegistration);
              fetchMyPets();
            },
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pets,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add a New Pet',
                            style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Register your pet to PawTrace',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.85))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (myPets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.pets, size: 60, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No pets registered yet',
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
            const SizedBox(height: 8),
            Text('Tap the banner above to register your first pet!',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: fetchMyPets,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: myPets.length,
        itemBuilder: (context, index) {
          final pet = myPets[index];
          return _buildPetCard(pet);
        },
      ),
    );
  }

  Widget _buildPetCard(Map<String, dynamic> pet) {
    final isLost =
        (pet['status'] ?? 'active').toString().toLowerCase() == 'lost';
    final name = pet['name'] ?? 'Unknown';
    final breed = pet['breed'] ?? '';
    final species = pet['species'] ?? '';
    final barangay = pet['barangay'] ?? '';
    final photoUrl = pet['photo_url'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PetProfileDetailScreen(pet: pet),
            ),
          );
          fetchMyPets();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4))
            ],
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
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('$breed • $species',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant)),
                      if (barangay.toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(barangay,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.7))),
                      ],
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLost
                        ? AppColors.errorContainer
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isLost ? 'Lost' : 'Active',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isLost
                          ? AppColors.error
                          : const Color(0xFF065F46),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right,
                    color: AppColors.outline, size: 20),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppColors.primaryContainer.withOpacity(0.2),
      child: const Center(
          child: Icon(Icons.pets,
              color: AppColors.primaryContainer, size: 32)),
    );
  }
}

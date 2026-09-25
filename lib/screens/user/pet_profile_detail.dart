import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../core/navigation_helpers.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/pair_collar_dialog.dart';
import 'locate_pet_screen.dart';

/// Pet Profile Detail screen – detailed individual pet profile view.
class PetProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? pet;
  const PetProfileDetailScreen({super.key, this.pet});

  @override
  State<PetProfileDetailScreen> createState() => _PetProfileDetailScreenState();
}

class _PetProfileDetailScreenState extends State<PetProfileDetailScreen> {
  bool _isRemoving = false;
  bool _isMarkingFound = false;
  Map<String, dynamic>? _currentPet;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
  }

  Future<void> _reloadPet() async {
    final petId = _currentPet?['pet_id'] ?? (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?)?['pet_id'];
    if (petId == null) return;
    try {
      final data = await Supabase.instance.client.from('pets').select().eq('pet_id', petId).single();
      if (mounted) {
        setState(() {
          _currentPet = data;
        });
      }
    } catch (e) {
      debugPrint('Error reloading pet: $e');
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty || isoString == 'null' || isoString.toLowerCase() == 'n/a') return 'N/A';
    try {
      final dt = DateTime.parse(isoString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _markPetFound() async {
    final pet = _currentPet;
    if (pet == null) return;
    final petId = pet['pet_id'];
    if (petId == null) return;

    setState(() => _isMarkingFound = true);
    try {
      // 1. Update pet status back to active
      await Supabase.instance.client
          .from('pets')
          .update({'status': 'active'})
          .eq('pet_id', petId);

      // 2. Delete the active lost report for this pet
      await Supabase.instance.client
          .from('lost_reports')
          .delete()
          .eq('pet_id', petId)
          .eq('status', 'active');

      if (!mounted) return;

      AppToast.success(
        context,
        '${pet['name'] ?? 'Pet'} has been marked as found! 🎉',
      );

      _reloadPet();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to mark as found: $e');
    } finally {
      if (mounted) setState(() => _isMarkingFound = false);
    }
  }

  Future<void> _removePet(Map<String, dynamic> pet, String reason) async {
    setState(() => _isRemoving = true);
    try {
      final petId = pet['pet_id'];
      if (petId == null) throw Exception('Pet ID is missing.');
      // Delete the pet's photo from the storage bucket
      final photoUrl = pet['photo_url'] as String?;
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl.contains('pet-photos/')) {
        try {
          final filePath = photoUrl.split('pet-photos/').last;
          await Supabase.instance.client.storage.from('pet-photos').remove([filePath]);
        } catch (e) {
          debugPrint('Failed to delete pet photo: $e');
        }
      }

      // Perform delete operation in Supabase
      await Supabase.instance.client
          .from('pets')
          .delete()
          .eq('pet_id', petId);

      if (!mounted) return;

      AppToast.success(
        context,
        '${pet['name'] ?? 'Pet'} profile removed. Reason: $reason',
      );

      // Return back to My Pets list screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to remove pet: $e');
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  void _showRemovePetDialog(Map<String, dynamic> pet) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final petName = (pet['name'] ?? 'this pet').toString();
        String? selectedReason;
        final reasonCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            final canRemove = selectedReason != null &&
                (selectedReason != 'Other' || reasonCtrl.text.trim().isNotEmpty);

            Widget reasonChip(String label, IconData icon) {
              final isSelected = selectedReason == label;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    selectedReason = label;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.errorContainer : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.error.withOpacity(0.45) : AppColors.outlineVariant.withOpacity(0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: isSelected ? AppColors.error : AppColors.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.onErrorContainer : AppColors.onSurface,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: isSelected
                            ? const Icon(Icons.check_circle_rounded, key: ValueKey('selected'), size: 18, color: AppColors.error)
                            : const SizedBox(key: ValueKey('empty'), width: 18, height: 18),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withOpacity(0.18)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Remove Pet Profile',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onErrorContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You are removing $petName from your profiles. This cannot be undone.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select reason',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      reasonChip('Deceased', Icons.favorite_border_rounded),
                      const SizedBox(height: 8),
                      reasonChip('Adopted', Icons.home_rounded),
                      const SizedBox(height: 8),
                      reasonChip('Other', Icons.edit_note_rounded),
                      if (selectedReason == 'Other') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: reasonCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Please specify the reason...',
                            hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withOpacity(0.65)),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          maxLines: 2,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.onSurfaceVariant,
                                side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.7)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: !canRemove
                                  ? null
                                  : () {
                                      final finalReason =
                                          selectedReason == 'Other' ? reasonCtrl.text.trim() : selectedReason;
                                      Navigator.pop(context);
                                      _removePet(pet, finalReason!);
                                    },
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: Text(
                                'Remove',
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.surfaceContainerHigh,
                                disabledForegroundColor: AppColors.onSurfaceVariant,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPet == null) {
      final args = widget.pet ?? (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
      if (args != null) {
        _currentPet = args;
      }
    }
    final Map<String, dynamic> pet = _currentPet ?? {};

    final name = pet['name'] ?? 'Cooper';
    final species = pet['species'] ?? 'Canine';
    final breed = pet['breed'] ?? 'Golden Retriever';
    final status = (pet['status'] ?? 'Active').toString().toUpperCase();
    final photoUrl = pet['photo_url'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white, // Status bar area becomes white
      body: _isRemoving
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              bottom: false,
              child: Container(
                color: AppColors.background,
                child: CustomScrollView(
                  slivers: [
                SliverAppBar(
                  expandedHeight: 360,
                  toolbarHeight: 76,
                  pinned: true,
                  backgroundColor: AppColors.surface,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 12, right: 8, bottom: 8),
                    child: GestureDetector(
                      onTap: () => handleSafeBack(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(999)),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  // Removed PawTrace logo, share and edit icons per user request
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _fallbackImage(),
                              )
                            : _fallbackImage(),
                        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black38]))),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    child: Column(
                      children: [
                        _buildIdentityHeader(name, breed, species, status),
                        const SizedBox(height: 16),
                        _buildInfoGrid(pet),
                        const SizedBox(height: 20),
                        _buildActionButtons(context, pet),
                        const SizedBox(height: 24),
                        _buildSecondaryActions(pet),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 4),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: const Icon(Icons.pets, size: 80, color: AppColors.primaryContainer),
    );
  }

  Widget _appBarBtn(IconData icon) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
        child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
      ),
    );
  }

  Widget _buildIdentityHeader(String name, String breed, String species, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          Text('$breed • $species', style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurfaceVariant)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: status == 'LOST' ? AppColors.errorContainer : AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: status == 'LOST' ? AppColors.error : AppColors.onPrimaryContainer,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> pet) {
    final dob = _formatDate(pet['date_of_birth']);
    final weight = '${pet['weight'] ?? '0.0'} kg';
    final color = pet['color'] ?? 'Unknown';
    final rawCollarId = pet['collar_id'] as String?;
    final hasCollar = rawCollarId != null && rawCollarId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _infoCell('Date of Birth', dob, border: const Border(right: BorderSide(color: Color(0xFFDDC1AE), width: 0.5)))),
              Expanded(child: Padding(padding: const EdgeInsets.only(left: 16), child: _infoCell('Weight', weight))),
            ],
          ),
          const Divider(height: 28, color: Color(0xFFDDC1AE), thickness: 0.5),
          Row(
            children: [
              Expanded(child: _infoCell('Color & Markings', color, border: const Border(right: BorderSide(color: Color(0xFFDDC1AE), width: 0.5)))),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final result = await showPairCollarDialog(context: context, pet: pet);
                      if (result != null) {
                        _reloadPet();
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'COLLAR ID',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                hasCollar ? rawCollarId : 'Not Paired',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: hasCollar ? AppColors.onSurface : AppColors.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasCollar ? const Color(0xFFD1FAE5) : AppColors.primaryContainer.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hasCollar ? 'PAIRED' : 'PAIR',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: hasCollar ? const Color(0xFF065F46) : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _infoCell(String label, String value, {Border? border}) {
    return Container(
      decoration: BoxDecoration(border: border),
      padding: border != null ? const EdgeInsets.only(right: 16) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      ]),
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> pet) {
    final isLost = (pet['status'] ?? '').toString().toLowerCase() == 'lost';

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LocatePetScreen(pet: pet),
                ),
              );
              _reloadPet();
            },
            icon: const Icon(Icons.location_on, size: 20),
            label: const Text('Locate My Pet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008080),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              shadowColor: const Color(0xFF008080).withOpacity(0.2),
              textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isLost)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isMarkingFound ? null : _markPetFound,
              icon: _isMarkingFound
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(_isMarkingFound ? 'Updating...' : 'Pet Has Been Found!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                final Map<String, dynamic> currentPet = _currentPet ?? {};
                await Navigator.pushNamed(context, AppRoutes.reportLostPet, arguments: currentPet);
                _reloadPet();
              },
              icon: const Icon(Icons.warning_amber_rounded, size: 20),
              label: const Text('Report as Lost'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error, width: 2),
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSecondaryActions(Map<String, dynamic> pet) {
    return Column(
      children: [
        const Divider(color: Color(0xFFDDC1AE), thickness: 0.5),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _showRemovePetDialog(pet),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Remove Pet Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

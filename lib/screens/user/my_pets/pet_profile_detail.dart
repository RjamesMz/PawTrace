import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_toast.dart';
import '../../../core/navigation_helpers.dart';
import '../../../widgets/user/bottom_nav_bar.dart';
import '../../../widgets/user/pair_collar_dialog.dart';
import '../../../services/audit/pet_audit_service.dart';
import '../locate_pet/locate_pet_screen.dart';

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
    final petId = _currentPet?['pet_id'] ??
        (ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>?)?['pet_id'];
    if (petId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('pets')
          .select()
          .eq('pet_id', petId)
          .single();
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
    if (isoString == null ||
        isoString.isEmpty ||
        isoString == 'null' ||
        isoString.toLowerCase() == 'n/a') {
      return 'N/A';
    }
    try {
      final dt = DateTime.parse(isoString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
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
          .update({'status': 'active'}).eq('pet_id', petId);

      // 2. Soft-archive the active lost report for this pet (preserve data history)
      await Supabase.instance.client
          .from('lost_reports')
          .update({
            'status': 'archived',
          })
          .eq('pet_id', petId)
          .eq('status', 'active');

      // 3. Log modification audit trail
      PetAuditService.instance.logPetModification(
        petId: petId,
        petName: pet['name']?.toString() ?? 'Pet',
        action: 'Status Changed: Found (Active)',
        changesSummary: 'Pet marked as found. Open lost reports archived.',
        modifiedByRole: 'Owner',
      );

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

  Future<void> _archivePet(Map<String, dynamic> pet, String reason) async {
    setState(() => _isRemoving = true);
    try {
      final petId = pet['pet_id'];
      if (petId == null) throw Exception('Pet ID is missing.');

      // Purge collar locations for this collar so it is completely fresh when reused
      final collarId = pet['gps_id']?.toString().trim();
      if (collarId != null &&
          collarId.isNotEmpty &&
          collarId.toUpperCase() != 'N/A') {
        try {
          await Supabase.instance.client
              .from('gps_locations')
              .delete()
              .eq('gps_id', collarId);
        } catch (_) {}
      }

      // Soft delete: Update status to 'archived' in Supabase
      // Preserves photo, medical/biometric records, and audit history
      try {
        await Supabase.instance.client.from('pets').update({
          'status': 'archived',
          'gps_id': null, // Unpair collar so it can be reused
          'archive_reason': reason,
        }).eq('pet_id', petId);
      } catch (_) {
        // Fallback if archive_reason column doesn't exist yet
        await Supabase.instance.client.from('pets').update({
          'status': 'archived',
          'gps_id': null,
        }).eq('pet_id', petId);
      }

      // Soft-archive any active lost reports for this pet (preserve data history)
      await Supabase.instance.client
          .from('lost_reports')
          .update({
            'status': 'archived',
          })
          .eq('pet_id', petId)
          .neq('status', 'archived');

      // Log modification audit trail
      PetAuditService.instance.logPetModification(
        petId: petId,
        petName: pet['name']?.toString() ?? 'Pet',
        action: 'Profile Archived',
        changesSummary: 'Reason: $reason',
        modifiedByRole: 'Owner',
      );

      if (!mounted) return;

      AppToast.success(
        context,
        '${pet['name'] ?? 'Pet'} profile has been archived. Reason: $reason',
      );

      // Return back to My Pets list screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to archive pet: $e');
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
                (selectedReason != 'Other' ||
                    reasonCtrl.text.trim().isNotEmpty);

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.errorContainer
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.error.withOpacity(0.45)
                          : AppColors.outlineVariant.withOpacity(0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon,
                          size: 18,
                          color: isSelected
                              ? AppColors.error
                              : AppColors.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.onErrorContainer
                                : AppColors.onSurface,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                key: ValueKey('selected'),
                                size: 18,
                                color: AppColors.error)
                            : const SizedBox(
                                key: ValueKey('empty'), width: 18, height: 18),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
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
                          border: Border.all(
                              color: AppColors.error.withOpacity(0.18)),
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
                              child: const Icon(Icons.archive_outlined,
                                  color: AppColors.error, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Archive Pet Profile',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onErrorContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Archive $petName from your active pets list. Their records and biometrics are safely preserved in history.',
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
                      reasonChip('Passed Away', Icons.favorite_border_rounded),
                      const SizedBox(height: 8),
                      reasonChip('Rehomed / Adopted', Icons.home_rounded),
                      const SizedBox(height: 8),
                      reasonChip('No longer in my care', Icons.pets_rounded),
                      const SizedBox(height: 8),
                      reasonChip('Other', Icons.edit_note_rounded),
                      if (selectedReason == 'Other') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: reasonCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Please specify the reason...',
                            hintStyle: GoogleFonts.inter(
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.65)),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 1.8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
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
                                side: BorderSide(
                                    color: AppColors.outlineVariant
                                        .withOpacity(0.7)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700),
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
                                          selectedReason == 'Other'
                                              ? reasonCtrl.text.trim()
                                              : selectedReason;
                                      Navigator.pop(context);
                                      _archivePet(pet, finalReason!);
                                    },
                              icon: const Icon(Icons.archive_rounded, size: 18),
                              label: Text(
                                'Archive',
                                style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.surfaceContainerHigh,
                                disabledForegroundColor:
                                    AppColors.onSurfaceVariant,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
      final args = widget.pet ??
          (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              bottom: false,
              child: Container(
                color: AppColors.background,
                child: RefreshIndicator(
                  onRefresh: _reloadPet,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 360,
                        toolbarHeight: 76,
                        pinned: true,
                        backgroundColor: AppColors.surface,
                        leading: Padding(
                          padding: const EdgeInsets.only(
                              left: 8, top: 12, right: 8, bottom: 8),
                          child: GestureDetector(
                            onTap: () => handleSafeBack(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(999)),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        actions: [
                          Padding(
                            padding: const EdgeInsets.only(
                                right: 12, top: 12, bottom: 8),
                            child: GestureDetector(
                              onTap: () => _showEditPetDialog(pet),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit_rounded,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Edit',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              photoUrl.isNotEmpty
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _fallbackImage(),
                                    )
                                  : _fallbackImage(),
                              const DecoratedBox(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                    Colors.transparent,
                                    Colors.black38
                                  ]))),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                          child: Column(
                            children: [
                              _buildIdentityHeader(
                                  name, breed, species, status),
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
            ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 4),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child:
          const Icon(Icons.pets, size: 80, color: AppColors.primaryContainer),
    );
  }

  Widget _buildIdentityHeader(
      String name, String breed, String species, String status) {
    final upperStatus = status.toUpperCase().trim();
    Color bg;
    Color fg;
    switch (upperStatus) {
      case 'ARCHIVED':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        break;
      case 'LOST':
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        break;
      case 'FOUND':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case 'ACTIVE':
      default:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface),
                overflow: TextOverflow.ellipsis),
            Text('$breed • $species',
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: fg.withOpacity(0.25)),
          ),
          child: Text(
            upperStatus.isNotEmpty ? upperStatus : 'ACTIVE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
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
    final rawCollarId = pet['gps_id'] as String?;
    final hasCollar = rawCollarId != null && rawCollarId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _infoCell('Date of Birth', dob,
                      border: const Border(
                          right: BorderSide(
                              color: Color(0xFFDDC1AE), width: 0.5)))),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: _infoCell('Weight', weight))),
            ],
          ),
          const Divider(height: 28, color: Color(0xFFDDC1AE), thickness: 0.5),
          Row(
            children: [
              Expanded(
                  child: _infoCell('Color & Markings', color,
                      border: const Border(
                          right: BorderSide(
                              color: Color(0xFFDDC1AE), width: 0.5)))),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final result = await showPairCollarDialog(
                          context: context, pet: pet);
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
                            const Icon(Icons.edit_outlined,
                                size: 12, color: AppColors.primary),
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
                                  color: hasCollar
                                      ? AppColors.onSurface
                                      : AppColors.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasCollar
                                    ? const Color(0xFFD1FAE5)
                                    : AppColors.primaryContainer
                                        .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hasCollar ? 'PAIRED' : 'PAIR',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: hasCollar
                                      ? const Color(0xFF065F46)
                                      : AppColors.primary,
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
        Text(label.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
      ]),
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> pet) {
    final status = (pet['status'] ?? '').toString().toLowerCase();
    final isLost = status == 'lost';
    final isArchived = status == 'archived';

    if (isArchived) {
      final reason =
          (pet['archive_reason'] ?? pet['reason'] ?? '').toString().trim();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.archive_outlined,
                  color: Color(0xFF475569), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archived Pet Profile',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reason.isNotEmpty
                        ? 'Reason: $reason\nThis pet profile has been archived. Biometric records and medical history are safely preserved.'
                        : 'This pet profile has been archived and removed from active pets. Historical records and biometrics remain preserved.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _showEditPetDialog(pet),
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Edit Profile & Status'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.6),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              shadowColor: const Color(0xFF008080).withOpacity(0.2),
              textStyle:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
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
              label:
                  Text(_isMarkingFound ? 'Updating...' : 'Pet Has Been Found!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                textStyle: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700),
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
                await Navigator.pushNamed(context, AppRoutes.reportLostPet,
                    arguments: currentPet);
                _reloadPet();
              },
              icon: const Icon(Icons.warning_amber_rounded, size: 20),
              label: const Text('Report as Lost'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error, width: 2),
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSecondaryActions(Map<String, dynamic> pet) {
    final isArchived =
        (pet['status'] ?? '').toString().toLowerCase() == 'archived';
    if (isArchived) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(color: Color(0xFFDDC1AE), thickness: 0.5),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _showRemovePetDialog(pet),
            icon: const Icon(Icons.archive_outlined, size: 20),
            label: const Text('Archive Pet Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              textStyle:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
          color: AppColors.onSurfaceVariant.withOpacity(0.6), fontSize: 13.5),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.outlineVariant.withOpacity(0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.outlineVariant.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _speciesChip(String species, String label, bool isSelected,
      Function(bool) onSelected) {
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(true),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer.withOpacity(0.3)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditPetDialog(Map<String, dynamic> pet) async {
    final petId = pet['pet_id'];
    if (petId == null) return;

    final nameCtrl = TextEditingController(text: pet['name']?.toString() ?? '');
    final breedCtrl = TextEditingController(
      text: (pet['breed'] != null && pet['breed'] != 'N/A')
          ? pet['breed'].toString()
          : '',
    );
    final colorCtrl = TextEditingController(
      text: (pet['color'] != null && pet['color'] != 'N/A')
          ? pet['color'].toString()
          : '',
    );
    final weightCtrl = TextEditingController(
      text:
          (pet['weight'] != null && pet['weight'] != 0 && pet['weight'] != 0.0)
              ? pet['weight'].toString()
              : '',
    );
    final barangayCtrl = TextEditingController(
      text: pet['barangay']?.toString() ?? 'Calatagan',
    );

    String selectedSpecies =
        (pet['species']?.toString().toLowerCase() == 'cat') ? 'Cat' : 'Dog';
    String selectedStatus =
        (pet['status']?.toString().toLowerCase() == 'lost') ? 'lost' : 'active';
    DateTime? selectedDOB = pet['date_of_birth'] != null
        ? DateTime.tryParse(pet['date_of_birth'].toString())
        : null;
    bool isDOBUnknown = selectedDOB == null;
    File? newPhotoFile;
    bool isSubmitting = false;
    String? errorMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickNewPhoto() async {
              final picker = ImagePicker();
              final source = await showModalBottomSheet<ImageSource>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_camera_rounded,
                              color: AppColors.primary),
                          title: const Text('Take a photo'),
                          onTap: () => Navigator.pop(ctx, ImageSource.camera),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_rounded,
                              color: AppColors.primary),
                          title: const Text('Choose from gallery'),
                          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (source == null) return;
              final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 1200,
                  maxHeight: 1200,
                  imageQuality: 85);
              if (picked != null) {
                setModalState(() {
                  newPhotoFile = File(picked.path);
                });
              }
            }

            Future<void> selectDOB() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDOB ??
                    DateTime.now().subtract(const Duration(days: 365)),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setModalState(() {
                  selectedDOB = picked;
                  isDOBUnknown = false;
                });
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_note_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Pet Profile',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                'Update details, physical description, or status',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        MediaQuery.of(context).viewInsets.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: AppColors.error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: GoogleFonts.inter(
                                          color: AppColors.onErrorContainer,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Pet Photo Preview & Update Button
                          Center(
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    color: AppColors.surfaceContainerHigh,
                                    child: newPhotoFile != null
                                        ? Image.file(newPhotoFile!,
                                            fit: BoxFit.cover)
                                        : (pet['photo_url'] != null &&
                                                pet['photo_url']
                                                    .toString()
                                                    .isNotEmpty
                                            ? Image.network(
                                                pet['photo_url'].toString(),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.pets,
                                                        size: 40,
                                                        color:
                                                            AppColors.primary),
                                              )
                                            : const Icon(Icons.pets,
                                                size: 40,
                                                color: AppColors.primary)),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: pickNewPhoto,
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton.icon(
                              onPressed: pickNewPhoto,
                              icon: const Icon(Icons.photo_camera_rounded,
                                  size: 16),
                              label: Text(newPhotoFile != null
                                  ? 'Change Selected Photo'
                                  : 'Update Photo'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                textStyle: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // STATUS SELECTOR (Active vs Lost)
                          Text(
                            'PET STATUS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setModalState(
                                      () => selectedStatus = 'active'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedStatus == 'active'
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selectedStatus == 'active'
                                            ? const Color(0xFF16A34A)
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: selectedStatus == 'active'
                                              ? const Color(0xFF16A34A)
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ACTIVE / SAFE',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: selectedStatus == 'active'
                                                ? const Color(0xFF166534)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setModalState(
                                      () => selectedStatus = 'lost'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedStatus == 'lost'
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selectedStatus == 'lost'
                                            ? const Color(0xFFDC2626)
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 18,
                                          color: selectedStatus == 'lost'
                                              ? const Color(0xFFDC2626)
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'REPORTED LOST',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: selectedStatus == 'lost'
                                                ? const Color(0xFF991B1B)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // PET NAME
                          _buildFieldLabel('PET NAME *'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            decoration: _inputDecoration(
                                'e.g. Cutie', Icons.badge_outlined),
                          ),
                          const SizedBox(height: 14),

                          // SPECIES SELECTOR
                          _buildFieldLabel('SPECIES'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _speciesChip(
                                  'Dog',
                                  '🐶 Dog',
                                  selectedSpecies == 'Dog',
                                  (val) => setModalState(
                                      () => selectedSpecies = 'Dog')),
                              const SizedBox(width: 10),
                              _speciesChip(
                                  'Cat',
                                  '🐱 Cat',
                                  selectedSpecies == 'Cat',
                                  (val) => setModalState(
                                      () => selectedSpecies = 'Cat')),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // BREED
                          _buildFieldLabel('BREED'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: breedCtrl,
                            decoration: _inputDecoration(
                                'e.g. Puspin, Golden Retriever, Aspin',
                                Icons.pets_outlined),
                          ),
                          const SizedBox(height: 14),

                          // COLOR, MARKINGS & DESCRIPTION
                          _buildFieldLabel(
                              'COLOR, DISTINCTIVE MARKINGS & DESCRIPTION'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: colorCtrl,
                            maxLines: 3,
                            decoration: _inputDecoration(
                              'Describe coat color, spots, unique physical marks, ear tips, or collar tag details...',
                              Icons.description_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // WEIGHT (KG)
                          _buildFieldLabel('WEIGHT (KG)'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: _inputDecoration(
                                'e.g. 4.5', Icons.monitor_weight_outlined),
                          ),
                          const SizedBox(height: 14),

                          // BARANGAY
                          _buildFieldLabel('REGISTERED BARANGAY'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: barangayCtrl,
                            decoration: _inputDecoration(
                                'e.g. Calatagan', Icons.location_on_outlined),
                          ),
                          const SizedBox(height: 14),

                          // DATE OF BIRTH
                          _buildFieldLabel('DATE OF BIRTH'),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: selectDOB,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.outlineVariant
                                        .withOpacity(0.6)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 18, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    isDOBUnknown
                                        ? 'Date of birth unknown'
                                        : (selectedDOB != null
                                            ? _formatDate(
                                                selectedDOB!.toIso8601String())
                                            : 'Select date'),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDOBUnknown
                                          ? AppColors.onSurfaceVariant
                                          : AppColors.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_drop_down,
                                      color: AppColors.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: isDOBUnknown,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setModalState(() {
                                    isDOBUnknown = val ?? false;
                                    if (isDOBUnknown) selectedDOB = null;
                                  });
                                },
                              ),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    isDOBUnknown = !isDOBUnknown;
                                    if (isDOBUnknown) selectedDOB = null;
                                  });
                                },
                                child: Text(
                                  'Date of birth is unknown / approximate',
                                  style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // SAVE BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final newName = nameCtrl.text.trim();
                                      if (newName.isEmpty) {
                                        setModalState(() => errorMessage =
                                            'Pet name cannot be empty.');
                                        return;
                                      }

                                      setModalState(() {
                                        isSubmitting = true;
                                        errorMessage = null;
                                      });

                                      try {
                                        String? photoUrl;
                                        if (newPhotoFile != null) {
                                          final timestamp = DateTime.now()
                                              .millisecondsSinceEpoch;
                                          final randomSuffix = Random()
                                              .nextInt(999999)
                                              .toString()
                                              .padLeft(6, '0');
                                          final fileExt = newPhotoFile!.path
                                              .split('.')
                                              .last;
                                          final fileName =
                                              'pets/${timestamp}_face_$randomSuffix.$fileExt';
                                          await Supabase.instance.client.storage
                                              .from('pet-photos')
                                              .upload(fileName, newPhotoFile!);
                                          photoUrl = Supabase
                                              .instance.client.storage
                                              .from('pet-photos')
                                              .getPublicUrl(fileName);
                                        }

                                        final updatePayload = <String, dynamic>{
                                          'name': newName,
                                          'species': selectedSpecies,
                                          'breed': breedCtrl.text.trim().isEmpty
                                              ? 'N/A'
                                              : breedCtrl.text.trim(),
                                          'color': colorCtrl.text.trim().isEmpty
                                              ? 'N/A'
                                              : colorCtrl.text.trim(),
                                          'weight': double.tryParse(
                                                  weightCtrl.text.trim()) ??
                                              0.0,
                                          'barangay':
                                              barangayCtrl.text.trim().isEmpty
                                                  ? 'Calatagan'
                                                  : barangayCtrl.text.trim(),
                                          'date_of_birth': isDOBUnknown ||
                                                  selectedDOB == null
                                              ? null
                                              : selectedDOB!.toIso8601String(),
                                          'status': selectedStatus,
                                        };
                                        if (photoUrl != null) {
                                          updatePayload['photo_url'] = photoUrl;
                                        }

                                        await Supabase.instance.client
                                            .from('pets')
                                            .update(updatePayload)
                                            .eq('pet_id', petId);

                                        // Compute audit changes diff
                                        final diffs = <String>[];
                                        if ((pet['name'] ?? '').toString().trim() != newName.trim()) {
                                          diffs.add('Name: "${pet['name']}" -> "$newName"');
                                        }
                                        if ((pet['species'] ?? '').toString().trim() != selectedSpecies.trim()) {
                                          diffs.add('Species: "${pet['species']}" -> "$selectedSpecies"');
                                        }
                                        final newBreed = breedCtrl.text.trim().isEmpty ? 'N/A' : breedCtrl.text.trim();
                                        if ((pet['breed'] ?? 'N/A').toString().trim() != newBreed) {
                                          diffs.add('Breed: "${pet['breed']}" -> "$newBreed"');
                                        }
                                        final newColor = colorCtrl.text.trim().isEmpty ? 'N/A' : colorCtrl.text.trim();
                                        if ((pet['color'] ?? 'N/A').toString().trim() != newColor) {
                                          diffs.add('Color: "${pet['color']}" -> "$newColor"');
                                        }
                                        final oldWeight = (pet['weight'] is num) ? (pet['weight'] as num).toDouble() : double.tryParse(pet['weight']?.toString() ?? '0') ?? 0.0;
                                        final parsedWeight = double.tryParse(weightCtrl.text.trim()) ?? 0.0;
                                        if ((oldWeight - parsedWeight).abs() > 0.001) {
                                          diffs.add('Weight: ${oldWeight}kg -> ${parsedWeight}kg');
                                        }
                                        final previousStatus = (pet['status'] ?? '').toString().toLowerCase();
                                        if (previousStatus != selectedStatus.toLowerCase()) {
                                          diffs.add('Status: $previousStatus -> $selectedStatus');
                                        }
                                        if (photoUrl != null) {
                                          diffs.add('Photo updated');
                                        }

                                        PetAuditService.instance.logPetModification(
                                          petId: petId,
                                          petName: newName,
                                          action: 'Profile Details Updated',
                                          changesSummary: diffs.isEmpty ? 'Profile details updated' : diffs.join('; '),
                                          modifiedByRole: 'Owner',
                                        );

                                        // If changed from lost to active, archive any open lost reports
                                        if (selectedStatus == 'active' &&
                                            previousStatus == 'lost') {
                                          await Supabase.instance.client
                                              .from('lost_reports')
                                              .update({'status': 'archived'})
                                              .eq('pet_id', petId)
                                              .eq('status', 'active');
                                        }

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          AppToast.success(context,
                                              '$newName profile updated successfully! ✨');
                                          _reloadPet();
                                        }
                                      } catch (err) {
                                        setModalState(() {
                                          isSubmitting = false;
                                          errorMessage =
                                              'Failed to save changes: $err';
                                        });
                                      }
                                    },
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded, size: 20),
                              label: Text(
                                isSubmitting
                                    ? 'Saving Changes...'
                                    : 'Save Profile Changes',
                                style: GoogleFonts.inter(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

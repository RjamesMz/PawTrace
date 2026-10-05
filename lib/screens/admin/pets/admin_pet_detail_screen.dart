import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';
import '../../../core/navigation_helpers.dart';
import '../../../services/alerts/alert_service.dart';
import '../../../services/audit/pet_audit_service.dart';
import '../../../widgets/admin/admin_content_wrapper.dart';
import '../../../widgets/admin/pet_location_map_dialog.dart';
import '../../../widgets/common/photo_placeholder.dart';
import '../../../widgets/admin/pets/admin_pet_detail_cards.dart';
import '../../../widgets/admin/pets/admin_pet_detail_dialogs.dart';
import '../../../widgets/admin/pets/admin_pet_detail_actions.dart';
import '../../../widgets/admin/pets/pet_audit_log_dialog.dart';

export '../../../widgets/admin/pets/admin_pet_detail_cards.dart';
export '../../../widgets/admin/pets/admin_pet_detail_dialogs.dart';
export '../../../widgets/admin/pets/admin_pet_detail_actions.dart';
export '../../../widgets/admin/pets/pet_audit_log_dialog.dart';

/// Admin Pet Detail screen – displays full pet details with admin actions
/// (Mark as Lost, Remove Pet). Receives a pet Map via constructor.
class AdminPetDetailScreen extends StatefulWidget {
  final Map<String, dynamic> pet;

  const AdminPetDetailScreen({super.key, required this.pet});

  @override
  State<AdminPetDetailScreen> createState() => _AdminPetDetailScreenState();
}

class _AdminPetDetailScreenState extends State<AdminPetDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Map<String, dynamic> pet;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    pet = Map<String, dynamic>.from(widget.pet);
    _fetchLatestPet();
  }

  Future<void> _fetchLatestPet() async {
    try {
      final petId = pet['pet_id'] ?? pet['id'];
      if (petId == null) return;
      final res = await _supabase
          .from('pets')
          .select('*, users(first_name, middle_name, surname, suffix, email, phone, barangay)')
          .eq('pet_id', petId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          pet = Map<String, dynamic>.from(res);
        });
      }
    } catch (_) {}
  }

  Future<void> _repostLostPetToNews() async {
    final petName = pet['name'] ?? 'Pet';
    final barangay =
        pet['barangay'] ?? pet['users']?['barangay'] ?? 'Catanduanes';

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

    setState(() => _isUpdating = true);
    try {
      final petId = pet['pet_id'] ?? pet['id'];
      final photoUrl = pet['photo_url'] ?? '';
      final species = pet['species'] ?? 'Pet';
      final breed = pet['breed'] ?? '';
      final color = pet['color'] ?? '';
      final u = pet['users'];
      final ownerName = u != null
          ? [u['first_name'], u['surname']]
              .where((s) => s != null && s.toString().isNotEmpty)
              .join(' ')
          : '';
      final ownerPhone = u?['phone'] ?? '';

      final summary = [
        '$species • $breed',
        if (color.toString().isNotEmpty) 'Color: $color',
        if (barangay.toString().isNotEmpty)
          'Registered Barangay: Brgy. $barangay',
        if (ownerName.isNotEmpty) 'Owner: $ownerName',
        if (ownerPhone.toString().isNotEmpty) 'Contact: $ownerPhone',
        'Please report any sightings or details to the owner or barangay authorities immediately.',
      ].join('\n');

      // 1. Mark pet as lost in pets table
      await _supabase
          .from('pets')
          .update({'status': 'lost'}).eq('pet_id', petId);

      // 2. Publish to news feed so it appears on home/news tab
      final postBarangay = (barangay.toString().trim().isNotEmpty)
          ? barangay.toString().trim()
          : 'Catanduanes';

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

      // 3. Dispatch notifications to ALL users across all barangays
      final alertedCount =
          await AlertService.instance.broadcastLostPetNewsAlert(
        petName: petName.toString(),
        barangay: barangay.toString(),
      );

      if (!mounted) return;
      setState(() => pet['status'] = 'lost');
      AppToast.success(
          context, '$petName posted to News! ($alertedCount users notified)');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Error broadcasting pet: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showContactDialog() {
    showAdminContactOwnerDialog(context, pet);
  }

  void _showEditArchiveReasonDialog() {
    showAdminEditArchiveReasonDialog(
      context,
      initialReason: pet['archive_reason']?.toString(),
      onSave: _updateArchiveReason,
    );
  }

  Future<void> _updateArchiveReason(String reason) async {
    setState(() => _isUpdating = true);
    try {
      final petId = pet['pet_id'] ?? pet['id'];
      await _supabase
          .from('pets')
          .update({'archive_reason': reason})
          .eq('pet_id', petId);
      setState(() {
        pet['archive_reason'] = reason;
      });
      PetAuditService.instance.logPetModification(
        petId: petId,
        petName: pet['name']?.toString() ?? 'Pet',
        action: 'Archive Reason Updated',
        changesSummary: 'Reason updated to: $reason',
        modifiedByRole: 'Admin',
      );
      if (mounted) {
        AppToast.success(context, 'Archive reason updated: $reason');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to update reason: $e');
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _showLocationDialog() async {
    showPetLocationMapDialog(context, pet);
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus =
        (pet['status'] ?? 'active').toString().toLowerCase();
    final photoUrl = pet['photo_url'] ?? '';
    final name = pet['name'] ?? 'Unknown';
    final breed = pet['breed'] ?? '';
    final species = pet['species'] ?? '';
    final dob = pet['date_of_birth'] ?? '-';
    final weight = pet['weight']?.toString() ?? '-';
    final color = pet['color'] ?? '-';
    final collarId = pet['gps_id'] ?? '-';
    final u = pet['users'];
    final ownerName = u != null
        ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']]
            .where((s) => s != null && s.toString().isNotEmpty)
            .join(' ')
        : 'Unknown';
    final ownerEmail = pet['users']?['email'] ?? '-';
    final ownerPhone = pet['users']?['phone'] ?? '-';

    // Format date of birth for display
    String dobDisplay = '-';
    if (dob != '-' && dob.toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(dob.toString());
        dobDisplay = '${dt.day} ${_monthName(dt.month)} ${dt.year}';
      } catch (_) {
        dobDisplay = dob.toString();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => handleSafeBack(context),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(name,
            style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primary),
            tooltip: 'View Modification Audit Logs',
            onPressed: () => showPetAuditLogDialog(context, pet),
          ),
        ],
      ),
      body: _isUpdating
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchLatestPet,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: AdminContentWrapper(
                  maxWidth: 960,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720 ||
                          MediaQuery.of(context).size.width >= 900;
                      if (isWide) {
                        return _buildWideDetailLayout(
                          photoUrl: photoUrl.toString(),
                          name: name,
                          breed: breed,
                          species: species,
                          status: rawStatus,
                          dobDisplay: dobDisplay,
                          weight: weight,
                          color: color,
                          collarId: collarId,
                          ownerName: ownerName,
                          ownerEmail: ownerEmail,
                          ownerPhone: ownerPhone,
                        );
                      }
                      return _buildNarrowDetailLayout(
                        photoUrl: photoUrl.toString(),
                        name: name,
                        breed: breed,
                        species: species,
                        status: rawStatus,
                        dobDisplay: dobDisplay,
                        weight: weight,
                        color: color,
                        collarId: collarId,
                        ownerName: ownerName,
                        ownerEmail: ownerEmail,
                        ownerPhone: ownerPhone,
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWideDetailLayout({
    required String photoUrl,
    required String name,
    required String breed,
    required String species,
    required String status,
    required String dobDisplay,
    required String weight,
    required String color,
    required String collarId,
    required String ownerName,
    required String ownerEmail,
    required String ownerPhone,
  }) {
    final barangay = pet['barangay']?.toString() ??
        pet['users']?['barangay']?.toString() ??
        '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Pet photo showcase + Profile Audit card
        SizedBox(
          width: 320,
          child: Column(
            children: [
              // Hero Photo Container with floating status badge
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 320,
                        height: 320,
                        child: photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const PhotoPlaceholder(iconSize: 64),
                              )
                            : const PhotoPlaceholder(iconSize: 64),
                      ),
                      // Top gradient for badge contrast
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 70,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.45),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Floating Status Badge in top right
                      Positioned(
                        top: 14,
                        right: 14,
                        child: AdminPetStatusBadge(rawStatus: status),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Profile Audit & History Card
              AdminPetAuditSummaryCard(
                pet: pet,
                onViewLogs: () => showPetAuditLogDialog(context, pet),
              ),
            ],
          ),
        ),
        const SizedBox(width: 28),

        // Right Column: Information, Metrics, Owner, Actions
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pet Name & Quick Category Chips
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _metaChip(
                              icon: Icons.pets,
                              label: species.isNotEmpty ? species : 'Pet',
                              color: AppColors.primary,
                            ),
                            if (breed.isNotEmpty && breed != 'N/A')
                              _metaChip(
                                icon: Icons.category_outlined,
                                label: breed,
                                color: const Color(0xFF64748B),
                              ),
                            if (barangay.isNotEmpty)
                              _metaChip(
                                icon: Icons.location_on_outlined,
                                label: 'Brgy. $barangay',
                                color: const Color(0xFF0D9488),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Physical Attributes Grid
              _sectionHeader(
                icon: Icons.tune_rounded,
                title: 'PHYSICAL ATTRIBUTES & IDENTIFICATION',
              ),
              const SizedBox(height: 10),
              AdminPetInfoGridCard(
                dobDisplay: dobDisplay,
                weight: weight,
                color: color,
                collarId: collarId,
              ),
              const SizedBox(height: 22),

              // Owner Info Card
              _sectionHeader(
                icon: Icons.person_outline_rounded,
                title: 'PET OWNER INFORMATION',
              ),
              const SizedBox(height: 10),
              AdminPetOwnerCard(
                ownerName: ownerName,
                ownerEmail: ownerEmail,
                ownerPhone: ownerPhone,
                barangay: barangay,
              ),
              const SizedBox(height: 26),

              // Action buttons
              AdminPetDetailActions(
                pet: pet,
                isUpdating: _isUpdating,
                onContactOwner: _showContactDialog,
                onViewMap: _showLocationDialog,
                onBroadcastLostPet: _repostLostPetToNews,
                onEditArchiveReason: _showEditArchiveReasonDialog,
                onViewAuditLogs: () => showPetAuditLogDialog(context, pet),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowDetailLayout({
    required String photoUrl,
    required String name,
    required String breed,
    required String species,
    required String status,
    required String dobDisplay,
    required String weight,
    required String color,
    required String collarId,
    required String ownerName,
    required String ownerEmail,
    required String ownerPhone,
  }) {
    final barangay = pet['barangay']?.toString() ??
        pet['users']?['barangay']?.toString() ??
        '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Mobile Hero Photo Showcase with Status Badge
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const PhotoPlaceholder(iconSize: 60),
                        )
                      : const PhotoPlaceholder(iconSize: 60),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: AdminPetStatusBadge(rawStatus: status),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Pet Name and Subtitle
        Text(
          name,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _metaChip(
              icon: Icons.pets,
              label: species.isNotEmpty ? species : 'Pet',
              color: AppColors.primary,
            ),
            if (breed.isNotEmpty && breed != 'N/A')
              _metaChip(
                icon: Icons.category_outlined,
                label: breed,
                color: const Color(0xFF64748B),
              ),
            if (barangay.isNotEmpty)
              _metaChip(
                icon: Icons.location_on_outlined,
                label: 'Brgy. $barangay',
                color: const Color(0xFF0D9488),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Physical Attributes Grid
        _sectionHeader(
          icon: Icons.tune_rounded,
          title: 'PHYSICAL ATTRIBUTES',
        ),
        const SizedBox(height: 10),
        AdminPetInfoGridCard(
          dobDisplay: dobDisplay,
          weight: weight,
          color: color,
          collarId: collarId,
        ),
        const SizedBox(height: 20),

        // Owner Info Card
        _sectionHeader(
          icon: Icons.person_outline_rounded,
          title: 'OWNER INFORMATION',
        ),
        const SizedBox(height: 10),
        AdminPetOwnerCard(
          ownerName: ownerName,
          ownerEmail: ownerEmail,
          ownerPhone: ownerPhone,
          barangay: barangay,
        ),
        const SizedBox(height: 20),

        // Profile Audit Card
        AdminPetAuditSummaryCard(
          pet: pet,
          onViewLogs: () => showPetAuditLogDialog(context, pet),
        ),
        const SizedBox(height: 24),

        // Actions
        AdminPetDetailActions(
          pet: pet,
          isUpdating: _isUpdating,
          onContactOwner: _showContactDialog,
          onViewMap: _showLocationDialog,
          onBroadcastLostPet: _repostLostPetToNews,
          onEditArchiveReason: _showEditArchiveReasonDialog,
          onViewAuditLogs: () => showPetAuditLogDialog(context, pet),
        ),
      ],
    );
  }

  Widget _sectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
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
    return months[month - 1];
  }
}

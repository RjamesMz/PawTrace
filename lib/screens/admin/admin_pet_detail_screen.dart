import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_toast.dart';
import '../../core/navigation_helpers.dart';
import '../../services/alert_service.dart';
import '../../widgets/admin_content_wrapper.dart';

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

  Widget _buildStatusBadge(String rawStatus) {
    final status = rawStatus.toLowerCase().trim();
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'archived':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'ARCHIVED';
        break;
      case 'lost':
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        label = 'LOST';
        break;
      case 'found':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = 'FOUND';
        break;
      case 'active':
      default:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = status.isNotEmpty ? status.toUpperCase() : 'ACTIVE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
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

  void _showEditArchiveReasonDialog() {
    String? selectedReason = pet['archive_reason']?.toString();
    final customCtrl = TextEditingController(
      text: (selectedReason != null &&
              !['Passed Away', 'Rehomed / Adopted', 'No longer in my care'].contains(selectedReason))
          ? selectedReason
          : '',
    );
    if (selectedReason != null &&
        !['Passed Away', 'Rehomed / Adopted', 'No longer in my care'].contains(selectedReason)) {
      selectedReason = 'Other';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final canSave = selectedReason != null &&
              (selectedReason != 'Other' || customCtrl.text.trim().isNotEmpty);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Set Archive Reason',
                    style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select the reason why this pet was archived:',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  ...['Passed Away', 'Rehomed / Adopted', 'No longer in my care', 'Other'].map((r) {
                    final isSel = selectedReason == r;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setDlgState(() => selectedReason = r),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSel ? AppColors.primary : Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isSel ? AppColors.primary : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 10),
                              Text(r,
                                  style: GoogleFonts.inter(
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customCtrl,
                      onChanged: (_) => setDlgState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Enter specific reason...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: !canSave
                    ? null
                    : () async {
                        final finalReason = selectedReason == 'Other'
                            ? customCtrl.text.trim()
                            : selectedReason!;
                        Navigator.pop(ctx);
                        await _updateArchiveReason(finalReason);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save Reason'),
              ),
            ],
          );
        },
      ),
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
    final petName = pet['name']?.toString() ?? 'Pet';
    String location = pet['barangay']?.toString() ??
        pet['users']?['barangay']?.toString() ??
        'Catanduanes';
    String note = '';

    try {
      final petId = pet['pet_id'] ?? pet['id'];
      if (petId != null) {
        final reports = await _supabase
            .from('lost_reports')
            .select('*')
            .eq('pet_id', petId)
            .order('reported_at', ascending: false)
            .limit(1);
        if (reports.isNotEmpty) {
          final r = reports.first;
          if (r['last_seen_address'] != null &&
              r['last_seen_address'].toString().isNotEmpty) {
            location = r['last_seen_address'].toString();
          } else if (r['barangay'] != null &&
              r['barangay'].toString().isNotEmpty) {
            location = r['barangay'].toString();
          }
          note = (r['description'] ?? r['notes'] ?? '').toString();
        }
      }
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.map_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text('Last Known Location',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pet: $petName',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location, style: GoogleFonts.inter()),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Notes: $note',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant)),
            ],
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
    final collarId = pet['collar_id'] ?? '-';
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
            icon: const Icon(Icons.edit, color: AppColors.primary),
            onPressed: () {
              // Edit functionality placeholder
            },
          ),
        ],
      ),
      body: _isUpdating
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: AdminContentWrapper(
                maxWidth: 800,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700 ||
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Pet photo 300px wide
        SizedBox(
          width: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 300,
              height: 300,
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                    )
                  : _photoPlaceholder(),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Right side: All pet details, info grid card, owner info, action buttons
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + breed + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.montserrat(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface)),
                        const SizedBox(height: 2),
                        Text('$breed • $species',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 20),

              // Info grid card
              _buildInfoGridCard(dobDisplay, weight, color, collarId),
              const SizedBox(height: 20),

              // Owner info section
              Text('OWNER INFORMATION',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 10),
              _buildOwnerCard(ownerName, ownerEmail, ownerPhone),
              const SizedBox(height: 24),

              // Action buttons
              _buildActionButtons(status),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: 200,
            child: photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(),
                  )
                : _photoPlaceholder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text('$breed • $species',
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            _buildStatusBadge(status),
          ],
        ),
        const SizedBox(height: 20),
        _buildInfoGridCard(dobDisplay, weight, color, collarId),
        const SizedBox(height: 20),
        Text('OWNER INFORMATION',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 10),
        _buildOwnerCard(ownerName, ownerEmail, ownerPhone),
        const SizedBox(height: 28),
        _buildActionButtons(status),
      ],
    );
  }

  Widget _buildInfoGridCard(
      String dobDisplay, String weight, String color, String collarId) {
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
                  child: _infoCell('Date of Birth', dobDisplay,
                      border: const Border(
                          right: BorderSide(
                              color: Color(0xFFDDC1AE), width: 0.5)))),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: _infoCell('Weight', '$weight kg'))),
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
                      child: _infoCell('Collar ID', collarId))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(
      String ownerName, String ownerEmail, String ownerPhone) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ownerRow(Icons.person, ownerName),
          const SizedBox(height: 10),
          _ownerRow(Icons.email_outlined, ownerEmail),
          const SizedBox(height: 10),
          _ownerRow(Icons.phone_outlined, ownerPhone),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    final rawStatus = status.toLowerCase().trim();
    final isLost = rawStatus == 'lost';
    final isArchived = rawStatus == 'archived';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _showContactDialog,
                  icon: const Icon(Icons.phone_in_talk_rounded,
                      size: 19, color: AppColors.primary),
                  label: Text(
                    'Contact Owner',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.06),
                    side: BorderSide(
                      color: AppColors.primary.withOpacity(0.22),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showLocationDialog,
                  icon: const Icon(Icons.location_on_rounded,
                      size: 19, color: Colors.white),
                  label: Text(
                    'View Map',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppColors.primary.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (isArchived) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.archive_outlined,
                    color: Color(0xFF475569),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Archived Pet Record',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ARCHIVED',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This pet has been removed by the owner and archived. Historical reports, telemetry, and biometrics remain safely preserved.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      if ((pet['archive_reason'] ?? pet['reason'] ?? '').toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF475569)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Reason: ${(pet['archive_reason'] ?? pet['reason'] ?? '').toString().trim()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _showEditArchiveReasonDialog,
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(
                          (pet['archive_reason'] ?? pet['reason'] ?? '').toString().trim().isNotEmpty
                              ? 'Change Archive Reason'
                              : 'Set Archive Reason',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isUpdating ? null : _repostLostPetToNews,
                child: Center(
                  child: _isUpdating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.campaign_rounded,
                                size: 22, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              isLost
                                  ? 'Repost to News & Notify All Users'
                                  : 'Broadcast to News & Notify All Users',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ],
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

  Widget _ownerRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurface)),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppColors.primaryContainer.withOpacity(0.2),
      child: const Center(
          child: Icon(Icons.pets, color: AppColors.primaryContainer, size: 60)),
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

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
  }

  Future<void> _repostLostPetToNews() async {
    final petName = pet['name'] ?? 'Pet';
    final barangay = pet['barangay'] ?? pet['users']?['barangay'] ?? 'Catanduanes';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text('Broadcast to News?',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'This will publish "$petName" directly as an urgent alert on the public News feed and notify all users across Catanduanes, regardless of their barangay.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Publish & Notify All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          ? [u['first_name'], u['surname']].where((s) => s != null && s.toString().isNotEmpty).join(' ')
          : '';
      final ownerPhone = u?['phone'] ?? '';

      final summary = [
        '$species • $breed',
        if (color.toString().isNotEmpty) 'Color: $color',
        if (barangay.toString().isNotEmpty) 'Registered Barangay: Brgy. $barangay',
        if (ownerName.isNotEmpty) 'Owner: $ownerName',
        if (ownerPhone.toString().isNotEmpty) 'Contact: $ownerPhone',
        'Please report any sightings or details to the owner or barangay authorities immediately.',
      ].join('\n');

      // 1. Mark pet as lost in pets table
      await _supabase.from('pets').update({'status': 'lost'}).eq('pet_id', petId);

      // 2. Publish to news feed so it appears on home/news tab
      await _supabase.from('news').insert({
        'category': 'Lost & Found',
        'title': '🚨 MISSING PET: $petName',
        'source': 'PawTrace Admin Alert',
        'summary': summary,
        'image_url': photoUrl,
        'accent_color': '#BA1A1A',
        'barangay': 'Catanduanes',
      });

      // 3. Dispatch notifications to ALL users across all barangays
      final alertedCount = await AlertService.instance.broadcastLostPetNewsAlert(
        petName: petName.toString(),
        barangay: barangay.toString(),
      );

      if (!mounted) return;
      setState(() => pet['status'] = 'lost');
      AppToast.success(context, '$petName posted to News! ($alertedCount users notified)');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Error broadcasting pet: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isLost = (pet['status'] ?? 'active').toString().toLowerCase() == 'lost';
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
        ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']].where((s) => s != null && s.toString().isNotEmpty).join(' ')
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
        title: Text(name, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                        isLost: isLost,
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
                      isLost: isLost,
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
    required bool isLost,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: isLost
                          ? AppColors.errorContainer
                          : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isLost ? 'LOST' : 'ACTIVE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isLost
                            ? AppColors.error
                            : const Color(0xFF065F46),
                      ),
                    ),
                  ),
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
              _buildActionButtons(isLost),
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
    required bool isLost,
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isLost
                    ? AppColors.errorContainer
                    : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isLost ? 'LOST' : 'ACTIVE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isLost
                      ? AppColors.error
                      : const Color(0xFF065F46),
                ),
              ),
            ),
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
        _buildActionButtons(isLost),
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
                          right:
                              BorderSide(color: Color(0xFFDDC1AE), width: 0.5)))),
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
                          right:
                              BorderSide(color: Color(0xFFDDC1AE), width: 0.5)))),
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

  Widget _buildActionButtons(bool isLost) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _repostLostPetToNews,
            icon: const Icon(Icons.campaign_rounded, size: 22),
            label: Text(
              isLost
                  ? 'Repost to News & Notify All Users'
                  : 'Broadcast to News & Notify All Users',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
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

  Widget _ownerRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppColors.primaryContainer.withOpacity(0.2),
      child: const Center(child: Icon(Icons.pets, color: AppColors.primaryContainer, size: 60)),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

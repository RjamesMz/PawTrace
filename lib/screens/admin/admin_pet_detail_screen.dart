import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/navigation_helpers.dart';
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

  Future<void> _markAsLost() async {
    setState(() => _isUpdating = true);
    try {
      final petId = pet['pet_id'] ?? pet['id'];
      await _supabase.from('pets').update({'status': 'lost'}).eq('pet_id', petId);
      if (!mounted) return;
      setState(() => pet['status'] = 'lost');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pet['name']} marked as lost', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _removePet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Pet', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to remove ${pet['name']}? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text('Remove', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      final petId = pet['pet_id'] ?? pet['id'];
      await _supabase.from('pets').delete().eq('pet_id', petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pet['name']} removed successfully', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.adminPets);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
            onPressed: isLost ? null : _markAsLost,
            icon: const Icon(Icons.warning_amber_rounded, size: 20),
            label: Text(isLost ? 'Already Marked as Lost' : 'Mark as Lost'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.surfaceContainerHigh,
              disabledForegroundColor: AppColors.onSurfaceVariant,
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
          child: OutlinedButton.icon(
            onPressed: _removePet,
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Remove Pet'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error, width: 2),
              foregroundColor: AppColors.error,
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/navigation_helpers.dart';

/// Report Lost Pet screen – form for reporting a pet as missing.
class ReportLostPetScreen extends StatefulWidget {
  const ReportLostPetScreen({super.key});

  @override
  State<ReportLostPetScreen> createState() => _ReportLostPetScreenState();
}

class _ReportLostPetScreenState extends State<ReportLostPetScreen> {
  final _colorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _species = 'Dog';
  bool _photoUploaded = false;
  Map<String, dynamic>? _pet;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pet == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _pet = args;
        _colorCtrl.text = _pet!['color'] ?? '';
        final sp = (_pet!['species'] ?? 'Dog').toString();
        if (sp.toLowerCase() == 'dog' || sp.toLowerCase() == 'cat') {
          _species = sp[0].toUpperCase() + sp.substring(1).toLowerCase();
        } else {
          _species = 'Dog';
        }
      }
    }
  }

  @override
  void dispose() {
    _colorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final pet = _pet;
    if (pet == null) return;

    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a last seen description.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final petId = pet['pet_id'];
      if (petId == null) throw Exception('Pet ID is missing.');

      // 1. Update status and color in 'pets' table
      await Supabase.instance.client.from('pets').update({
        'status': 'lost',
        'color': _colorCtrl.text.trim(),
      }).eq('pet_id', petId);

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final ownerId = currentUserId ?? pet['owner_id'];

      // 2. Insert lost report in 'lost_reports' table
      await Supabase.instance.client.from('lost_reports').insert({
        'pet_id': petId,
        'owner_id': ownerId,
        'last_seen_address': 'Calatagan, Batangas, Philippines',
        'barangay': pet['barangay'] ?? 'Santa Ana',
        'description': _descCtrl.text.trim(),
        'status': 'active',
        'reported_at': DateTime.now().toIso8601String(),
        'photo_url': pet['photo_url'] ?? '',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pet['name'] ?? 'Pet'} reported as lost!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhotoSection(),
                        const SizedBox(height: 24),
                        _buildForm(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isSaving ? null : _buildBottomBar(),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding:
          EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => handleSafeBack(context),
              color: AppColors.onSurfaceVariant),
          const Spacer(),
          Text('Report Lost Pet',
              style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface)),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    final petPhotoUrl = _pet?['photo_url'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('RECENT PHOTO'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _photoUploaded = !_photoUploaded),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.outlineVariant,
                  width: 1.5,
                  style: BorderStyle.none),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: (petPhotoUrl.isNotEmpty || _photoUploaded)
                ? Image.network(
                    petPhotoUrl.isNotEmpty
                        ? petPhotoUrl
                        : 'https://images.unsplash.com/photo-1558788353-f76d92427f16?w=600',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(),
                  )
                : _photoPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.add_a_photo_outlined,
          size: 48, color: AppColors.onSurfaceVariant),
      const SizedBox(height: 8),
      Text('Tap to upload recent photo',
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.onSurfaceVariant)),
    ]);
  }

  Widget _buildForm() {
    final petName = _pet?['name'] ?? 'Cooper';
    final petBreed = _pet?['breed'] ?? 'Golden Retriever';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pet name + breed (auto-filled)
        Row(
          children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('PET NAME'),
                    const SizedBox(height: 8),
                    _readonlyField(petName),
                  ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('BREED'),
                    const SizedBox(height: 8),
                    _readonlyField(petBreed),
                  ]),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Species
        _label('SPECIES'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _species,
          items: ['Dog', 'Cat']
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: GoogleFonts.inter(fontSize: 15))))
              .toList(),
          onChanged: (v) => setState(() => _species = v!),
          icon:
              const Icon(Icons.expand_more, color: AppColors.onSurfaceVariant),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
        ),
        const SizedBox(height: 18),

        // Color
        _label('COLOR / MARKINGS'),
        const SizedBox(height: 8),
        TextField(
          controller: _colorCtrl,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g. Cream coat, white patch on chest',
            hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.onSurfaceVariant.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 18),

        // Description
        _label('LAST SEEN DESCRIPTION'),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText:
                'Describe where they were last seen and any behavioral notes...',
            hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.onSurfaceVariant.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 18),

        // Map section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _label('LAST KNOWN LOCATION'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(999)),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    size: 14, color: Color(0xFF2E7D32)),
                const SizedBox(width: 4),
                Text('AUTO-DETECTED',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E7D32))),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Map placeholder
                Container(color: AppColors.surfaceContainerHigh),
                Image.network(
                  'https://maps.googleapis.com/maps/api/staticmap?center=34.0522,-118.2437&zoom=14&size=600x300',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFD0E8D0),
                    child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map_outlined,
                                size: 48, color: AppColors.primaryContainer),
                            const SizedBox(height: 8),
                            Text('Map Placeholder',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant)),
                          ]),
                    ),
                  ),
                ),
                // GPS pin with bounce
                Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(999)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.sensors,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('LIVE GPS COLLAR',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ]),
                        ),
                        const Icon(Icons.location_on,
                            size: 40, color: AppColors.primaryContainer),
                      ]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('Using precise collar coordinates from 2 minutes ago',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _readonlyField(String value) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.secondaryFixed.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(value,
          style: GoogleFonts.inter(
              fontSize: 15, color: AppColors.onSurfaceVariant)),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.onSurfaceVariant),
      );

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        border: Border(
            top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.15))),
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _submitReport,
          icon: const Icon(Icons.campaign_rounded, size: 20),
          label: const Text('SUBMIT REPORT'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            shadowColor: AppColors.primaryContainer.withOpacity(0.3),
            elevation: 8,
            textStyle: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

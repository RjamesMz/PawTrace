import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/app_toast.dart';
import 'lost_pet_screen.dart' show LostPetMapScreen;

class LostPetDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  const LostPetDetailScreen({super.key, required this.report});

  @override
  State<LostPetDetailScreen> createState() => _LostPetDetailScreenState();
}

class _LostPetDetailScreenState extends State<LostPetDetailScreen> {
  Map<String, dynamic>? _ownerData;
  bool _loadingOwner = false;
  bool _markingFound = false;

  String get _currentUserId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _resolveOwner();
  }

  Future<void> _resolveOwner() async {
    final embedded = widget.report['owner_id'];
    if (embedded is Map<String, dynamic>) {
      setState(() => _ownerData = embedded);
      return;
    }
    final ownerId = widget.report['owner_id']?.toString() ?? widget.report['user_id']?.toString();
    if (ownerId == null || ownerId.isEmpty) return;
    setState(() => _loadingOwner = true);
    try {
      final data = await Supabase.instance.client.from('users').select().eq('id', ownerId).maybeSingle();
      if (mounted) setState(() => _ownerData = data);
    } catch (e) {
      debugPrint('[PetTrace] owner fetch: $e');
    } finally {
      if (mounted) setState(() => _loadingOwner = false);
    }
  }

  Future<void> _markAsFound() async {
    final reportId = widget.report['report_id']?.toString();
    final petId = widget.report['pet_id']?.toString() ??
        (widget.report['pets'] is Map
            ? widget.report['pets']['pet_id']?.toString()
            : null);
    if (reportId == null) return;
    setState(() => _markingFound = true);
    try {
      await Supabase.instance.client.from('lost_reports').update({
        'status': 'archived',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('report_id', reportId);

      if (petId != null && petId.isNotEmpty) {
        await Supabase.instance.client
            .from('pets')
            .update({'status': 'active'})
            .eq('pet_id', petId);
      }

      if (mounted) {
        AppToast.show(context, 'Marked as found and archived!',
            icon: Icons.check_circle_outline,
            backgroundColor: const Color(0xFF22C55E));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed: $e',
            icon: Icons.error_outline, backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _markingFound = false);
    }
  }

  String _timeAgo(String? ts) {
    if (ts == null || ts.isEmpty) return 'Recently';
    try {
      final diff = DateTime.now().difference(DateTime.parse(ts));
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return 'Recently';
    }
  }

  String _ownerFullName() {
    if (_ownerData == null) return 'Unknown Owner';
    return [_ownerData!['first_name'], _ownerData!['middle_name'], _ownerData!['surname'], _ownerData!['suffix']]
        .where((s) => s != null && s.toString().trim().isNotEmpty)
        .join(' ');
  }

  String _ownerInitial() {
    final n = _ownerData?['first_name']?.toString() ?? '';
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  String _cleanAddress(String raw) {
    return raw.replaceAll(RegExp(r'\s*\(?Lat:\s*[-\d.]+,\s*Lng:\s*[-\d.]+\)?'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final petData = widget.report['pets'] as Map<String, dynamic>?;
    final petName = petData?['name'] as String? ?? 'Unknown Pet';
    final species = petData?['species'] as String? ?? '';
    final breed = petData?['breed'] as String? ?? '';
    final color = petData?['color'] as String? ?? '';
    final imageUrl = widget.report['photo_url'] as String? ?? petData?['photo_url'] as String? ?? '';
    final rawAddress = widget.report['last_seen_address'] as String? ?? widget.report['barangay'] as String? ?? 'Calatagan';
    final location = _cleanAddress(rawAddress);
    final description = widget.report['description'] as String? ?? '';
    final reportedAt = widget.report['reported_at'] as String?;
    final reportId = widget.report['report_id']?.toString() ?? '-';
    double? lat = (widget.report['last_seen_lat'] as num?)?.toDouble();
    double? lon = (widget.report['last_seen_lon'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      final m = RegExp(r'Lat:\s*([-\d.]+),\s*Lng:\s*([-\d.]+)').firstMatch(rawAddress);
      if (m != null) {
        lat = double.tryParse(m.group(1)!);
        lon = double.tryParse(m.group(2)!);
      }
    }
    final isOwner = _currentUserId.isNotEmpty &&
        (_currentUserId == widget.report['owner_id']?.toString() || _currentUserId == widget.report['user_id']?.toString());
    final ownerPhone = (_ownerData?['phone'] as String? ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 340,
                      width: double.infinity,
                      color: const Color(0xFF1A1A1A),
                      child: imageUrl.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(),
                                ),
                                BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                  child: Container(
                                    color: Colors.black.withOpacity(0.35),
                                  ),
                                ),
                                Center(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _placeholder(),
                                  ),
                                ),
                              ],
                            )
                          : _placeholder(),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          'LOST',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                petName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (species.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(species.toLowerCase() == 'dog' ? '🐶' : '🐱', style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 4),
                                    Text(
                                      species,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [if (breed.isNotEmpty) breed, if (color.isNotEmpty) color].join(' · '),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 18),
                        _label('LAST SEEN'),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                location,
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 16, color: AppColors.onSurfaceVariant.withOpacity(0.7)),
                            const SizedBox(width: 8),
                            Text(
                              _timeAgo(reportedAt),
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant.withOpacity(0.8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 18),
                        _label('DESCRIPTION'),
                        const SizedBox(height: 10),
                        description.isNotEmpty
                            ? Text(
                                description,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.onSurface,
                                  height: 1.55,
                                ),
                              )
                            : Text(
                                'No description provided.',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.onSurfaceVariant.withOpacity(0.55),
                                ),
                              ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 18),
                        _label('OWNER'),
                        const SizedBox(height: 12),
                        _loadingOwner
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            : Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.primary.withOpacity(0.15),
                                    child: Text(
                                      _ownerInitial(),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _ownerFullName(),
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.onSurface,
                                          ),
                                        ),
                                        if (ownerPhone.isNotEmpty)
                                          Text(
                                            ownerPhone,
                                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: ownerPhone.isNotEmpty
                                    ? () async {
                                        final uri = Uri.parse('tel:$ownerPhone');
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        } else {
                                          Clipboard.setData(ClipboardData(text: ownerPhone));
                                          if (context.mounted) {
                                            AppToast.show(context, 'Phone copied: $ownerPhone', icon: Icons.copy_rounded);
                                          }
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.call_rounded, size: 16),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Contact Owner',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (lat != null && lon != null)
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LostPetMapScreen(
                                              petName: petName,
                                              lat: lat!,
                                              lon: lon!,
                                              address: location,
                                            ),
                                          ),
                                        )
                                    : () => AppToast.show(context, 'No GPS coordinates available.', icon: Icons.location_off_rounded),
                                icon: const Icon(Icons.map_rounded, size: 16),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'View on Map',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isOwner) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _markingFound ? null : _markAsFound,
                              icon: _markingFound
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                                    )
                                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
                              label: Text(
                                _markingFound ? 'Updating…' : 'Mark as Found',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(color: AppColors.error.withOpacity(0.6)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'Report ID: $reportId',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant.withOpacity(0.4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.primary.withOpacity(0.1),
        child: const Center(
          child: Icon(Icons.pets_rounded, size: 80, color: AppColors.primary),
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      );
}

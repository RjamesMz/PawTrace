import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_toast.dart';
import '../../core/navigation_helpers.dart';
import '../../services/alert_service.dart';

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

  final MapController _mapController = MapController();
  double _lastLat = 13.9747; // Default Virac / Catanduanes coordinates
  double _lastLon = 124.2432;
  String? _lastRecordedAt;
  bool _hasCollarGps = false;
  bool _isLoadingGps = false;

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
        _fetchLastKnownLocation();
      }
    }
  }

  Future<void> _fetchLastKnownLocation() async {
    final collarId = _pet?['collar_id']?.toString();
    if (collarId == null ||
        collarId.isEmpty ||
        collarId.toUpperCase() == 'N/A') {
      return;
    }

    setState(() => _isLoadingGps = true);
    try {
      final data = await Supabase.instance.client
          .from('collar_locations')
          .select()
          .eq('collar_id', collarId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null && mounted) {
        final parsedLat = (data['lat'] as num?)?.toDouble();
        final parsedLon = (data['lon'] as num?)?.toDouble();
        if (parsedLat != null && parsedLon != null) {
          setState(() {
            _lastLat = parsedLat;
            _lastLon = parsedLon;
            _lastRecordedAt = data['recorded_at']?.toString();
            _hasCollarGps = true;
            _isLoadingGps = false;
          });
          _mapController.move(ll.LatLng(_lastLat, _lastLon), 16.0);
        } else {
          setState(() => _isLoadingGps = false);
        }
      } else if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    } catch (e) {
      debugPrint('[ReportLostPet] Error fetching collar location: $e');
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  String _formatLastPing(String? raw) {
    if (raw == null || raw.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return 'Recent';
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
      AppToast.error(context, 'Please enter a last seen description.');
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

      final barangay = pet['barangay']?.toString() ?? 'Santa Ana';
      final coordString =
          'Lat: ${_lastLat.toStringAsFixed(5)}, Lng: ${_lastLon.toStringAsFixed(5)}';
      final lastSeenAddress = '$barangay ($coordString)';

      // 2. Insert lost report in 'lost_reports' table
      final reportRes = await Supabase.instance.client
          .from('lost_reports')
          .insert({
            'pet_id': petId,
            'owner_id': ownerId,
            'last_seen_address': lastSeenAddress,
            'barangay': barangay,
            'description': _descCtrl.text.trim(),
            'status': 'active',
            'reported_at': DateTime.now().toIso8601String(),
            'photo_url': pet['photo_url'] ?? '',
          })
          .select('report_id')
          .maybeSingle();

      final reportId = reportRes?['report_id'];

      // 3. Dispatch in-app alerts to barangay admins and local users
      await AlertService.instance.createLostPetAlerts(
        lostReportId: reportId,
        petName: pet['name']?.toString() ?? 'A pet',
        barangay: pet['barangay']?.toString() ?? 'Santa Ana',
      );

      if (!mounted) return;

      AppToast.success(context, '${pet['name'] ?? 'Pet'} reported as lost!');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to submit report: $e');
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
        color: Colors.white,
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
                  color: _hasCollarGps
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999)),
              child: Row(children: [
                Icon(
                  _hasCollarGps ? Icons.check_circle : Icons.gps_fixed,
                  size: 14,
                  color: _hasCollarGps
                      ? const Color(0xFF2E7D32)
                      : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  _hasCollarGps
                      ? 'GPS COLLAR DETECTED'
                      : 'TAP MAP TO SET LOCATION',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _hasCollarGps
                        ? const Color(0xFF2E7D32)
                        : AppColors.primary,
                  ),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: ll.LatLng(_lastLat, _lastLon),
                    initialZoom: 15.5,
                    onTap: (_, point) {
                      setState(() {
                        _lastLat = point.latitude;
                        _lastLon = point.longitude;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pawtrace.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: ll.LatLng(_lastLat, _lastLon),
                          width: 140,
                          height: 70,
                          alignment: Alignment.center,
                          child: _buildPinMarker(petName),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isLoadingGps)
                  Container(
                    color: Colors.black.withOpacity(0.15),
                    child: const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Coords: ${_lastLat.toStringAsFixed(5)}, ${_lastLon.toStringAsFixed(5)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Text(
              _lastRecordedAt != null
                  ? 'Last ping: ${_formatLastPing(_lastRecordedAt)}'
                  : 'Tap map to adjust pin',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinMarker(String petName) {
    final photoUrl = _pet?['photo_url'] as String?;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            petName,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: photoUrl != null && photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.pets,
                      size: 18,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.pets,
                    size: 18,
                    color: Colors.white,
                  ),
          ),
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

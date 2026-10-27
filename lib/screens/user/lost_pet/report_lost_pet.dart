import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_toast.dart';
import '../../../core/navigation_helpers.dart';
import '../../../core/time_utils.dart';
import '../../../services/alerts/alert_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../../widgets/user/locate_pet/pet_geofence_layer.dart';

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
  bool _isGpsActive = false;
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
    final collarId = _pet?['gps_id']?.toString().trim();
    final bool hasPairedCollar = collarId != null &&
        collarId.isNotEmpty &&
        collarId.toUpperCase() != 'N/A' &&
        collarId.toUpperCase() != 'NONE';

    if (hasPairedCollar) {
      setState(() => _isLoadingGps = true);
      try {
        final data = await Supabase.instance.client
            .from('gps_locations')
            .select()
            .eq('gps_id', collarId)
            .order('recorded_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (data != null && mounted) {
          final parsedLat = (data['lat'] as num?)?.toDouble();
          final parsedLon = (data['lon'] as num?)?.toDouble();
          final rawRecordedAt = data['recorded_at']?.toString();

          bool active = data['is_online'] == true;
          if (rawRecordedAt != null && rawRecordedAt.isNotEmpty) {
            try {
              DateTime dt = DateTime.parse(rawRecordedAt);
              if (!rawRecordedAt.endsWith('Z') && !rawRecordedAt.contains('+')) {
                dt = DateTime.parse('${rawRecordedAt}Z');
              }
              final diff = DateTime.now().difference(dt.toLocal());
              if (!diff.isNegative && diff.inSeconds <= 180) {
                active = true;
              }
            } catch (_) {}
          }

          if (parsedLat != null && parsedLon != null) {
            setState(() {
              _lastLat = parsedLat;
              _lastLon = parsedLon;
              _lastRecordedAt = rawRecordedAt;
              _hasCollarGps = true;
              _isGpsActive = active;
              _isLoadingGps = false;
            });
            _mapController.move(ll.LatLng(_lastLat, _lastLon), 16.0);
            return;
          }
        }
      } catch (e) {
        debugPrint('[ReportLostPet] Error fetching collar location: $e');
      }
    }

    // Collar is unpaired OR collar had no telemetry:
    // Check if the pet has a retained last known location!
    double? retainedLat = (_pet?['last_seen_lat'] as num?)?.toDouble();
    double? retainedLon = (_pet?['last_seen_lon'] as num?)?.toDouble();
    String? retainedAt = _pet?['last_seen_at']?.toString();

    // If not in memory, query the 'pets' table or 'lost_reports' table for this pet
    if (retainedLat == null || retainedLon == null) {
      final petId = _pet?['pet_id'];
      if (petId != null) {
        try {
          final petDb = await Supabase.instance.client
              .from('pets')
              .select('last_seen_lat, last_seen_lon, last_seen_at')
              .eq('pet_id', petId)
              .maybeSingle();
          if (petDb != null) {
            retainedLat ??= (petDb['last_seen_lat'] as num?)?.toDouble();
            retainedLon ??= (petDb['last_seen_lon'] as num?)?.toDouble();
            retainedAt ??= petDb['last_seen_at']?.toString();
          }
        } catch (_) {}

        // Fallback: check previous reports for this pet
        if (retainedLat == null || retainedLon == null) {
          try {
            final prevRep = await Supabase.instance.client
                .from('lost_reports')
                .select('last_seen_lat, last_seen_lon, reported_at')
                .eq('pet_id', petId)
                .order('reported_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (prevRep != null) {
              retainedLat ??= (prevRep['last_seen_lat'] as num?)?.toDouble();
              retainedLon ??= (prevRep['last_seen_lon'] as num?)?.toDouble();
              retainedAt ??= prevRep['reported_at']?.toString();
            }
          } catch (_) {}
        }
      }
    }

    if (retainedLat != null && retainedLon != null && mounted) {
      setState(() {
        _lastLat = retainedLat!;
        _lastLon = retainedLon!;
        _lastRecordedAt = retainedAt;
        _hasCollarGps = true; // Pin and map WILL BE DISPLAYED!
        _isGpsActive = false; // Collar is unpaired, so NOT live active, reporting is permitted!
        _isLoadingGps = false;
      });
      _mapController.move(ll.LatLng(_lastLat, _lastLon), 16.0);
    } else if (mounted) {
      setState(() {
        _hasCollarGps = false;
        _isGpsActive = false;
        _isLoadingGps = false;
      });
    }
  }

  String _formatLastPing(String? raw) {
    if (raw == null || raw.isEmpty) return 'Recent';
    try {
      final dt = TimeUtils.parseTimestamp(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
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

    if (_hasCollarGps && _isGpsActive) {
      AppToast.error(
        context,
        'GPS is active. You cannot report as lost while the GPS collar is active.',
      );
      return;
    }

    final descErr = AuthService.validateText(
      _descCtrl.text,
      fieldName: 'Last seen description',
      minLength: 5,
      maxLength: 500,
    );
    if (descErr != null) {
      AppToast.error(context, descErr);
      return;
    }

    final colorVal = _colorCtrl.text.trim();
    if (colorVal.isNotEmpty && colorVal.length > 50) {
      AppToast.error(context, 'Color description cannot exceed 50 characters.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final petId = pet['pet_id'];
      if (petId == null) throw Exception('Pet ID is missing.');

      final barangay = pet['barangay']?.toString() ?? 'Santa Ana';
      final String addressWithCoords = _hasCollarGps
          ? '$barangay (Lat: ${_lastLat.toStringAsFixed(5)}, Lng: ${_lastLon.toStringAsFixed(5)})'
          : barangay;

      // 1. Update status and color in 'pets' table
      // Note: 'pets' table does not have last_seen_lat/lon/address/at columns.
      // Those coordinates belong to 'lost_reports' (inserted below).
      final petUpdateData = <String, dynamic>{
        'status': 'lost',
      };
      if (_colorCtrl.text.trim().isNotEmpty) {
        petUpdateData['color'] = _colorCtrl.text.trim();
      }
      await Supabase.instance.client
          .from('pets')
          .update(petUpdateData)
          .eq('pet_id', petId);

      // Sync in-memory pet map for calling screens
      pet['status'] = 'lost';
      if (_colorCtrl.text.trim().isNotEmpty) {
        pet['color'] = _colorCtrl.text.trim();
      }
      if (_hasCollarGps) {
        pet['last_seen_lat'] = _lastLat;
        pet['last_seen_lon'] = _lastLon;
        pet['last_seen_address'] = addressWithCoords;
        pet['last_seen_at'] =
            _lastRecordedAt ?? DateTime.now().toUtc().toIso8601String();
      }

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final ownerId = currentUserId ?? pet['owner_id'];

      // 2. Insert lost report in 'lost_reports' table
      final reportInsertData = <String, dynamic>{
        'pet_id': petId,
        'owner_id': ownerId,
        'last_seen_address': addressWithCoords,
        'barangay': barangay,
        'description': _descCtrl.text.trim(),
        'status': 'active',
        'reported_at': DateTime.now().toUtc().toIso8601String(),
        'photo_url': pet['photo_url'] ?? '',
      };
      if (_hasCollarGps) {
        reportInsertData['last_seen_lat'] = _lastLat;
        reportInsertData['last_seen_lon'] = _lastLon;
      }

      Map<String, dynamic>? reportRes;
      try {
        reportRes = await Supabase.instance.client
            .from('lost_reports')
            .insert(reportInsertData)
            .select('report_id')
            .maybeSingle();
      } catch (insertErr) {
        debugPrint('[ReportLostPet] First insert attempt failed: $insertErr');
        // Fallback without separate lat/lon fields in case schema differs
        final fallbackData = Map<String, dynamic>.from(reportInsertData)
          ..remove('last_seen_lat')
          ..remove('last_seen_lon');
        reportRes = await Supabase.instance.client
            .from('lost_reports')
            .insert(fallbackData)
            .select('report_id')
            .maybeSingle();
      }

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
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppConstants.buildLogoGraphic(size: 22),
                const SizedBox(width: 8),
                Text('Report Lost Pet',
                    style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface)),
              ],
            ),
          ),
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
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        petPhotoUrl.isNotEmpty
                            ? petPhotoUrl
                            : 'https://images.unsplash.com/photo-1558788353-f76d92427f16?w=600',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(color: Colors.black.withOpacity(0.3)),
                      ),
                      Center(
                        child: Image.network(
                          petPhotoUrl.isNotEmpty
                              ? petPhotoUrl
                              : 'https://images.unsplash.com/photo-1558788353-f76d92427f16?w=600',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _photoPlaceholder(),
                        ),
                      ),
                    ],
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
        // Pet name + species (auto-filled from registered pet)
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
                    _label('SPECIES'),
                    const SizedBox(height: 8),
                    _readonlyField(_species),
                  ]),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Breed (auto-filled)
        _label('BREED'),
        const SizedBox(height: 8),
        _readonlyField(petBreed),
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
        const SizedBox(height: 18), // Map / GPS section
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
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _hasCollarGps
                        ? const Color(0xFFA5D6A7)
                        : const Color(0xFFFECACA),
                  )),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasCollarGps ? Icons.check_circle : Icons.gps_off_rounded,
                    size: 13,
                    color: _hasCollarGps
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hasCollarGps ? 'GPS COLLAR DETECTED' : 'NO GPS CONNECTED',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _hasCollarGps
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingGps)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.3)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Checking for GPS collar connection...',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_hasCollarGps)
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.outlineVariant.withOpacity(0.3)),
                  ),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: ll.LatLng(_lastLat, _lastLon),
                      initialZoom: 15.5,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.pettrace.app',
                      ),
                      // Geofence & GPS Accuracy Tolerance Circle (±2.5m)
                      PetGeofenceLayer(
                        center: ll.LatLng(_lastLat, _lastLon),
                        isGpsActive: false,
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
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isGpsActive
                            ? Icons.my_location_rounded
                            : Icons.location_on_outlined,
                        size: 13,
                        color: const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isGpsActive
                            ? 'Live Location detected'
                            : 'Last known location',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  if (_lastRecordedAt != null)
                    Text(
                      'Last ping: ${_formatLastPing(_lastRecordedAt)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
              if (_hasCollarGps && _isGpsActive) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFECACA),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 22,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GPS is Active',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'The GPS collar for this pet is currently paired and active. You cannot file a lost pet report while live tracking is operational. Please track your pet on the map instead.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          )
        else
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.outlineVariant.withOpacity(0.35)),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.gps_off_rounded,
                              size: 26,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No GPS Connected',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This pet does not have an active GPS collar paired.\nLocation will be reported using the registered barangay.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Registered area: ${_pet?['barangay']?.toString() ?? 'San Andres, Catanduanes'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
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
      child: Text(
        value,
        style: GoogleFonts.inter(
            fontSize: 15, color: AppColors.onSurfaceVariant),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
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
    final isBlocked = _hasCollarGps && _isGpsActive;
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
          onPressed: isBlocked
              ? () {
                  AppToast.error(
                    context,
                    'GPS is active. You cannot report as lost while the GPS collar is active.',
                  );
                }
              : _submitReport,
          icon: Icon(
            isBlocked ? Icons.block_rounded : Icons.campaign_rounded,
            size: 20,
          ),
          label: Text(isBlocked ? 'GPS IS ACTIVE' : 'SUBMIT REPORT'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isBlocked
                ? const Color(0xFFDC2626)
                : AppColors.primaryContainer,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            shadowColor: (isBlocked
                    ? const Color(0xFFDC2626)
                    : AppColors.primaryContainer)
                .withOpacity(0.3),
            elevation: 8,
            textStyle: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

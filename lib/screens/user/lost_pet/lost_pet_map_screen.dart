import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/time_utils.dart';
import '../../../services/geo/active_lost_pet_pins_service.dart';
import '../../../services/geo/no_signal_mask_service.dart';
import '../../../services/geo/reverse_geocode_service.dart';
import '../../../widgets/user/locate_pet/pet_geofence_layer.dart';
import '../../../widgets/user/lost_pet/lost_pet_marker_widget.dart';
import 'lost_pet_detail_screen.dart';

/// Interactive Map Screen for viewing a lost pet's location alongside other active lost pets.
class LostPetMapScreen extends StatefulWidget {
  final String petName;
  final double lat;
  final double lon;
  final String address;
  final String locationSource;
  final String? recordedAt;
  final String? photoUrl;
  final String? reportId;
  final Map<String, dynamic>? rawReport;

  const LostPetMapScreen({
    super.key,
    required this.petName,
    required this.lat,
    required this.lon,
    required this.address,
    this.locationSource = 'Reported Location',
    this.recordedAt,
    this.photoUrl,
    this.reportId,
    this.rawReport,
  });

  @override
  State<LostPetMapScreen> createState() => _LostPetMapScreenState();
}

class _LostPetMapScreenState extends State<LostPetMapScreen> {
  final MapController _mapController = MapController();

  // Active pet details currently selected/focused on the map
  late String _activePetName;
  late double _activeLat;
  late double _activeLon;
  late String _activeAddress;
  late String _activeLocationSource;
  late String? _activeRecordedAt;
  String? _activePhotoUrl;
  String? _activeReportId;
  Map<String, dynamic>? _activeRawReport;

  String? _detectedAddress;
  bool _isResolving = true;
  bool _showCard = true;

  List<LostPetPin> _allPins = const [];
  bool _isLoadingAllPins = true;

  @override
  void initState() {
    super.initState();
    ReverseGeocodeService.clearCache();
    _activePetName = widget.petName;
    _activeLat = widget.lat;
    _activeLon = widget.lon;
    _activeAddress = widget.address;
    _activeLocationSource = widget.locationSource;
    _activeRecordedAt = widget.recordedAt;
    _activePhotoUrl = widget.photoUrl;
    _activeReportId = widget.reportId;
    _activeRawReport = widget.rawReport;

    _resolveAddress(_activeLat, _activeLon);
    _loadAllActivePins();
    _ensurePetPhoto();
  }

  Future<void> _ensurePetPhoto() async {
    if (_activePhotoUrl != null && _activePhotoUrl!.trim().isNotEmpty) return;
    try {
      final petRow = await Supabase.instance.client
          .from('pets')
          .select('photo_url')
          .eq('name', widget.petName)
          .maybeSingle();
      final photo = petRow?['photo_url']?.toString();
      if (photo != null && photo.isNotEmpty && mounted) {
        setState(() => _activePhotoUrl = photo);
      }
    } catch (_) {}
  }

  Future<void> _loadAllActivePins() async {
    try {
      final pins = await ActiveLostPetPinsService.fetch();
      if (!mounted) return;
      setState(() {
        _allPins = pins;
        _isLoadingAllPins = false;
        // If initial photo was missing, see if active pin has it
        final match = pins.where((p) => p.petName == _activePetName);
        if (match.isNotEmpty) {
          if (_activePhotoUrl == null || _activePhotoUrl!.isEmpty) {
            _activePhotoUrl = match.first.photoUrl;
          }
          _activeReportId ??= match.first.reportId;
          _activeRawReport ??= match.first.rawReport;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAllPins = false);
      }
    }
  }

  Future<void> _resolveAddress(double lat, double lon) async {
    setState(() => _isResolving = true);
    final res = await ReverseGeocodeService.reverseGeocode(lat, lon);
    if (mounted) {
      setState(() {
        _detectedAddress = res;
        _isResolving = false;
      });
    }
  }

  void _selectPin(LostPetPin pin) {
    setState(() {
      _activePetName = pin.petName;
      _activeLat = pin.lat;
      _activeLon = pin.lon;
      _activeAddress = pin.address ?? '';
      _activeLocationSource = pin.sourceLabel ?? 'Reported Location';
      _activeRecordedAt = pin.recordedAt;
      _activePhotoUrl = pin.photoUrl;
      _activeReportId = pin.reportId;
      _activeRawReport = pin.rawReport;
      _detectedAddress = null;
      _showCard = true;
    });
    _mapController.move(ll.LatLng(pin.lat, pin.lon), 16.0);
    _resolveAddress(pin.lat, pin.lon);
  }

  Future<void> _openReportDetails() async {
    if (_activeRawReport != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LostPetDetailScreen(report: _activeRawReport!),
        ),
      );
      return;
    }

    final id = _activeReportId;
    if (id != null && id.isNotEmpty) {
      try {
        final data = await Supabase.instance.client
            .from('lost_reports')
            .select('*, pets(*)')
            .eq('report_id', id)
            .maybeSingle();
        if (data != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LostPetDetailScreen(report: data),
            ),
          );
        }
      } catch (e) {
        debugPrint('[LostPetMapScreen] Error opening report details: $e');
      }
    }
  }

  void _recenterToActive() {
    setState(() => _showCard = true);
    _mapController.move(ll.LatLng(_activeLat, _activeLon), 16.0);
  }

  void _fitAllPins() {
    final points = <ll.LatLng>[ll.LatLng(widget.lat, widget.lon)];
    for (final p in _allPins) {
      points.add(ll.LatLng(p.lat, p.lon));
    }
    if (points.length == 1) {
      _mapController.move(points.first, 16.0);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
        maxZoom: 16.0,
      ),
    );
  }

  String get _displayTitle {
    if (_detectedAddress != null && _detectedAddress!.isNotEmpty) {
      return _detectedAddress!;
    }
    if (_isResolving) {
      return 'Resolving pin location...';
    }
    if (_activeAddress.trim().isNotEmpty) {
      var cleaned = _activeAddress
          .replaceAll(RegExp(r'\s*\(?Lat:\s*[-\d.]+,\s*(?:Lng|Lon):\s*[-\d.]+\)?'), '')
          .trim();
      if (cleaned.contains('San Isidro Village')) {
        cleaned = 'Catanduanes State University, Brgy. Calatagan, Virac';
      }
      if (cleaned.isNotEmpty) return cleaned;
    }
    return 'Pin Location';
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // Other reported lost pets (amber avatars)
    for (final p in _allPins) {
      final isSelected = (p.lat - _activeLat).abs() < 0.00005 &&
          (p.lon - _activeLon).abs() < 0.00005;
      if (isSelected) continue;

      markers.add(
        Marker(
          point: ll.LatLng(p.lat, p.lon),
          width: 140,
          height: 80,
          alignment: Alignment.center,
          child: LostPetMarkerWidget(
            petName: p.petName,
            photoUrl: p.photoUrl,
            isSelected: false,
            onTap: () => _selectPin(p),
          ),
        ),
      );
    }

    // Active / Selected Pet Marker (prominent red avatar)
    markers.add(
      Marker(
        point: ll.LatLng(_activeLat, _activeLon),
        width: 140,
        height: 80,
        alignment: Alignment.center,
        child: LostPetMarkerWidget(
          petName: _activePetName,
          photoUrl: _activePhotoUrl,
          isSelected: true,
          onTap: _recenterToActive,
        ),
      ),
    );

    final totalPinsCount = markers.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Last Known Location',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        actions: [
          if (totalPinsCount > 1)
            IconButton(
              icon: const Icon(Icons.zoom_out_map_rounded),
              tooltip: 'Fit all pins ($totalPinsCount reported)',
              onPressed: _fitAllPins,
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: ll.LatLng(widget.lat, widget.lon),
              initialZoom: 16.0,
              onTap: (_, __) {
                if (_showCard) {
                  setState(() => _showCard = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pettrace.app',
              ),
              if (NoSignalMaskService.instance.isLoaded)
                PolygonLayer(
                  polygons: NoSignalMaskService.instance.polygons,
                ),
              // GPS Margin of Error Accuracy Circle (±2.5m)
              PetGeofenceLayer(
                center: ll.LatLng(_activeLat, _activeLon),
                isGpsActive: _activeLocationSource.contains('Live') ||
                    _activeLocationSource.contains('Collar'),
                showGeofence: false,
                marginOfErrorRadius: 5.0,
                customColor: const Color(0xFF64748B),
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // Total Lost Pets active pill (if multiple pins)
          if (!_isLoadingAllPins && totalPinsCount > 1)
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: _fitAllPins,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pets_rounded,
                        size: 14,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$totalPinsCount Lost Pets on Map',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Action Buttons (Recenter / Fit All)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            bottom: _showCard ? 124 : 30,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (totalPinsCount > 1) ...[
                  FloatingActionButton.small(
                    heroTag: 'lost_pet_fit_all_fab',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 4,
                    tooltip: 'Show all pins',
                    onPressed: _fitAllPins,
                    child: const Icon(Icons.zoom_out_map_rounded, size: 20),
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton.small(
                  heroTag: 'lost_pet_recenter_fab',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                  tooltip: 'Recenter to $_activePetName',
                  onPressed: _recenterToActive,
                  child: const Icon(Icons.my_location_rounded, size: 20),
                ),
              ],
            ),
          ),

          // Bottom Location Card
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            bottom: _showCard ? 30 : -220,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showCard ? 1.0 : 0.0,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.08),
                child: InkWell(
                  onTap: _openReportDetails,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.error, width: 2),
                          ),
                          child: ClipOval(
                            child: _activePhotoUrl != null &&
                                    _activePhotoUrl!.trim().isNotEmpty
                                ? Image.network(
                                    _activePhotoUrl!.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.pets_rounded,
                                      color: AppColors.error,
                                      size: 24,
                                    ),
                                  )
                                : const Icon(
                                    Icons.pets_rounded,
                                    color: AppColors.error,
                                    size: 24,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _activeLocationSource.contains('Live')
                                          ? const Color(0xFF16A34A)
                                          : (_activeLocationSource.contains('Collar')
                                              ? const Color(0xFFD97706)
                                              : AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$_activePetName · $_activeLocationSource',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _activeRecordedAt != null && _activeRecordedAt!.isNotEmpty
                                    ? 'Recorded ${TimeUtils.formatTimeAgo(_activeRecordedAt!)}'
                                    : 'Reported Location',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant.withOpacity(0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.onSurfaceVariant,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ),
        ),
        ],
      ),
    );
  }
}

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
import '../../../widgets/admin/reports/admin_report_card.dart';
import '../../../widgets/user/locate_pet/pet_geofence_layer.dart';
import '../../../widgets/user/lost_pet/lost_pet_marker_widget.dart';

/// Map showing all active lost pet reports across the area.
class AllLostPetsMapScreen extends StatefulWidget {
  final String? barangay;
  const AllLostPetsMapScreen({super.key, this.barangay});

  @override
  State<AllLostPetsMapScreen> createState() => _AllLostPetsMapScreenState();
}

class _AllLostPetsMapScreenState extends State<AllLostPetsMapScreen> {
  static const _defaultCenter = ll.LatLng(13.5938, 124.2381);
  final MapController _mapController = MapController();

  List<LostPetPin> _pins = const [];
  bool _isLoading = true;

  LostPetPin? _selectedPin;
  String? _detectedAddress;
  bool _isResolving = false;
  bool _showCard = true;

  @override
  void initState() {
    super.initState();
    ReverseGeocodeService.clearCache();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final pins = await ActiveLostPetPinsService.fetch(barangay: widget.barangay);
    if (!mounted) return;
    setState(() {
      _pins = pins;
      _isLoading = false;
      if (pins.isNotEmpty) {
        _selectedPin = pins.first;
        _showCard = true;
        _resolveAddress(pins.first.lat, pins.first.lon);
      }
    });
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

  void _selectPin(LostPetPin p) {
    setState(() {
      _selectedPin = p;
      _detectedAddress = null;
      _showCard = true;
    });
    _mapController.move(ll.LatLng(p.lat, p.lon), 16.0);
    _resolveAddress(p.lat, p.lon);
  }

  Future<void> _openReportDetails() async {
    final pin = _selectedPin;
    if (pin == null) return;

    Map<String, dynamic>? fullReport = pin.rawReport != null
        ? Map<String, dynamic>.from(pin.rawReport!)
        : null;

    if (fullReport == null || fullReport['owner_id'] is! Map<String, dynamic>) {
      if (pin.reportId != null && pin.reportId!.isNotEmpty) {
        try {
          final data = await Supabase.instance.client
              .from('lost_reports')
              .select('*, pets(*), owner_id(*)')
              .eq('report_id', pin.reportId!)
              .maybeSingle();
          if (data != null) {
            fullReport = Map<String, dynamic>.from(data);
          }
        } catch (e) {
          debugPrint('[AllLostPetsMapScreen] Error fetching report details: $e');
        }
      }
    }

    if (fullReport == null || !mounted) return;

    // Show the Web View dialog (matching the admin side web report card)
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: SingleChildScrollView(
            child: AdminReportCard(
              report: fullReport!,
              isDialog: true,
              onClose: () => Navigator.pop(ctx),
              onViewMap: () {
                Navigator.pop(ctx);
                _selectPin(pin);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _fitAllPins() {
    if (_pins.isEmpty) return;
    if (_pins.length == 1) {
      _mapController.move(ll.LatLng(_pins.first.lat, _pins.first.lon), 16.0);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _pins.map((p) => ll.LatLng(p.lat, p.lon)).toList(),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
        maxZoom: 16.0,
      ),
    );
  }

  MapOptions _options() {
    if (_pins.isEmpty) {
      return MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 10,
        onTap: (_, __) {
          if (_showCard) {
            setState(() => _showCard = false);
          }
        },
      );
    }
    return MapOptions(
      initialCameraFit: CameraFit.coordinates(
        coordinates: _pins.map((p) => ll.LatLng(p.lat, p.lon)).toList(),
        padding: const EdgeInsets.all(64),
        maxZoom: 16,
      ),
      onTap: (_, __) {
        if (_showCard) {
          setState(() => _showCard = false);
        }
      },
    );
  }

  String get _displayTitle {
    if (_detectedAddress != null && _detectedAddress!.isNotEmpty) {
      return _detectedAddress!;
    }
    if (_isResolving) {
      return 'Resolving location...';
    }
    if (_selectedPin?.address != null && _selectedPin!.address!.isNotEmpty) {
      var cleaned = _selectedPin!.address!
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
    final hasCard = _selectedPin != null && _showCard;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          widget.barangay != null && widget.barangay!.isNotEmpty
              ? 'Active Lost Pets · Brgy. ${widget.barangay} (${_pins.length})'
              : 'Active Lost Pets (${_pins.length})',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        actions: [
          if (_pins.length > 1)
            IconButton(
              icon: const Icon(Icons.zoom_out_map_rounded),
              tooltip: 'Fit all pins',
              onPressed: _fitAllPins,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh pins',
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: _options(),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pettrace.app',
                    ),
                    if (NoSignalMaskService.instance.isLoaded)
                      PolygonLayer(
                          polygons: NoSignalMaskService.instance.polygons),
                    if (_selectedPin != null)
                      PetGeofenceLayer(
                        center:
                            ll.LatLng(_selectedPin!.lat, _selectedPin!.lon),
                        isGpsActive: _selectedPin!.sourceLabel?.contains('Live') == true,
                        showGeofence: false,
                        marginOfErrorRadius: 5.0,
                        customColor: const Color(0xFF64748B),
                      ),
                    MarkerLayer(
                      markers: [
                        for (final p in _pins)
                          Marker(
                            point: ll.LatLng(p.lat, p.lon),
                            width: 140,
                            height: 80,
                            alignment: Alignment.center,
                            child: LostPetMarkerWidget(
                              petName: p.petName,
                              photoUrl: p.photoUrl,
                              isSelected: _selectedPin == p,
                              onTap: () => _selectPin(p),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Empty state overlay
                if (_pins.isEmpty)
                  Positioned(
                    top: 24,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'No active lost pets reported currently.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Recenter FAB
                if (_selectedPin != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    bottom: hasCard ? 124 : 30,
                    right: 20,
                    child: FloatingActionButton.small(
                      heroTag: 'all_lost_pets_recenter_fab',
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 4,
                      tooltip: 'Center on ${_selectedPin!.petName}',
                      onPressed: () {
                        setState(() => _showCard = true);
                        _mapController.move(
                          ll.LatLng(_selectedPin!.lat, _selectedPin!.lon),
                          16.0,
                        );
                      },
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                  ),

                // Selected Pet Detail Card
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  bottom: hasCard ? 30 : -220,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: hasCard ? 1.0 : 0.0,
                        child: _selectedPin == null
                            ? const SizedBox()
                            : Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                elevation: 6,
                                shadowColor: Colors.black.withOpacity(0.12),
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
                                            border: Border.all(
                                                color: AppColors.error, width: 2),
                                          ),
                                          child: ClipOval(
                                            child: _selectedPin!.photoUrl != null &&
                                                    _selectedPin!.photoUrl!.trim().isNotEmpty
                                                ? Image.network(
                                                    _selectedPin!.photoUrl!.trim(),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                        const Icon(
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: _selectedPin!.sourceLabel
                                                                  ?.contains('Live') ==
                                                              true
                                                          ? const Color(0xFF16A34A)
                                                          : const Color(0xFFD97706),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      '${_selectedPin!.petName} · ${_selectedPin!.sourceLabel ?? 'Reported Location'}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors
                                                            .onSurfaceVariant,
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
                                                _selectedPin!.recordedAt != null && _selectedPin!.recordedAt!.isNotEmpty
                                                    ? 'Recorded ${TimeUtils.formatTimeAgo(_selectedPin!.recordedAt!)}'
                                                    : 'Reported Location',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: AppColors.onSurfaceVariant
                                                      .withOpacity(0.75),
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
                  ),
                ),
              ],
            ),
    );
  }
}

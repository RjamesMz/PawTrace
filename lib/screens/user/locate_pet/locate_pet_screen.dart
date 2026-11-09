import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_toast.dart';
import '../../../services/geo/no_signal_mask_service.dart';
import '../../../services/geo/pet_tracking_history_service.dart';
import '../../../widgets/user/pair_collar_dialog.dart';
import '../../../widgets/user/locate_pet/pet_marker_widget.dart';
import '../../../widgets/user/locate_pet/locate_pet_top_controls.dart';
import '../../../widgets/user/locate_pet/locate_pet_bottom_card.dart';
import '../../../widgets/user/locate_pet/locate_pet_empty_view.dart';
import '../../../widgets/user/locate_pet/pet_geofence_layer.dart';
import '../../../widgets/user/locate_pet/locate_pet_history_panel.dart';

export '../../../widgets/user/locate_pet/pet_marker_widget.dart';
export '../../../widgets/user/locate_pet/locate_pet_top_controls.dart';
export '../../../widgets/user/locate_pet/locate_pet_bottom_card.dart';
export '../../../widgets/user/locate_pet/locate_pet_empty_view.dart';
export '../../../widgets/user/locate_pet/pet_geofence_layer.dart';
export '../../../widgets/user/locate_pet/locate_pet_history_panel.dart';

class LocatePetScreen extends StatefulWidget {
  final Map<String, dynamic> pet;
  const LocatePetScreen({super.key, required this.pet});

  @override
  State<LocatePetScreen> createState() => _LocatePetScreenState();
}

class _LocatePetScreenState extends State<LocatePetScreen> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  StreamSubscription? _locationSub;
  Timer? _statusTimer;

  String? currentCollarId;
  double? lat;
  double? lon;
  bool isOnline = false;
  int battery = 0;
  String lastUpdated = '';
  bool isLoading = true;
  bool _isCardMinimized = false;

  // ── History Mode State ──
  bool isHistoryMode = false;
  bool _isHistoryMinimized = false;
  DateTime selectedHistoryDate = DateTime.now();
  PetDailyTrack? dailyTrack;
  bool isLoadingHistory = false;
  PetTrackSegment? selectedSegment;

  /// Returns true if the collar has sent a GPS ping within the last 3 minutes (180 seconds).
  /// Online/Offline status is determined purely by last_seen staleness, not by a hardcoded boolean.
  bool get isGpsActive {
    final hasCollar = currentCollarId != null && currentCollarId!.isNotEmpty;
    if (!hasCollar || lastUpdated.isEmpty || lat == null) return false;
    try {
      DateTime dt = DateTime.parse(lastUpdated);
      if (!lastUpdated.endsWith('Z') && !lastUpdated.contains('+')) {
        dt = DateTime.parse('${lastUpdated}Z');
      }
      final diff = DateTime.now().toUtc().difference(dt.toUtc());
      return !diff.isNegative && diff.inSeconds <= 180;
    } catch (_) {
      return false;
    }
  }

  int _parseBattery(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    battery = 0;
    NoSignalMaskService.instance.loadMask().then((_) {
      if (mounted) setState(() {});
    });

    currentCollarId = widget.pet['gps_id'] as String?;
    if (currentCollarId != null && currentCollarId!.isNotEmpty) {
      loadCollarLocation();
      listenToCollarUpdates();
    } else {
      // Pet has no active collar, but check if it has a retained last known location!
      final pLat = (widget.pet['last_seen_lat'] as num?)?.toDouble();
      final pLon = (widget.pet['last_seen_lon'] as num?)?.toDouble();
      if (pLat != null && pLon != null) {
        lat = pLat;
        lon = pLon;
        lastUpdated = widget.pet['last_seen_at']?.toString() ?? '';
        isOnline = false;
        battery = 0;
        isLoading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && lat != null && lon != null) {
            _mapController.move(ll.LatLng(lat!, lon!), 16.0);
          }
        });
      } else {
        isLoading = false;
      }
    }

    // Refresh every 5 seconds to automatically recalculate time-ago and offline status quickly
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  // One time fetch
  Future<void> loadCollarLocation() async {
    final collarId = currentCollarId;
    if (collarId == null || collarId.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final data = await supabase
          .from('gps_locations')
          .select()
          .eq('gps_id', collarId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        setState(() {
          lat = (data['lat'] as num).toDouble();
          lon = (data['lon'] as num).toDouble();
          isOnline = data['is_online'] ?? false;
          battery = _parseBattery(data['battery_level'] ?? data['battery']);
          lastUpdated = data['recorded_at'] ?? '';
          isLoading = false;
        });
        if (!isHistoryMode) {
          _mapController.move(ll.LatLng(lat!, lon!), 16.0);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Real time listener
  void listenToCollarUpdates() {
    final collarId = currentCollarId;
    if (collarId == null || collarId.isEmpty) return;

    _locationSub?.cancel();
    _locationSub = supabase
        .from('gps_locations')
        .stream(primaryKey: ['location_id'])
        .eq('gps_id', collarId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .listen((data) {
          if (!mounted || data.isEmpty) return;
          final latest = data.first;
          setState(() {
            lat = (latest['lat'] as num).toDouble();
            lon = (latest['lon'] as num).toDouble();
            isOnline = latest['is_online'] ?? false;
            battery = _parseBattery(latest['battery_level'] ?? latest['battery']);
            lastUpdated = latest['recorded_at'] ?? '';
          });

          // Only auto-move to live coordinates if currently in Live Mode
          if (!isHistoryMode && lat != null && lon != null) {
            _mapController.move(ll.LatLng(lat!, lon!), 16.0);
          }
        }, onError: (err) {
          debugPrint('[LocatePetScreen] Stream error: $err');
        });
  }

  Future<void> _loadHistoryTrack({DateTime? date}) async {
    final targetDate = date ?? selectedHistoryDate;
    setState(() {
      selectedHistoryDate = targetDate;
      isLoadingHistory = true;
      selectedSegment = null;
    });

    final track = await PetTrackingHistoryService.instance.fetchDailyTrack(
      collarId: currentCollarId ?? '',
      date: targetDate,
      fallbackLat: lat,
      fallbackLon: lon,
    );

    if (!mounted) return;

    setState(() {
      dailyTrack = track;
      isLoadingHistory = false;
    });

    // Fit camera to the route path
    if (track.points.length > 1) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: track.points,
          padding: const EdgeInsets.only(top: 80, bottom: 320, left: 40, right: 40),
        ),
      );
    } else if (track.points.isNotEmpty) {
      _mapController.move(track.points.first, 16.0);
    }
  }

  void _toggleHistoryMode() {
    setState(() {
      isHistoryMode = !isHistoryMode;
    });

    if (isHistoryMode) {
      if (dailyTrack == null || !DateUtils.isSameDay(dailyTrack!.date, selectedHistoryDate)) {
        _loadHistoryTrack();
      } else if (dailyTrack!.points.length > 1) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: dailyTrack!.points,
            padding: const EdgeInsets.only(top: 80, bottom: 320, left: 40, right: 40),
          ),
        );
      }
    } else {
      // Switching back to Live Tracking
      if (lat != null && lon != null) {
        _mapController.move(ll.LatLng(lat!, lon!), 16.0);
      }
    }
  }

  Future<void> _handleManageCollar() async {
    final petCopy = Map<String, dynamic>.from(widget.pet);
    petCopy['gps_id'] = currentCollarId;
    final result = await showPairCollarDialog(context: context, pet: petCopy);
    if (result == null) return;

    _locationSub?.cancel();
    _locationSub = null;

    if (result == '__unpaired__') {
      setState(() {
        currentCollarId = null;
        widget.pet['gps_id'] = null;
        // RETAIN last known location so the pin is NOT removed!
        if (lat != null && lon != null) {
          widget.pet['last_seen_lat'] = lat;
          widget.pet['last_seen_lon'] = lon;
        }
        isOnline = false;
        battery = 0;
        isLoading = false;
        dailyTrack = null;
      });
      if (mounted) {
        AppToast.show(
          context,
          'Collar unpaired. Last known location retained.',
          icon: Icons.link_off_rounded,
        );
      }
    } else {
      setState(() {
        currentCollarId = result;
        widget.pet['gps_id'] = result;
        widget.pet['last_seen_address'] = null;
        widget.pet['last_seen_lat'] = null;
        widget.pet['last_seen_lon'] = null;
        widget.pet['last_seen_at'] = null;
        lat = null;
        lon = null;
        lastUpdated = '';
        isOnline = false;
        battery = 0;
        isLoading = true;
        dailyTrack = null;
      });
      if (mounted) {
        AppToast.success(
          context,
          'Collar $result successfully paired!',
        );
      }
      loadCollarLocation();
      listenToCollarUpdates();
    }
  }

  String formatTimeAgo(String timestamp) {
    if (timestamp.isEmpty) return 'Unknown';
    try {
      DateTime dt = DateTime.parse(timestamp);
      if (!timestamp.endsWith('Z') && !timestamp.contains('+')) {
        dt = DateTime.parse('${timestamp}Z');
      }
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.isNegative) return 'just now';
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.pet['name'] ?? 'Your Pet';
    final hasCollar = currentCollarId != null && currentCollarId!.isNotEmpty;
    final photoUrl = widget.pet['photo_url'] as String?;
    final cardHeight = _isCardMinimized
        ? 88.0
        : (MediaQuery.of(context).size.height * 0.45).clamp(340.0, 440.0);

    final historyHeight = _isHistoryMinimized
        ? 88.0
        : (MediaQuery.of(context).size.height * 0.46).clamp(340.0, 440.0);
    final floatingOffset = isHistoryMode ? (historyHeight + 14) : (cardHeight + 14);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── 1. Full-Screen Map (Takes 100% of the screen) ──
          Positioned.fill(
            child: isLoading
                ? Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : (lat == null && lon == null && (dailyTrack == null || dailyTrack!.points.isEmpty))
                    ? LocatePetEmptyView(hasCollar: hasCollar)
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: (lat != null && lon != null)
                              ? ll.LatLng(lat!, lon!)
                              : (dailyTrack != null && dailyTrack!.points.isNotEmpty)
                                  ? dailyTrack!.points.first
                                  : const ll.LatLng(14.5995, 120.9842),
                          initialZoom: 16.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.pettrace.app',
                          ),
                          if (NoSignalMaskService.instance.isLoaded)
                            PolygonLayer(
                              polygons: NoSignalMaskService.instance.polygons,
                            ),

                          // ── ROUTE POLYLINES (History Mode) ──
                          if (isHistoryMode && dailyTrack != null && dailyTrack!.points.length > 1)
                            PolylineLayer(
                              polylines: [
                                // Main full route (vibrant indigo / purple like reference screenshot)
                                Polyline(
                                  points: dailyTrack!.points,
                                  color: const Color(0xFF6366F1),
                                  strokeWidth: 5.0,
                                  borderColor: Colors.white,
                                  borderStrokeWidth: 1.5,
                                ),
                                // Highlighted segment (bright green when tapped)
                                if (selectedSegment != null && selectedSegment!.points.length > 1)
                                  Polyline(
                                    points: selectedSegment!.points,
                                    color: const Color(0xFF22C55E),
                                    strokeWidth: 7.0,
                                    borderColor: Colors.white,
                                    borderStrokeWidth: 2.0,
                                  ),
                              ],
                            ),

                          // ── GEOFENCE & LIVE MARKER (Live Mode) ──
                          if (!isHistoryMode && lat != null && lon != null) ...[
                            PetGeofenceLayer(
                              center: ll.LatLng(lat!, lon!),
                              isGpsActive: isGpsActive,
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: ll.LatLng(lat!, lon!),
                                  width: 160,
                                  height: 80,
                                  alignment: Alignment.center,
                                  child: LocatePetMarker(
                                    petName: petName,
                                    photoUrl: photoUrl,
                                    isGpsActive: isGpsActive,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── HISTORY MARKERS (Start, Stops, End) ──
                          if (isHistoryMode && dailyTrack != null && dailyTrack!.points.isNotEmpty)
                            MarkerLayer(
                              markers: [
                                // Start Marker (Green Flag / Pin)
                                Marker(
                                  point: dailyTrack!.points.first,
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 6,
                                        )
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),

                                // Intermediate Stop Dots
                                for (final seg in dailyTrack!.segments.where((s) => !s.isMoving))
                                  Marker(
                                    point: ll.LatLng(seg.endLat, seg.endLon),
                                    width: 18,
                                    height: 18,
                                    alignment: Alignment.center,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),

                                // End / Latest Location Marker
                                Marker(
                                  point: dailyTrack!.points.last,
                                  width: 140,
                                  height: 60,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.25),
                                              blurRadius: 6,
                                            )
                                          ],
                                        ),
                                        child: Text(
                                          '$petName (End)',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.location_on, color: Color(0xFF4F46E5), size: 24),
                                    ],
                                  ),
                                ),

                                // Focused Highlight Marker for tapped segment
                                if (selectedSegment != null)
                                  Marker(
                                    point: ll.LatLng(selectedSegment!.endLat, selectedSegment!.endLon),
                                    width: 50,
                                    height: 50,
                                    alignment: Alignment.center,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF22C55E), width: 2.5),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.my_location, color: Color(0xFF22C55E), size: 22),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
          ),

          // ── 2, 3, 4. Top Controls (Back button, Mode toggle pill, Manage collar) ──
          LocatePetTopControls(
            hasCollar: hasCollar,
            isGpsActive: isGpsActive,
            isHistoryMode: isHistoryMode,
            onBack: () {
              if (isHistoryMode) {
                _toggleHistoryMode();
              } else {
                Navigator.pop(context);
              }
            },
            onManageCollar: _handleManageCollar,
            onToggleHistory: _toggleHistoryMode,
          ),

          // ── 5. Floating History Toggle Button on Map ──
          LocatePetHistoryToggleButton(
            bottomOffset: floatingOffset + 50,
            isHistoryMode: isHistoryMode,
            onToggle: _toggleHistoryMode,
          ),

          // ── 6. Floating Re-center button (slides above the bottom card) ──
          LocatePetRecenterButton(
            bottomOffset: floatingOffset,
            onRecenter: () {
              if (isHistoryMode && dailyTrack != null && dailyTrack!.points.isNotEmpty) {
                if (dailyTrack!.points.length > 1) {
                  _mapController.fitCamera(
                    CameraFit.coordinates(
                      coordinates: dailyTrack!.points,
                      padding: const EdgeInsets.only(top: 80, bottom: 320, left: 40, right: 40),
                    ),
                  );
                } else {
                  _mapController.move(dailyTrack!.points.first, 16.0);
                }
              } else if (lat != null && lon != null) {
                _mapController.move(ll.LatLng(lat!, lon!), 16.0);
              }
            },
          ),

          // ── 7. Bottom Panel: History Timeline Sheet OR Live Pet Card ──
          if (isHistoryMode)
            LocatePetHistoryPanel(
              petName: petName,
              collarId: currentCollarId ?? '',
              selectedDate: selectedHistoryDate,
              dailyTrack: dailyTrack,
              isLoading: isLoadingHistory,
              isMinimized: _isHistoryMinimized,
              height: historyHeight,
              selectedSegment: selectedSegment,
              onClose: _toggleHistoryMode,
              onToggleMinimize: () {
                setState(() => _isHistoryMinimized = !_isHistoryMinimized);
              },
              onDragEnd: (velocity) {
                if (velocity > 120) {
                  setState(() => _isHistoryMinimized = true);
                } else if (velocity < -120) {
                  setState(() => _isHistoryMinimized = false);
                }
              },
              onSelectDate: (newDate) => _loadHistoryTrack(date: newDate),
              onSelectSegment: (seg) {
                setState(() => selectedSegment = seg);
                _mapController.move(ll.LatLng(seg.endLat, seg.endLon), 16.5);
              },
            )
          else
            LocatePetBottomCard(
              pet: widget.pet,
              currentCollarId: currentCollarId,
              hasCollar: hasCollar,
              isGpsActive: isGpsActive,
              battery: battery,
              lastUpdated: lastUpdated,
              lat: lat,
              lon: lon,
              isCardMinimized: _isCardMinimized,
              cardHeight: cardHeight,
              formatTimeAgo: formatTimeAgo,
              onToggleMinimize: () {
                setState(() => _isCardMinimized = !_isCardMinimized);
              },
              onDragEnd: (velocity) {
                if (velocity > 120) {
                  setState(() => _isCardMinimized = true);
                } else if (velocity < -120) {
                  setState(() => _isCardMinimized = false);
                }
              },
              onManageCollar: _handleManageCollar,
              onReportLost: () {
                if (isGpsActive) {
                  AppToast.error(
                    context,
                    'GPS is active. You cannot report as lost while the GPS collar is active.',
                  );
                  return;
                }
                Navigator.pushNamed(
                  context,
                  AppRoutes.reportLostPet,
                  arguments: widget.pet,
                );
              },
              onShare: () {
                AppToast.show(
                  context,
                  hasCollar
                      ? (lat != null && lon != null
                          ? "$petName's coordinates: ${lat!.toStringAsFixed(6)}, ${lon!.toStringAsFixed(6)}"
                          : "No GPS location yet for $petName.")
                      : "No collar paired to $petName.",
                  icon: Icons.share_rounded,
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_toast.dart';
import '../../../services/geo/no_signal_mask_service.dart';
import '../../../widgets/user/pair_collar_dialog.dart';
import '../../../widgets/user/locate_pet/pet_marker_widget.dart';
import '../../../widgets/user/locate_pet/locate_pet_top_controls.dart';
import '../../../widgets/user/locate_pet/locate_pet_bottom_card.dart';
import '../../../widgets/user/locate_pet/locate_pet_empty_view.dart';

export '../../../widgets/user/locate_pet/pet_marker_widget.dart';
export '../../../widgets/user/locate_pet/locate_pet_top_controls.dart';
export '../../../widgets/user/locate_pet/locate_pet_bottom_card.dart';
export '../../../widgets/user/locate_pet/locate_pet_empty_view.dart';

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
      final diff = DateTime.now().difference(dt.toLocal());
      return !diff.isNegative && diff.inSeconds <= 180;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    NoSignalMaskService.instance.loadMask().then((_) {
      if (mounted) setState(() {});
    });

    currentCollarId = widget.pet['gps_id'] as String?;
    if (currentCollarId != null && currentCollarId!.isNotEmpty) {
      loadCollarLocation();
      listenToCollarUpdates();
    } else {
      isLoading = false;
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
          battery = data['battery_level'] ?? data['battery'] ?? 0;
          lastUpdated = data['recorded_at'] ?? '';
          isLoading = false;
        });
        _mapController.move(ll.LatLng(lat!, lon!), 16.0);
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
          debugPrint('[GPS DEBUG] Raw Supabase data: $latest');
          debugPrint('[GPS DEBUG] recorded_at raw = "${latest['recorded_at']}"');
          setState(() {
            lat = (latest['lat'] as num).toDouble();
            lon = (latest['lon'] as num).toDouble();
            isOnline = latest['is_online'] ?? false;
            battery = latest['battery_level'] ?? latest['battery'] ?? 0;
            lastUpdated = latest['recorded_at'] ?? '';
          });
          debugPrint('[GPS DEBUG] lastUpdated = "$lastUpdated", isGpsActive = $isGpsActive');

          // Move map camera to new location (lat/lon are set above so they're non-null here)
          _mapController.move(ll.LatLng(lat!, lon!), 16.0);
        }, onError: (err) {
          debugPrint('[LocatePetScreen] Stream error: $err');
        });
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
        widget.pet['last_seen_address'] = null;
        widget.pet['last_seen_lat'] = null;
        widget.pet['last_seen_lon'] = null;
        widget.pet['last_seen_at'] = null;
        isOnline = false;
        battery = 0;
        lastUpdated = '';
        lat = null; // no location — collar is gone
        lon = null;
        isLoading = false;
      });
      if (mounted) {
        AppToast.show(
          context,
          'Collar unpaired from this pet.',
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
                : (lat == null || lon == null)
                    ? LocatePetEmptyView(hasCollar: hasCollar)
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: ll.LatLng(lat!, lon!),
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
                          if (hasCollar)
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
                      ),
          ),

          // ── 2, 3, 4. Top Controls (Back button, Status pill, Manage collar) ──
          LocatePetTopControls(
            hasCollar: hasCollar,
            isGpsActive: isGpsActive,
            onBack: () => Navigator.pop(context),
            onManageCollar: _handleManageCollar,
          ),

          // ── 5. Floating Re-center button (slides above the bottom card) ──
          if (lat != null && lon != null)
            LocatePetRecenterButton(
              bottomOffset: cardHeight + 14,
              onRecenter: () => _mapController.move(
                ll.LatLng(lat!, lon!),
                16.0,
              ),
            ),

          // ── 6. Minimizable Bottom Pet Info Card ──
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

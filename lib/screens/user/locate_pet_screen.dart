import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../widgets/pair_collar_dialog.dart';

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
  double lat = 13.9747; // default Virac coordinates
  double lon = 124.2432;
  bool isOnline = false;
  int battery = 0;
  String lastUpdated = '';
  bool isLoading = true;
  bool _isCardMinimized = false;

  /// Returns true only if the collar is marked online AND has sent a GPS ping within the last 45 seconds.
  /// (Since testing interval is 30 seconds, anything > 45 seconds means the collar is offline or powered off).
  bool get isGpsActive {
    final hasCollar = currentCollarId != null && currentCollarId!.isNotEmpty;
    if (!hasCollar || !isOnline || lastUpdated.isEmpty) return false;
    try {
      DateTime dt = DateTime.parse(lastUpdated);
      if (!lastUpdated.endsWith('Z') && !lastUpdated.contains('+')) {
        dt = DateTime.parse('${lastUpdated}Z');
      }
      final diff = DateTime.now().difference(dt.toLocal());
      return diff.inSeconds <= 45;
    } catch (_) {
      return isOnline;
    }
  }

  @override
  void initState() {
    super.initState();
    currentCollarId = widget.pet['collar_id'] as String?;
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
          .from('collar_locations')
          .select()
          .eq('collar_id', collarId)
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
        _mapController.move(ll.LatLng(lat, lon), 16.0);
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
        .from('collar_locations')
        .stream(primaryKey: ['location_id'])
        .eq('collar_id', collarId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .listen((data) {
          if (!mounted || data.isEmpty) return;
          final latest = data.first;
          setState(() {
            lat = (latest['lat'] as num).toDouble();
            lon = (latest['lon'] as num).toDouble();
            isOnline = latest['is_online'] ?? false;
            battery = latest['battery_level'] ?? latest['battery'] ?? 0;
            lastUpdated = latest['recorded_at'] ?? '';
          });

          // Move map camera to new location
          _mapController.move(ll.LatLng(lat, lon), 16.0);
        }, onError: (err) {
          debugPrint('[LocatePetScreen] Stream error: $err');
        });
  }

  Future<void> _handleManageCollar() async {
    final petCopy = Map<String, dynamic>.from(widget.pet);
    petCopy['collar_id'] = currentCollarId;
    final result = await showPairCollarDialog(context: context, pet: petCopy);
    if (result == null) return;

    _locationSub?.cancel();
    _locationSub = null;

    if (result == '__unpaired__') {
      setState(() {
        currentCollarId = null;
        widget.pet['collar_id'] = null;
        isOnline = false;
        battery = 0;
        lastUpdated = '';
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collar unpaired from this pet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() {
        currentCollarId = result;
        widget.pet['collar_id'] = result;
        isLoading = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collar $result successfully paired!'),
            behavior: SnackBarBehavior.floating,
          ),
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
      if (diff.isNegative || diff.inSeconds < 60) return '${diff.inSeconds.abs()}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  Widget _buildPetMarker(String petName) {
    final photoUrl = widget.pet['photo_url'] as String?;
    final active = isGpsActive;
    final markerColor = active ? const Color(0xFFFF6600) : const Color(0xFF64748B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFFFF6600) : const Color(0xFF94A3B8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  active ? petName : '$petName (Last Known)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: markerColor.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
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
                      color: Colors.white,
                      size: 22,
                    ),
                  )
                : const Icon(
                    Icons.pets,
                    color: Colors.white,
                    size: 22,
                  ),
          ),
        ),
      ],
    );
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
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: ll.LatLng(lat, lon),
                      initialZoom: 16.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.pawtrace.app',
                      ),
                      if (hasCollar)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: ll.LatLng(lat, lon),
                              width: 160,
                              height: 80,
                              alignment: Alignment.center,
                              child: _buildPetMarker(petName),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),

          // ── 2. Top Controls: Back button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
          ),

          // ── 3. Top Controls: Status pill ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 58,
            right: 58,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: !hasCollar
                      ? const Color(0xFFF59E0B)
                      : (isGpsActive
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF475569)),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasCollar)
                      const Icon(Icons.sensors_off_rounded,
                          color: Colors.white, size: 14)
                    else if (isGpsActive)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const Icon(Icons.location_off_rounded,
                          color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        !hasCollar
                            ? 'No Collar Paired'
                            : (isGpsActive
                                ? 'Live Tracking'
                                : 'GPS Offline • Last Known'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 4. Top Controls: Manage Collar button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: _handleManageCollar,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // ── 5. Floating Re-center button (slides above the bottom card) ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            bottom: cardHeight + 14,
            right: 14,
            child: GestureDetector(
              onTap: () => _mapController.move(
                ll.LatLng(lat, lon),
                16.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // ── 6. Minimizable Bottom Pet Info Card ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            bottom: 0,
            left: 0,
            right: 0,
            height: cardHeight,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! > 120) {
                    setState(() => _isCardMinimized = true);
                  } else if (details.primaryVelocity! < -120) {
                    setState(() => _isCardMinimized = false);
                  }
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // Header / Handle bar with toggle
                    InkWell(
                      onTap: () {
                        setState(() => _isCardMinimized = !_isCardMinimized);
                      },
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Column(
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 44,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Mini summary row when minimized, or minimize prompt when expanded
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_isCardMinimized) ...[
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundImage: photoUrl != null
                                              ? NetworkImage(photoUrl)
                                              : null,
                                          backgroundColor:
                                              AppColors.primaryContainer,
                                          child: photoUrl == null
                                              ? const Icon(Icons.pets,
                                                  size: 14,
                                                  color: AppColors.primary)
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            petName,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: !hasCollar
                                                ? const Color(0xFFFEF3C7)
                                                : (isGpsActive
                                                    ? const Color(0xFFD1FAE5)
                                                    : const Color(0xFFFEE2E2)),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            !hasCollar
                                                ? 'Unpaired'
                                                : (isGpsActive
                                                    ? 'Active'
                                                    : 'Offline'),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: !hasCollar
                                                  ? const Color(0xFF92400E)
                                                  : (isGpsActive
                                                      ? const Color(0xFF065F46)
                                                      : const Color(0xFFB91C1C)),
                                            ),
                                          ),
                                        ),
                                        if (hasCollar && battery > 0) ...[
                                          const SizedBox(width: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.battery_full,
                                                  size: 13,
                                                  color: Color(0xFF22C55E)),
                                              const SizedBox(width: 2),
                                              Text(
                                                '$battery%',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    'Pet & Location Details',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                Row(
                                  children: [
                                    Text(
                                      _isCardMinimized
                                          ? 'Show Details'
                                          : 'Minimize Map',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Icon(
                                      _isCardMinimized
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Detailed Content (Only rendered when expanded)
                    if (!_isCardMinimized)
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pet name and status
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    backgroundColor: AppColors.primaryContainer,
                                    child: photoUrl == null
                                        ? const Icon(Icons.pets,
                                            color: AppColors.primary)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      petName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !hasCollar
                                          ? const Color(0xFFFEF3C7)
                                          : (isGpsActive
                                              ? const Color(0xFFD1FAE5)
                                              : const Color(0xFFFEE2E2)),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      !hasCollar
                                          ? 'Unpaired'
                                          : (isGpsActive ? 'Active' : 'Offline'),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: !hasCollar
                                            ? const Color(0xFF92400E)
                                            : (isGpsActive
                                                ? const Color(0xFF065F46)
                                                : const Color(0xFFB91C1C)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // GPS Offline Warning Notice
                              if (hasCollar && !isGpsActive) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.location_off_rounded,
                                        color: Color(0xFFD97706),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'GPS Collar Offline',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF92400E),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'The collar is powered off or disconnected. Displaying the last known location recorded ${formatTimeAgo(lastUpdated)}.',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFFB45309),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Unpaired Prompt or Info Pills
                              if (!hasCollar) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.outlineVariant
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.sensors_off_rounded,
                                          color: Color(0xFFF59E0B),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'No GPS Collar Attached',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.onSurface,
                                              ),
                                            ),
                                            Text(
                                              'Pair a collar (1 collar for 1 pet) to start tracking.',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: _handleManageCollar,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text('Pair Collar'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ] else ...[
                                // Info pills
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _infoPill(
                                      Icons.location_on,
                                      widget.pet['barangay'] ?? 'Unknown',
                                    ),
                                    _infoPill(
                                      isGpsActive
                                          ? Icons.access_time
                                          : Icons.history_rounded,
                                      isGpsActive
                                          ? formatTimeAgo(lastUpdated)
                                          : 'Seen ${formatTimeAgo(lastUpdated)}',
                                    ),
                                    _infoPill(
                                      isGpsActive
                                          ? Icons.sensors_rounded
                                          : Icons.sensors_off_rounded,
                                      isGpsActive
                                          ? 'Signal Live'
                                          : 'Signal Lost',
                                    ),
                                    if (battery > 0)
                                      _infoPill(
                                        Icons.battery_full,
                                        '$battery%',
                                      ),
                                    InkWell(
                                      onTap: _handleManageCollar,
                                      borderRadius: BorderRadius.circular(999),
                                      child: _infoPill(
                                        Icons.tag_rounded,
                                        currentCollarId!,
                                        trailingIcon: Icons.edit,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Coordinates
                                Text(
                                  isGpsActive
                                      ? 'Live Location Coordinates'
                                      : 'Last Known Location Coordinates',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lat: ${lat.toStringAsFixed(6)}, Lon: ${lon.toStringAsFixed(6)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.reportLostPet,
                                          arguments: widget.pet,
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.warning_amber_rounded),
                                      label: const Text('Report as Lost'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              hasCollar
                                                  ? "$petName's coordinates: $lat, $lon"
                                                  : "No collar paired to $petName.",
                                            ),
                                            behavior:
                                                SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.share),
                                      label: const Text('Share'),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppColors.primary,
                                        ),
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, {IconData? trailingIcon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 12, color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}

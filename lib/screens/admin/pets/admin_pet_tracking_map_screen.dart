import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';
import '../../../widgets/admin/pet_location_map_dialog.dart' show PetLocationResult;
import '../../../widgets/common/photo_placeholder.dart';

/// Fullscreen Admin Pet GPS Tracking and Location Map screen.
/// Supports live realtime collar updates, accurate staleness status (Live vs Offline),
/// responsive web & mobile layouts, and admin context info.
class AdminPetTrackingMapScreen extends StatefulWidget {
  final Map<String, dynamic> pet;
  final PetLocationResult? initialLocation;

  const AdminPetTrackingMapScreen({
    super.key,
    required this.pet,
    this.initialLocation,
  });

  @override
  State<AdminPetTrackingMapScreen> createState() =>
      _AdminPetTrackingMapScreenState();
}

class _AdminPetTrackingMapScreenState extends State<AdminPetTrackingMapScreen> {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  StreamSubscription? _locationSub;
  Timer? _tickerTimer;

  String? _collarId;
  double? _lat;
  double? _lon;
  String _address = '';
  String _lastUpdated = '';
  int? _battery;
  bool _isLoading = true;
  bool _isPanelCollapsed = false;
  Map<String, dynamic>? _fetchedUser;

  /// Returns true only if the collar ping was received within the last 180 seconds (3 minutes).
  bool get _isLiveGpsActive {
    final hasCollar = _collarId != null && _collarId!.isNotEmpty;
    if (!hasCollar || _lastUpdated.isEmpty || _lat == null) return false;
    try {
      DateTime dt = DateTime.parse(_lastUpdated);
      if (!_lastUpdated.endsWith('Z') && !_lastUpdated.contains('+')) {
        dt = DateTime.parse('${_lastUpdated}Z');
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
    _collarId = (widget.pet['gps_id'] ?? '').toString().trim();
    if (_collarId != null &&
        (_collarId!.toUpperCase() == 'N/A' ||
            _collarId!.toUpperCase() == 'NONE' ||
            _collarId!.isEmpty)) {
      _collarId = null;
    }

    if (widget.initialLocation != null) {
      _lat = widget.initialLocation!.lat;
      _lon = widget.initialLocation!.lon;
      _address = widget.initialLocation!.displayAddress;
      _lastUpdated = widget.initialLocation!.timeRecorded ?? '';
      _battery = widget.initialLocation!.battery;
    }

    _loadOwnerInfo();
    _loadInitialLocation();

    if (_collarId != null && _collarId!.isNotEmpty) {
      _listenToCollarStream();
    }

    // Refresh every 5 seconds so live/offline badge transitions dynamically
    _tickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialLocation() async {
    if (_collarId != null && _collarId!.isNotEmpty) {
      try {
        final ping = await _supabase
            .from('gps_locations')
            .select()
            .eq('gps_id', _collarId!)
            .order('recorded_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (ping != null && mounted) {
          setState(() {
            final pLat = (ping['lat'] as num?)?.toDouble();
            final pLon = (ping['lon'] as num?)?.toDouble();
            if (pLat != null && pLon != null) {
              _lat = pLat;
              _lon = pLon;
            }
            _lastUpdated = ping['recorded_at']?.toString() ?? _lastUpdated;
            _battery = (ping['battery_level'] ?? ping['battery']) as int?;
            _isLoading = false;
          });

          if (_lat != null && _lon != null) {
            _mapController.move(ll.LatLng(_lat!, _lon!), 16.0);
          }
          return;
        }
      } catch (e) {
        debugPrint('[AdminTracking] Error loading collar ping: $e');
      }
    }

    // If no collar or no collar ping, fallback to initialLocation or registered barangay
    if (mounted) {
      setState(() {
        _lat ??= 13.5938;
        _lon ??= 124.2381;
        if (_address.isEmpty) {
          final brgy = widget.pet['barangay']?.toString() ??
              widget.pet['users']?['barangay']?.toString() ??
              '';
          _address = brgy.isNotEmpty ? '$brgy, Catanduanes' : 'Catanduanes';
        }
        _isLoading = false;
      });
      _mapController.move(ll.LatLng(_lat!, _lon!), 15.0);
    }
  }

  Future<void> _loadOwnerInfo() async {
    // 1. Check if user is already embedded in widget.pet
    if (widget.pet['users'] is Map<String, dynamic>) {
      _fetchedUser = widget.pet['users'] as Map<String, dynamic>;
      if (mounted) setState(() {});
      return;
    }
    if (widget.pet['owner_id'] is Map<String, dynamic>) {
      _fetchedUser = widget.pet['owner_id'] as Map<String, dynamic>;
      if (mounted) setState(() {});
      return;
    }
    if (widget.pet['owner'] is Map<String, dynamic>) {
      _fetchedUser = widget.pet['owner'] as Map<String, dynamic>;
      if (mounted) setState(() {});
      return;
    }

    // 2. Fetch by owner_id / user_id UUID string
    final rawOwnerId = widget.pet['owner_id'] ??
        widget.pet['user_id'] ??
        (widget.pet['users'] is String ? widget.pet['users'] : null);
    if (rawOwnerId is String && rawOwnerId.trim().isNotEmpty) {
      try {
        final res = await _supabase
            .from('users')
            .select()
            .eq('user_id', rawOwnerId.trim())
            .maybeSingle();
        if (res != null && mounted) {
          setState(() {
            _fetchedUser = Map<String, dynamic>.from(res);
          });
          return;
        }
      } catch (e) {
        debugPrint('[AdminTracking] Error fetching user by owner_id: $e');
      }
    }

    // 3. Fallback: Query pet with joined users table
    final petId = widget.pet['pet_id'] ?? widget.pet['id'];
    if (petId != null) {
      try {
        final petRecord = await _supabase
            .from('pets')
            .select('*, users(*)')
            .eq('pet_id', petId)
            .maybeSingle();
        if (petRecord != null && petRecord['users'] is Map && mounted) {
          setState(() {
            _fetchedUser = Map<String, dynamic>.from(petRecord['users']);
          });
        }
      } catch (e) {
        debugPrint('[AdminTracking] Error fetching pet with users: $e');
      }
    }
  }

  void _listenToCollarStream() {
    final collar = _collarId;
    if (collar == null || collar.isEmpty) return;

    _locationSub?.cancel();
    _locationSub = _supabase
        .from('gps_locations')
        .stream(primaryKey: ['location_id'])
        .eq('gps_id', collar)
        .order('recorded_at', ascending: false)
        .limit(1)
        .listen(
      (data) {
        if (!mounted || data.isEmpty) return;
        final latest = data.first;
        final pLat = (latest['lat'] as num?)?.toDouble();
        final pLon = (latest['lon'] as num?)?.toDouble();

        if (pLat != null && pLon != null) {
          setState(() {
            _lat = pLat;
            _lon = pLon;
            _battery = (latest['battery_level'] ?? latest['battery']) as int?;
            _lastUpdated = latest['recorded_at']?.toString() ?? '';
          });
          _mapController.move(ll.LatLng(pLat, pLon), 16.0);
        }
      },
      onError: (err) {
        debugPrint('[AdminTracking] Stream error: $err');
      },
    );
  }

  String _formatTimeAgo(String timestamp) {
    if (timestamp.isEmpty) return 'No timestamp';
    try {
      DateTime dt = DateTime.parse(timestamp);
      if (!timestamp.endsWith('Z') && !timestamp.contains('+')) {
        dt = DateTime.parse('${timestamp}Z');
      }
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.isNegative) return 'Just now';
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return timestamp;
    }
  }

  Future<void> _callOwner(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      AppToast.error(context, 'No phone number on record.');
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        AppToast.error(context, 'Could not launch dialer.');
      }
    }
  }

  void _copyCoordinates() {
    if (_lat == null || _lon == null) return;
    final text = '${_lat!.toStringAsFixed(6)}, ${_lon!.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    AppToast.success(context, 'Coordinates copied: $text');
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.pet['name']?.toString() ?? 'Pet';
    final species = widget.pet['species']?.toString() ?? 'Pet';
    final breed = widget.pet['breed']?.toString() ?? 'Unknown Breed';
    final photoUrl = widget.pet['photo_url']?.toString() ?? '';
    final petStatus =
        (widget.pet['status']?.toString() ?? 'active').toLowerCase();

    final u = _fetchedUser ??
        (widget.pet['users'] is Map<String, dynamic>
            ? widget.pet['users'] as Map<String, dynamic>
            : null) ??
        (widget.pet['owner_id'] is Map<String, dynamic>
            ? widget.pet['owner_id'] as Map<String, dynamic>
            : null) ??
        (widget.pet['owner'] is Map<String, dynamic>
            ? widget.pet['owner'] as Map<String, dynamic>
            : null);

    final ownerName = u != null
        ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']]
            .where((s) => s != null && s.toString().trim().isNotEmpty)
            .join(' ')
        : (widget.pet['owner_name']?.toString() ?? 'Unknown Owner');
    final ownerPhone = u?['phone']?.toString() ??
        widget.pet['phone']?.toString() ??
        widget.pet['owner_phone']?.toString() ??
        '';
    final ownerEmail = u?['email']?.toString() ??
        widget.pet['email']?.toString() ??
        widget.pet['owner_email']?.toString() ??
        '';
    final barangay = widget.pet['barangay']?.toString() ??
        u?['barangay']?.toString() ??
        'Catanduanes';

    final hasCollar = _collarId != null && _collarId!.isNotEmpty;
    final isLive = _isLiveGpsActive;
    final targetPoint = ll.LatLng(_lat ?? 13.5938, _lon ?? 124.2381);

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── 1. Fullscreen Map ──
          Positioned.fill(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: targetPoint,
                      initialZoom: 16.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.pettrace.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: targetPoint,
                            width: 140,
                            height: 86,
                            alignment: Alignment.topCenter,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.18),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: isLive
                                            ? const Color(0xFF16A34A)
                                            : (hasCollar
                                                ? const Color(0xFFD97706)
                                                : AppColors.primary),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: isLive
                                                ? const Color(0xFF16A34A)
                                                : (hasCollar
                                                    ? const Color(0xFFD97706)
                                                    : AppColors.primary),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          petName,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.location_on,
                                    size: 42,
                                    color: isLive
                                        ? const Color(0xFF16A34A)
                                        : (hasCollar
                                            ? const Color(0xFFD97706)
                                            : AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // ── 2. Top Header Bar (Admin Context) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Back button
                    Material(
                      color: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.arrow_back,
                              color: AppColors.onSurface, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Admin Header Title Pill
                    Expanded(
                      child: Material(
                        color: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: photoUrl.isNotEmpty
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const PhotoPlaceholder(
                                                  iconSize: 18),
                                        )
                                      : const PhotoPlaceholder(iconSize: 18),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      petName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      '$breed • $species',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Live / Offline Status Pill
                              _buildStatusBadge(
                                  hasCollar: hasCollar,
                                  isLive: isLive,
                                  lastUpdated: _lastUpdated),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Floating Re-Center Button ──
          Positioned(
            right: 16,
            bottom: isWide ? 24 : (_isPanelCollapsed ? 90 : 260),
            child: Material(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  _mapController.move(targetPoint, 16.0);
                },
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.my_location_rounded,
                      color: AppColors.primary, size: 22),
                ),
              ),
            ),
          ),

          // ── 4. Responsive Info Panel ──
          // On Web Desktop: Elegant floating right card (width 360)
          // On Mobile: Bottom sheet card with collapse toggle
          if (isWide)
            Positioned(
              right: 16,
              top: 76,
              bottom: 24,
              child: SizedBox(
                width: 360,
                child: _buildAdminInfoCard(
                  petName: petName,
                  species: species,
                  breed: breed,
                  petStatus: petStatus,
                  ownerName: ownerName,
                  ownerPhone: ownerPhone,
                  ownerEmail: ownerEmail,
                  barangay: barangay,
                  hasCollar: hasCollar,
                  isLive: isLive,
                ),
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileBottomPanel(
                petName: petName,
                species: species,
                breed: breed,
                petStatus: petStatus,
                ownerName: ownerName,
                ownerPhone: ownerPhone,
                ownerEmail: ownerEmail,
                barangay: barangay,
                hasCollar: hasCollar,
                isLive: isLive,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool hasCollar,
    required bool isLive,
    required String lastUpdated,
  }) {
    if (!hasCollar) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'No Collar',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      );
    }

    if (isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'LIVE GPS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF16A34A),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'OFFLINE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminInfoCard({
    required String petName,
    required String species,
    required String breed,
    required String petStatus,
    required String ownerName,
    required String ownerPhone,
    required String ownerEmail,
    required String barangay,
    required bool hasCollar,
    required bool isLive,
  }) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PET TRACKING DETAILS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // GPS Collar telemetry section
            Text(
              'TELEMETRY & STATUS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLive
                    ? const Color(0xFFF0FDF4)
                    : (hasCollar
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLive
                      ? const Color(0xFFBBF7D0)
                      : (hasCollar
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFBFDBFE)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Collar ID:',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        hasCollar ? _collarId! : 'None paired',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Collar Status:',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        isLive
                            ? 'Actively Transmitting'
                            : (hasCollar
                                ? 'Offline / Sleep Mode'
                                : 'No Device'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isLive
                              ? const Color(0xFF16A34A)
                              : (hasCollar
                                  ? const Color(0xFFD97706)
                                  : AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  if (_battery != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Battery Level:',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                        Row(
                          children: [
                            Icon(
                              _battery! > 20
                                  ? Icons.battery_full_rounded
                                  : Icons.battery_alert_rounded,
                              size: 14,
                              color: _battery! > 20
                                  ? const Color(0xFF16A34A)
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_battery%',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  if (_lastUpdated.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Last Update:',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                        Text(
                          _formatTimeAgo(_lastUpdated),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Coordinates & Address
            Text(
              'LOCATION COORDINATES',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _lat != null && _lon != null
                        ? '${_lat!.toStringAsFixed(6)}, ${_lon!.toStringAsFixed(6)}'
                        : 'No coordinates',
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _copyCoordinates,
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  tooltip: 'Copy coordinates',
                  color: AppColors.primary,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _address.isNotEmpty ? _address : barangay,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),

            const Divider(height: 24),

            // Owner Information
            Text(
              'OWNER CONTACT',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ownerName,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            if (barangay.isNotEmpty)
              Text(
                'Barangay $barangay',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),

            // Action: Call owner
            if (ownerPhone.isNotEmpty && ownerPhone != '-')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _callOwner(ownerPhone),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: Text('Call Owner ($ownerPhone)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomPanel({
    required String petName,
    required String species,
    required String breed,
    required String petStatus,
    required String ownerName,
    required String ownerPhone,
    required String ownerEmail,
    required String barangay,
    required bool hasCollar,
    required bool isLive,
  }) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black38,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag / Toggle Handle
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isPanelCollapsed = !_isPanelCollapsed);
                  },
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Summary Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _address.isNotEmpty ? _address : barangay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _lat != null && _lon != null
                              ? '${_lat!.toStringAsFixed(5)}, ${_lon!.toStringAsFixed(5)} • ${_formatTimeAgo(_lastUpdated)}'
                              : 'No coordinates',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _isPanelCollapsed = !_isPanelCollapsed);
                    },
                    icon: Icon(
                      _isPanelCollapsed
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              if (!_isPanelCollapsed) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Owner: $ownerName',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          if (barangay.isNotEmpty)
                            Text(
                              'Brgy. $barangay',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (ownerPhone.isNotEmpty && ownerPhone != '-')
                      ElevatedButton.icon(
                        onPressed: () => _callOwner(ownerPhone),
                        icon: const Icon(Icons.phone_rounded, size: 14),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

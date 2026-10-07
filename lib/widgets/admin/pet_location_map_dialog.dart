import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../screens/admin/pets/admin_pet_tracking_map_screen.dart';

/// Data class holding resolved location info for a pet
class PetLocationResult {
  final double lat;
  final double lon;
  final String displayAddress;
  final String rawAddress;
  final String? timeRecorded;
  final String? note;
  final String sourceLabel;
  final Color sourceColor;
  final bool isLiveCollar;
  final int? battery;
  final bool hasCoordinates;

  const PetLocationResult({
    required this.lat,
    required this.lon,
    required this.displayAddress,
    required this.rawAddress,
    this.timeRecorded,
    this.note,
    required this.sourceLabel,
    required this.sourceColor,
    this.isLiveCollar = false,
    this.battery,
    required this.hasCoordinates,
  });
}

/// Helper function to fetch the most accurate last known location of any pet.
///
/// Priority:
/// 1. Live/Last GPS ping from 'gps_locations' if pet has a gps_id.
/// 2. Active or recent lost report in 'lost_reports' table.
/// 3. Pet record fields: 'last_seen_address', 'last_seen_lat', 'last_seen_lon'.
/// 4. Regex coordinates extraction from 'last_seen_address' (Lat: ..., Lng: ...).
/// 5. Fallback to registered barangay in Catanduanes.
Future<PetLocationResult> fetchPetLocation(Map<String, dynamic> pet) async {
  final supabase = Supabase.instance.client;
  final petId = pet['pet_id'] ?? pet['id'];
  final collarId = (pet['gps_id'] ?? '').toString().trim();
  final petStatus = (pet['status'] ?? '').toString().toLowerCase();

  double? lat;
  double? lon;
  String? rawAddress;
  String? timeRecorded;
  String? note;
  String sourceLabel = 'Registered Address';
  Color sourceColor = const Color(0xFF2563EB); // Blue
  bool isLiveCollar = false;
  int? battery;

  // 1. If pet has a collar assigned, fetch the latest collar GPS ping
  if (collarId.isNotEmpty &&
      collarId.toUpperCase() != 'N/A' &&
      collarId.toUpperCase() != 'NONE') {
    try {
      final collarPing = await supabase
          .from('gps_locations')
          .select()
          .eq('gps_id', collarId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (collarPing != null) {
        final pLat = (collarPing['lat'] as num?)?.toDouble();
        final pLon = (collarPing['lon'] as num?)?.toDouble();
        if (pLat != null && pLon != null) {
          lat = pLat;
          lon = pLon;
          timeRecorded = collarPing['recorded_at']?.toString();
          battery = (collarPing['battery_level'] ?? collarPing['battery']) as int?;

          bool isFreshPing = false;
          final tr = timeRecorded;
          if (tr != null && tr.isNotEmpty) {
            try {
              DateTime dt = DateTime.parse(tr);
              if (!tr.endsWith('Z') && !tr.contains('+')) {
                dt = DateTime.parse('${tr}Z');
              }
              final diff = DateTime.now().difference(dt.toLocal());
              isFreshPing = !diff.isNegative && diff.inSeconds <= 180;
            } catch (_) {}
          }

          if (isFreshPing) {
            isLiveCollar = true;
            sourceLabel = 'Live GPS Collar';
            sourceColor = const Color(0xFF16A34A); // Green
          } else {
            isLiveCollar = false;
            sourceLabel = 'Collar Offline (Last Known)';
            sourceColor = const Color(0xFFD97706); // Amber
          }
        }
      }
    } catch (e) {
      debugPrint('[PetLocation] Error fetching collar location: $e');
    }
  }

  // 2. Check lost_reports table for this pet
  if (petId != null) {
    try {
      final reports = await supabase
          .from('lost_reports')
          .select('*')
          .eq('pet_id', petId)
          .order('reported_at', ascending: false)
          .limit(1);

      if (reports.isNotEmpty) {
        final r = reports.first;
        final rAddress = (r['last_seen_address'] ?? r['barangay'] ?? '').toString();
        if (rAddress.isNotEmpty) {
          rawAddress = rAddress;
        }

        final rNote = (r['description'] ?? r['notes'] ?? '').toString();
        if (rNote.isNotEmpty) {
          note = rNote;
        }

        timeRecorded ??= r['reported_at']?.toString();

        // Numeric coordinates in lost_reports
        final rLat = (r['last_seen_lat'] as num?)?.toDouble() ??
            (r['lat'] as num?)?.toDouble();
        final rLon = (r['last_seen_lon'] as num?)?.toDouble() ??
            (r['lon'] as num?)?.toDouble();

        if (rLat != null && rLon != null && (lat == null || lon == null || petStatus == 'lost')) {
          lat = rLat;
          lon = rLon;
          sourceLabel = 'Lost Pet Report';
          sourceColor = AppColors.error;
        }
      }
    } catch (e) {
      debugPrint('[PetLocation] Error fetching lost report: $e');
    }
  }

  // 3. Check pet record directly
  if (rawAddress == null || rawAddress.isEmpty) {
    final petLastSeen = pet['last_seen_address']?.toString() ?? '';
    if (petLastSeen.isNotEmpty) {
      rawAddress = petLastSeen;
    }
  }

  if (lat == null || lon == null) {
    final pLat = (pet['last_seen_lat'] as num?)?.toDouble();
    final pLon = (pet['last_seen_lon'] as num?)?.toDouble();
    if (pLat != null && pLon != null) {
      lat = pLat;
      lon = pLon;
      sourceLabel = 'Last Seen Record';
      sourceColor = AppColors.primary;
    }
  }

  // 4. Regex coordinates extraction from any text in rawAddress or pet['last_seen_address']
  if (lat == null || lon == null) {
    final textToSearch = '${rawAddress ?? ''} ${pet['last_seen_address'] ?? ''}';
    final match = RegExp(r'Lat:\s*([-\d.]+),\s*Lng:\s*([-\d.]+)', caseSensitive: false)
        .firstMatch(textToSearch);
    if (match != null) {
      final parsedLat = double.tryParse(match.group(1)!);
      final parsedLon = double.tryParse(match.group(2)!);
      if (parsedLat != null && parsedLon != null) {
        lat = parsedLat;
        lon = parsedLon;
        if (sourceLabel == 'Registered Address') {
          sourceLabel = 'Reported Coordinates';
          sourceColor = AppColors.primary;
        }
      }
    }
  }

  // Fallback barangay
  final barangay = pet['barangay']?.toString() ??
      (pet['users'] is Map ? pet['users']['barangay']?.toString() : null) ??
      (pet['owner_id'] is Map ? pet['owner_id']['barangay']?.toString() : null) ??
      (pet['owner'] is Map ? pet['owner']['barangay']?.toString() : null) ??
      '';

  if (rawAddress == null || rawAddress.isEmpty) {
    rawAddress = barangay.isNotEmpty ? '$barangay, Catanduanes' : 'Catanduanes';
  }

  // Clean formatted address for display (strip raw Lat/Lng regex string)
  String displayAddress = rawAddress
      .replaceAll(RegExp(r'\s*\(?Lat:\s*[-\d.]+,\s*Lng:\s*[-\d.]+\)?', caseSensitive: false), '')
      .trim();
  if (displayAddress.isEmpty) {
    displayAddress = barangay.isNotEmpty ? '$barangay, Catanduanes' : 'Catanduanes';
  }

  final bool hasCoordinates = (lat != null && lon != null);
  if (!hasCoordinates && !isLiveCollar) {
    sourceLabel = 'No GPS Connected';
    sourceColor = const Color(0xFF64748B);
  }
  // Default to San Andres / Virac Catanduanes center if no GPS available
  final double finalLat = lat ?? 13.5938;
  final double finalLon = lon ?? 124.2381;

  return PetLocationResult(
    lat: finalLat,
    lon: finalLon,
    displayAddress: displayAddress,
    rawAddress: rawAddress,
    timeRecorded: timeRecorded,
    note: note,
    sourceLabel: sourceLabel,
    sourceColor: sourceColor,
    isLiveCollar: isLiveCollar,
    battery: battery,
    hasCoordinates: hasCoordinates,
  );
}

String _formatTimeAgo(String? timestamp) {
  if (timestamp == null || timestamp.isEmpty) return 'Recent';
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
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  } catch (_) {
    return 'Recent';
  }
}

/// Opens the interactive Pet Location Map dialog.
Future<void> showPetLocationMapDialog(
  BuildContext context,
  Map<String, dynamic> pet,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => PetLocationMapDialog(pet: pet),
  );
}

class PetLocationMapDialog extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PetLocationMapDialog({super.key, required this.pet});

  @override
  State<PetLocationMapDialog> createState() => _PetLocationMapDialogState();
}

class _PetLocationMapDialogState extends State<PetLocationMapDialog> {
  late Future<PetLocationResult> _locationFuture;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _locationFuture = fetchPetLocation(widget.pet);
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.pet['name']?.toString() ?? 'Pet';
    final species = widget.pet['species']?.toString() ?? 'Pet';
    final breed = widget.pet['breed']?.toString() ?? '';
    final photoUrl = widget.pet['photo_url']?.toString() ?? '';
    final status = (widget.pet['status']?.toString() ?? 'active').toLowerCase();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 16,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: FutureBuilder<PetLocationResult>(
          future: _locationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Locating $petName...',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pulling collar GPS and last known location records...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to pull location',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            final loc = snapshot.data!;
            final targetPoint = ll.LatLng(loc.lat, loc.lon);

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 46,
                            height: 46,
                            color: AppColors.surfaceContainerHigh,
                            child: photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.pets,
                                        color: AppColors.primary,
                                        size: 24),
                                  )
                                : const Icon(Icons.pets,
                                    color: AppColors.primary, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      petName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                breed.isNotEmpty ? '$breed • $species' : species,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.onSurfaceVariant,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // 2. Location Source & GPS Status Pill Row
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: loc.sourceColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: loc.sourceColor.withOpacity(0.24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: loc.sourceColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.sourceLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: loc.sourceColor,
                          ),
                        ),
                        const Spacer(),
                        if (loc.battery != null) ...[
                          Icon(
                            loc.battery! > 20
                                ? Icons.battery_full_rounded
                                : Icons.battery_alert_rounded,
                            size: 15,
                            color: loc.battery! > 20
                                ? const Color(0xFF16A34A)
                                : AppColors.error,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${loc.battery}%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (loc.timeRecorded != null)
                          Text(
                            _formatTimeAgo(loc.timeRecorded),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Interactive FlutterMap Container (or Blank / No GPS placeholder)
                  _buildMapArea(loc, targetPoint, petName),

                  // 4. Details Section (Address, Coordinates, Notes)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.displayAddress,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    loc.hasCoordinates
                                        ? 'GPS: ${loc.lat.toStringAsFixed(5)}, ${loc.lon.toStringAsFixed(5)}'
                                        : 'GPS: No GPS coordinates connected',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: loc.hasCoordinates
                                          ? AppColors.onSurfaceVariant
                                          : const Color(0xFF64748B),
                                      fontWeight: loc.hasCoordinates
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (loc.note != null && loc.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.outlineVariant.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.notes_rounded,
                                    size: 16, color: AppColors.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Notes: ${loc.note!}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 5. Actions Footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color:
                                    AppColors.outlineVariant.withOpacity(0.5),
                              ),
                              foregroundColor: AppColors.onSurface,
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        if (loc.hasCoordinates || loc.isLiveCollar) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminPetTrackingMapScreen(
                                      pet: widget.pet,
                                      initialLocation: loc,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.fullscreen_rounded, size: 18),
                              label: const Text('Fullscreen Map'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapArea(
      PetLocationResult loc, ll.LatLng targetPoint, String petName) {
    if (!loc.hasCoordinates && !loc.isLiveCollar) {
      return Container(
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gps_off_rounded,
                  size: 32,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No GPS Connected',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'This pet does not have an active GPS collar paired and no location coordinates were recorded for this report.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          FlutterMap(
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
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.18),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              petName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: loc.sourceColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            color: loc.sourceColor,
                            size: 38,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Map control: Recenter button
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'recenter_pet_map',
              onPressed: () {
                _mapController.move(targetPoint, 16.0);
              },
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 3,
              tooltip: 'Center on pet',
              child: const Icon(Icons.my_location_rounded,
                  size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'active':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'ACTIVE';
        break;
      case 'lost':
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        label = 'LOST';
        break;
      case 'archived':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'ARCHIVED';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = AppColors.onSurfaceVariant;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../core/app_colors.dart';

/// Renders a visual Geofence perimeter and Satellite GPS accuracy margin of error (±2.5m)
/// as circular layers around the pet's pinned location coordinates.
class PetGeofenceLayer extends StatelessWidget {
  final ll.LatLng center;
  final bool isGpsActive;
  final double marginOfErrorRadius; // in meters (represents ±2.5m GPS CEP satellite error)
  final double geofenceRadius; // in meters (represents geofence safe perimeter)

  const PetGeofenceLayer({
    super.key,
    required this.center,
    this.isGpsActive = true,
    this.marginOfErrorRadius = 4.5,
    this.geofenceRadius = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isGpsActive ? AppColors.primary : const Color(0xFF64748B);

    return CircleLayer(
      circles: [
        // 1. Outer Geofence Boundary / Safe Perimeter (18m radius)
        CircleMarker(
          point: center,
          radius: geofenceRadius,
          useRadiusInMeter: true,
          color: baseColor.withOpacity(0.08),
          borderColor: baseColor.withOpacity(0.40),
          borderStrokeWidth: 1.4,
        ),
        // 2. Satellite GPS Margin of Error Tolerance Zone (±2.5m)
        CircleMarker(
          point: center,
          radius: marginOfErrorRadius,
          useRadiusInMeter: true,
          color: baseColor.withOpacity(0.24),
          borderColor: baseColor.withOpacity(0.90),
          borderStrokeWidth: 2.0,
        ),
      ],
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PetLocationResult {
  final double lat;
  final double lon;
  final String sourceLabel;
  final String? recordedAt;

  const PetLocationResult({
    required this.lat,
    required this.lon,
    required this.sourceLabel,
    this.recordedAt,
  });
}

class PetLocationResolver {
  /// Resolves the best available coordinates for a lost pet report.
  /// Priority:
  /// 1. Report's numeric 'last_seen_lat' and 'last_seen_lon'
  /// 2. Pet's numeric 'last_seen_lat' and 'last_seen_lon'
  /// 3. Embedded regex coordinates in 'last_seen_address' or 'barangay'
  /// 4. Paired GPS collar telemetry from 'gps_locations' table
  /// 5. Direct pet table query for collar ID if not present in joined data
  static Future<PetLocationResult?> resolve({
    required Map<String, dynamic> report,
    Map<String, dynamic>? petData,
  }) async {
    final pet = petData ??
        (report['pets'] is Map<String, dynamic>
            ? report['pets'] as Map<String, dynamic>
            : null);

    // 1. Direct coordinates on report
    final double? rLat = (report['last_seen_lat'] as num?)?.toDouble();
    final double? rLon = (report['last_seen_lon'] as num?)?.toDouble();
    if (rLat != null && rLon != null) {
      return PetLocationResult(
        lat: rLat,
        lon: rLon,
        sourceLabel: 'Reported Location',
        recordedAt: report['reported_at']?.toString(),
      );
    }

    // 2. Direct coordinates on joined pet record
    final double? pLat = (pet?['last_seen_lat'] as num?)?.toDouble();
    final double? pLon = (pet?['last_seen_lon'] as num?)?.toDouble();
    if (pLat != null && pLon != null) {
      return PetLocationResult(
        lat: pLat,
        lon: pLon,
        sourceLabel: 'Last Seen Location',
        recordedAt: pet?['last_seen_at']?.toString() ??
            report['reported_at']?.toString(),
      );
    }

    // 3. Regex coordinates in last_seen_address, barangay, or pet's last_seen_address
    final addressText = [
      report['last_seen_address'],
      report['barangay'],
      pet?['last_seen_address'],
    ].where((e) => e != null).join(' ');

    final regExp = RegExp(
      r'Lat:\s*([-\d.]+),\s*(?:Lng|Lon):\s*([-\d.]+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(addressText);
    if (match != null) {
      final double? parsedLat = double.tryParse(match.group(1)!);
      final double? parsedLon = double.tryParse(match.group(2)!);
      if (parsedLat != null && parsedLon != null) {
        return PetLocationResult(
          lat: parsedLat,
          lon: parsedLon,
          sourceLabel: 'Reported GPS Pin',
          recordedAt: report['reported_at']?.toString(),
        );
      }
    }

    // 4. Paired collar lookup from joined pet or report
    String? collarId = (pet?['gps_id'] ?? report['gps_id'])?.toString().trim();

    // 5. If collarId is not in memory, query 'pets' table if pet_id is available
    if (collarId == null ||
        collarId.isEmpty ||
        collarId.toUpperCase() == 'N/A' ||
        collarId.toUpperCase() == 'NONE') {
      final petId = report['pet_id'] ?? pet?['pet_id'] ?? pet?['id'];
      if (petId != null) {
        try {
          final petRow = await Supabase.instance.client
              .from('pets')
              .select('gps_id')
              .eq('pet_id', petId)
              .maybeSingle();

          if (petRow != null) {
            final double? dbLat =
                (petRow['last_seen_lat'] as num?)?.toDouble();
            final double? dbLon =
                (petRow['last_seen_lon'] as num?)?.toDouble();
            if (dbLat != null && dbLon != null) {
              return PetLocationResult(
                lat: dbLat,
                lon: dbLon,
                sourceLabel: 'Last Seen Location',
              );
            }
            collarId = petRow['gps_id']?.toString().trim();
          }
        } catch (e) {
          debugPrint('[PetLocationResolver] Error checking pet record: $e');
        }
      }
    }

    // 6. Query 'gps_locations' if collarId is valid
    if (collarId != null &&
        collarId.isNotEmpty &&
        collarId.toUpperCase() != 'N/A' &&
        collarId.toUpperCase() != 'NONE') {
      try {
        final ping = await Supabase.instance.client
            .from('gps_locations')
            .select('lat, lon, recorded_at, is_online')
            .eq('gps_id', collarId)
            .order('recorded_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (ping != null) {
          final double? pingLat = (ping['lat'] as num?)?.toDouble();
          final double? pingLon = (ping['lon'] as num?)?.toDouble();
          if (pingLat != null && pingLon != null) {
            // Cache back into memory so immediate re-reads don't re-query
            report['last_seen_lat'] = pingLat;
            report['last_seen_lon'] = pingLon;

            // Persist back to database so future reads retain the pin even if collar is unpaired
            try {
              final reportId = report['report_id'];
              if (reportId != null &&
                  (report['last_seen_lat'] == null ||
                      report['last_seen_lon'] == null)) {
                Supabase.instance.client
                    .from('lost_reports')
                    .update({
                      'last_seen_lat': pingLat,
                      'last_seen_lon': pingLon,
                    })
                    .eq('report_id', reportId);
              }
            } catch (_) {}

            final isOnline = ping['is_online'] == true;
            return PetLocationResult(
              lat: pingLat,
              lon: pingLon,
              sourceLabel: isOnline
                  ? 'Live GPS Collar'
                  : 'GPS Collar (Last Known Location)',
              recordedAt: ping['recorded_at']?.toString(),
            );
          }
        }
      } catch (e) {
        debugPrint(
            '[PetLocationResolver] Error checking collar telemetry: $e');
      }
    }

    return null;
  }
}

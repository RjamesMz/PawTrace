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

    // 1. Paired collar lookup from joined pet, report, or 'pets' database table
    String? collarId = (pet?['gps_id'] ?? report['gps_id'])?.toString().trim();

    if (collarId == null ||
        collarId.isEmpty ||
        collarId.toUpperCase() == 'N/A' ||
        collarId.toUpperCase() == 'NONE') {
      final petId = report['pet_id'] ?? pet?['pet_id'] ?? pet?['id'];
      if (petId != null) {
        try {
          final petRow = await Supabase.instance.client
              .from('pets')
              .select('gps_id, last_seen_lat, last_seen_lon, last_seen_at')
              .eq('pet_id', petId)
              .maybeSingle();

          if (petRow != null) {
            collarId = petRow['gps_id']?.toString().trim();
          }
        } catch (e) {
          debugPrint('[PetLocationResolver] Error checking pet record: $e');
        }
      }
    }

    // If collarId is valid, query 'gps_locations' for the collar's true last known ping
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
            final rawRecordedAt = ping['recorded_at']?.toString();

            // Cache in memory for immediate re-reads
            report['last_seen_lat'] = pingLat;
            report['last_seen_lon'] = pingLon;

            // Sync back to database so future queries retain this pin
            try {
              final reportId = report['report_id'];
              if (reportId != null) {
                Supabase.instance.client
                    .from('lost_reports')
                    .update({
                      'last_seen_lat': pingLat,
                      'last_seen_lon': pingLon,
                    })
                    .eq('report_id', reportId);
              }
            } catch (_) {}

            bool isFresh = false;
            if (rawRecordedAt != null && rawRecordedAt.isNotEmpty) {
              try {
                DateTime dt = DateTime.parse(rawRecordedAt);
                if (!rawRecordedAt.endsWith('Z') && !rawRecordedAt.contains('+')) {
                  dt = DateTime.parse('${rawRecordedAt}Z');
                }
                final diff = DateTime.now().toUtc().difference(dt.toUtc());
                if (!diff.isNegative && diff.inSeconds <= 180) {
                  isFresh = true;
                }
              } catch (_) {}
            }

            return PetLocationResult(
              lat: pingLat,
              lon: pingLon,
              sourceLabel: isFresh
                  ? 'Live GPS Collar'
                  : 'GPS Collar (Last Known Location)',
              recordedAt: rawRecordedAt,
            );
          }
        }
      } catch (e) {
        debugPrint(
            '[PetLocationResolver] Error checking collar telemetry: $e');
      }
    }

    // 2. Direct coordinates on report
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

    // 3. Direct coordinates on joined pet record
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

    // 4. Regex coordinates in last_seen_address, barangay, or pet's last_seen_address
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

    return null;
  }
}

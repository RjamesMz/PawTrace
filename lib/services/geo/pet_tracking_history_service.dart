import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single GPS coordinate point in a tracking trail
class PetTrackPoint {
  final double lat;
  final double lon;
  final DateTime recordedAt;
  final int? battery;

  const PetTrackPoint({
    required this.lat,
    required this.lon,
    required this.recordedAt,
    this.battery,
  });

  ll.LatLng toLatLng() => ll.LatLng(lat, lon);
}

/// Activity segment: either Stationary / Rest (e.g. at home or resting) or Moving / Walk
class PetTrackSegment {
  final bool isMoving;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceMeters;
  final int stepCount;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final String address;
  final List<ll.LatLng> points;

  const PetTrackSegment({
    required this.isMoving,
    required this.startTime,
    required this.endTime,
    required this.distanceMeters,
    required this.stepCount,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.address,
    required this.points,
  });

  Duration get duration => endTime.difference(startTime);

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '$hours hr $minutes min';
    } else if (hours > 0) {
      return '$hours hr';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '${d.inSeconds} sec';
    }
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${distanceMeters.round()} m';
    }
  }
}

/// Full tracking history for a single day
class PetDailyTrack {
  final DateTime date;
  final String collarId;
  final List<ll.LatLng> points;
  final List<PetTrackSegment> segments;
  final double totalDistanceMeters;
  final Duration activeDuration;
  final Duration restDuration;

  const PetDailyTrack({
    required this.date,
    required this.collarId,
    required this.points,
    required this.segments,
    required this.totalDistanceMeters,
    required this.activeDuration,
    required this.restDuration,
  });

  String get formattedTotalDistance {
    if (totalDistanceMeters >= 1000) {
      final km = totalDistanceMeters / 1000.0;
      return '${km.toStringAsFixed(2)} km';
    } else {
      return '${totalDistanceMeters.round()} m';
    }
  }

  String get formattedActiveDuration {
    final hours = activeDuration.inHours;
    final minutes = activeDuration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class PetTrackingHistoryService {
  PetTrackingHistoryService._();
  static final PetTrackingHistoryService instance = PetTrackingHistoryService._();

  static final Map<String, String> _addressCache = {};

  /// Haversine formula to compute distance in meters between two coordinates
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Reverse-geocode with OSM Nominatim (cached in memory)
  Future<String> reverseGeocode(double lat, double lon) async {
    final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'PawTraceApp/1.0 (contact: support@pawtrace.app)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addressObj = data['address'] as Map<String, dynamic>?;
        if (addressObj != null) {
          final road = addressObj['road'] ??
              addressObj['pedestrian'] ??
              addressObj['suburb'] ??
              addressObj['neighbourhood'] ??
              addressObj['quarter'];
          final city = addressObj['city'] ??
              addressObj['town'] ??
              addressObj['municipality'] ??
              addressObj['county'];

          String formatted;
          if (road != null && city != null) {
            formatted = '$road, $city';
          } else if (road != null) {
            formatted = road.toString();
          } else if (city != null) {
            formatted = city.toString();
          } else {
            formatted = data['display_name']?.toString().split(',').take(2).join(',').trim() ??
                'Location (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})';
          }

          _addressCache[key] = formatted;
          return formatted;
        }
      }
    } catch (_) {}

    final fallback = 'Coordinates: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
    _addressCache[key] = fallback;
    return fallback;
  }

  /// Fetches GPS locations for a given collar on a specific calendar date (local day)
  Future<PetDailyTrack> fetchDailyTrack({
    required String collarId,
    required DateTime date,
    double? fallbackLat,
    double? fallbackLon,
  }) async {
    final startOfDayLocal = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDayLocal = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final startUtcIso = startOfDayLocal.toUtc().toIso8601String();
    final endUtcIso = endOfDayLocal.toUtc().toIso8601String();

    List<Map<String, dynamic>> rows = [];
    try {
      final res = await Supabase.instance.client
          .from('gps_locations')
          .select('lat, lon, recorded_at, battery_level, battery')
          .eq('gps_id', collarId)
          .gte('recorded_at', startUtcIso)
          .lte('recorded_at', endUtcIso)
          .order('recorded_at', ascending: true);
      if (res is List) {
        rows = List<Map<String, dynamic>>.from(res);
      }
    } catch (e) {
      debugPrint('[PetTrackingHistoryService] Fetch error: $e');
    }

    final rawPoints = <PetTrackPoint>[];
    for (final r in rows) {
      final rLat = (r['lat'] as num?)?.toDouble();
      final rLon = (r['lon'] as num?)?.toDouble();
      final rRecordedAt = r['recorded_at']?.toString();
      if (rLat != null && rLon != null && rRecordedAt != null) {
        DateTime dt = DateTime.tryParse(rRecordedAt) ?? DateTime.now();
        if (!rRecordedAt.endsWith('Z') && !rRecordedAt.contains('+')) {
          dt = DateTime.tryParse('${rRecordedAt}Z') ?? dt;
        }
        final bat = r['battery_level'] ?? r['battery'];
        rawPoints.add(
          PetTrackPoint(
            lat: rLat,
            lon: rLon,
            recordedAt: dt.toLocal(),
            battery: bat is num ? bat.toInt() : null,
          ),
        );
      }
    }

    // If no points were recorded on this day, check if fallbackLat/Lon is provided
    if (rawPoints.isEmpty) {
      if (fallbackLat != null && fallbackLon != null) {
        final address = await reverseGeocode(fallbackLat, fallbackLon);
        final singleSegment = PetTrackSegment(
          isMoving: false,
          startTime: startOfDayLocal,
          endTime: endOfDayLocal,
          distanceMeters: 0,
          stepCount: 0,
          startLat: fallbackLat,
          startLon: fallbackLon,
          endLat: fallbackLat,
          endLon: fallbackLon,
          address: address,
          points: [ll.LatLng(fallbackLat, fallbackLon)],
        );
        return PetDailyTrack(
          date: date,
          collarId: collarId,
          points: [ll.LatLng(fallbackLat, fallbackLon)],
          segments: [singleSegment],
          totalDistanceMeters: 0,
          activeDuration: Duration.zero,
          restDuration: const Duration(hours: 24),
        );
      }

      return PetDailyTrack(
        date: date,
        collarId: collarId,
        points: const [],
        segments: const [],
        totalDistanceMeters: 0,
        activeDuration: Duration.zero,
        restDuration: Duration.zero,
      );
    }

    final mapPoints = rawPoints.map((p) => p.toLatLng()).toList();
    final segments = await _segmentizePoints(rawPoints);

    double totalDist = 0;
    Duration activeDur = Duration.zero;
    Duration restDur = Duration.zero;

    for (final seg in segments) {
      totalDist += seg.distanceMeters;
      if (seg.isMoving) {
        activeDur += seg.duration;
      } else {
        restDur += seg.duration;
      }
    }

    return PetDailyTrack(
      date: date,
      collarId: collarId,
      points: mapPoints,
      segments: segments,
      totalDistanceMeters: totalDist,
      activeDuration: activeDur,
      restDuration: restDur,
    );
  }

  /// Groups sequential GPS points into stationary stops and active movement segments
  Future<List<PetTrackSegment>> _segmentizePoints(List<PetTrackPoint> points) async {
    if (points.isEmpty) return [];

    final segments = <PetTrackSegment>[];

    // Thresholds:
    // Any movement between points within 25 meters is treated as stationary/stay.
    // If movement > 25 meters, it counts as an active walk segment.
    List<PetTrackPoint> currentGroup = [points.first];
    bool isCurrentMoving = false;

    for (int i = 1; i < points.length; i++) {
      final prev = currentGroup.last;
      final curr = points[i];
      final dist = calculateDistanceMeters(prev.lat, prev.lon, curr.lat, curr.lon);

      final isPointMoving = dist > 25.0;

      if (currentGroup.length == 1) {
        isCurrentMoving = isPointMoving;
        currentGroup.add(curr);
      } else if (isPointMoving == isCurrentMoving) {
        currentGroup.add(curr);
      } else {
        // State changed: finish current segment
        segments.add(await _buildSegment(currentGroup, isCurrentMoving));
        currentGroup = [prev, curr];
        isCurrentMoving = isPointMoving;
      }
    }

    if (currentGroup.isNotEmpty) {
      segments.add(await _buildSegment(currentGroup, isCurrentMoving));
    }

    return segments;
  }

  Future<PetTrackSegment> _buildSegment(
    List<PetTrackPoint> group,
    bool isMoving,
  ) async {
    final start = group.first;
    final end = group.last;

    double segmentDistance = 0.0;
    for (int i = 1; i < group.length; i++) {
      segmentDistance += calculateDistanceMeters(
        group[i - 1].lat,
        group[i - 1].lon,
        group[i].lat,
        group[i].lon,
      );
    }

    // Step estimate: approx 1.35 steps per meter for dogs/cats
    final stepCount = (segmentDistance * 1.35).round();
    final address = await reverseGeocode(end.lat, end.lon);

    return PetTrackSegment(
      isMoving: isMoving,
      startTime: start.recordedAt,
      endTime: end.recordedAt,
      distanceMeters: segmentDistance,
      stepCount: stepCount,
      startLat: start.lat,
      startLon: start.lon,
      endLat: end.lat,
      endLon: end.lon,
      address: address,
      points: group.map((p) => p.toLatLng()).toList(),
    );
  }
}


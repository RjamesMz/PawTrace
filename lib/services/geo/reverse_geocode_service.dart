import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_constants.dart';

/// Reverse geocoding service using OpenStreetMap Nominatim.
/// Translates geographic coordinates (lat, lon) into accurate, human-readable
/// addresses and barangay names (especially for Catanduanes / Philippines).
class ReverseGeocodeService {
  ReverseGeocodeService._();

  static final Map<String, String> _cache = {};
  static void clearCache() => _cache.clear();

  /// Matches common Philippine residential subdivision, housing project,
  /// purok, or sitio naming patterns (e.g., "San Isidro Village", "Teachers Village",
  /// "Capitol Heights", "Villa Subdivision", "St. Jude Homes", "Purok 1").
  static final RegExp _subAreaRegex = RegExp(
    r'\b(?:village|subdivision|subd\.?|heights|homes|estates?|residences?|condominium|compound|phase\s*\d+|block\s*\d+|sector\s*\d+|sitio|purok|zone\s*\d+)\b',
    caseSensitive: false,
  );

  /// Automatically identifies whether an OSM locality name is a private residential
  /// subdivision, housing project, or purok rather than an administrative barangay.
  static bool _isSubArea(String name) => _subAreaRegex.hasMatch(name.trim());

  /// Automatically resolves the true administrative barangay from OSM address details.
  /// Subdivisions / puroks (tagged as 'quarter' or 'neighbourhood') automatically
  /// defer to the official administrative barangay (tagged as 'village' or 'suburb').
  static String? _resolveBarangay(Map<String, dynamic> address) {
    final quarter = address['quarter']?.toString().trim();
    final neighbourhood = address['neighbourhood']?.toString().trim();
    final locality = address['locality']?.toString().trim();
    final village = address['village']?.toString().trim();
    final suburb = address['suburb']?.toString().trim();
    final residential = address['residential']?.toString().trim();
    final hamlet = address['hamlet']?.toString().trim();

    String? candidate;

    // 1. If quarter is present, check if it's a subdivision/sub-area
    if (quarter != null && quarter.isNotEmpty) {
      if (_isSubArea(quarter) && village != null && village.isNotEmpty) {
        candidate = village;
      } else {
        candidate = quarter;
      }
    }

    // 2. If candidate still unset, check neighbourhood
    if (candidate == null && neighbourhood != null && neighbourhood.isNotEmpty) {
      if (_isSubArea(neighbourhood) && village != null && village.isNotEmpty) {
        candidate = village;
      } else {
        candidate = neighbourhood;
      }
    }

    // 3. Fallback to administrative village, suburb, locality, or residential
    candidate ??= (village != null && village.isNotEmpty ? village : null) ??
        (suburb != null && suburb.isNotEmpty ? suburb : null) ??
        (locality != null && locality.isNotEmpty ? locality : null) ??
        (residential != null && residential.isNotEmpty ? residential : null) ??
        (hamlet != null && hamlet.isNotEmpty ? hamlet : null);

    if (candidate == null || candidate.isEmpty) return null;

    // 4. Automatic canonical matching against configured app barangays if present
    for (final known in AppConstants.barangays) {
      final lowerCand = candidate.toLowerCase();
      final lowerKnown = known.toLowerCase();
      if (lowerCand == lowerKnown ||
          lowerCand.startsWith('$lowerKnown ') ||
          lowerCand.endsWith(' $lowerKnown') ||
          lowerCand == '$lowerKnown proper') {
        return known;
      }
    }

    return candidate;
  }

  /// Looks up the human-readable address / barangay for [lat] and [lon].
  /// Returns a clean formatted string like "Brgy. Palnab Del Sur, Virac" or null if offline.
  static Future<String?> reverseGeocode(double lat, double lon) async {
    final cacheKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&addressdetails=1&zoom=18',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'PetTraceApp/1.0 (contact: support@pettrace.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final address = data['address'] as Map<String, dynamic>?;
          if (address != null) {
            // 1. Generic POI / Landmark / Institution extraction
            String? poi;
            final rawName = data['name']?.toString().trim();
            final osmClass = data['class']?.toString().toLowerCase();
            if (rawName != null &&
                rawName.isNotEmpty &&
                osmClass != 'highway' &&
                osmClass != 'boundary') {
              poi = rawName;
            }

            poi ??= address['amenity']?.toString() ??
                address['university']?.toString() ??
                address['college']?.toString() ??
                address['school']?.toString() ??
                address['hospital']?.toString() ??
                address['clinic']?.toString() ??
                address['place_of_worship']?.toString() ??
                address['tourism']?.toString() ??
                address['leisure']?.toString() ??
                (address['building'] != null && address['building'] != 'yes'
                    ? address['building'].toString()
                    : null);

            if (poi != null) {
              poi = poi.trim();
              if (poi.isEmpty) poi = null;
            }

            // 2. Generic administrative barangay resolution
            final String? barangay = _resolveBarangay(address);

            final String? town = address['town']?.toString() ??
                address['city']?.toString() ??
                address['municipality']?.toString() ??
                address['county']?.toString();

            final String? road = address['road']?.toString();

            final prefix = (barangay != null &&
                    (barangay.toLowerCase().startsWith('brgy') ||
                        barangay.toLowerCase().startsWith('barangay')))
                ? ''
                : 'Brgy. ';

            String formatted;
            if (poi != null && poi.isNotEmpty) {
              if (barangay != null &&
                  barangay.isNotEmpty &&
                  town != null &&
                  town.isNotEmpty) {
                formatted = '$poi, $prefix$barangay, $town';
              } else if (town != null && town.isNotEmpty) {
                formatted = '$poi, $town';
              } else if (barangay != null && barangay.isNotEmpty) {
                formatted = '$poi, $prefix$barangay';
              } else {
                formatted = poi;
              }
            } else if (road != null &&
                road.isNotEmpty &&
                barangay != null &&
                barangay.isNotEmpty &&
                !road.toLowerCase().contains(barangay.toLowerCase())) {
              formatted = town != null && town.isNotEmpty
                  ? '$road, $prefix$barangay, $town'
                  : '$road, $prefix$barangay';
            } else if (barangay != null && barangay.isNotEmpty) {
              formatted = town != null && town.isNotEmpty
                  ? '$prefix$barangay, $town'
                  : '$prefix$barangay';
            } else if (town != null && town.isNotEmpty) {
              formatted = '$town, Catanduanes';
            } else {
              final displayName = data['display_name']?.toString() ?? '';
              final parts = displayName.split(',');
              formatted = parts.take(2).map((s) => s.trim()).join(', ');
            }

            if (formatted.isNotEmpty) {
              _cache[cacheKey] = formatted;
              return formatted;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ReverseGeocode] Notice: $e');
    }

    return null;
  }
}

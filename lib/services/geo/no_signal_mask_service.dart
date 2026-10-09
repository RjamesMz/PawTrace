import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

/// Service that parses and manages the Catanduanes "No Signal" gray mask
/// derived from Speedtest by Ookla Open Data (CC BY-NC-SA 4.0).
class NoSignalMaskService {
  NoSignalMaskService._();
  static final NoSignalMaskService instance = NoSignalMaskService._();

  bool _isLoaded = false;
  final List<Polygon> _polygons = [];
  final List<List<ll.LatLng>> _outerRings = [];

  bool get isLoaded => _isLoaded;
  List<Polygon> get polygons => List.unmodifiable(_polygons);

  /// Loads `assets/data/gray_mask.geojson` asynchronously.
  /// Fails gracefully if the file is missing or invalid.
  Future<void> loadMask() async {
    if (_isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/gray_mask.geojson');
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final features = data['features'] as List<dynamic>? ?? [];
      _polygons.clear();
      _outerRings.clear();

      for (final f in features) {
        final geom = f['geometry'] as Map<String, dynamic>?;
        if (geom == null) continue;

        final type = geom['type'] as String?;
        final coordinates = geom['coordinates'] as List<dynamic>?;
        if (coordinates == null) continue;

        if (type == 'Polygon') {
          _parsePolygon(coordinates);
        } else if (type == 'MultiPolygon') {
          for (final polyCoords in coordinates) {
            _parsePolygon(polyCoords as List<dynamic>);
          }
        }
      }

      _isLoaded = true;
      debugPrint('[NoSignalMaskService] Loaded ${_polygons.length} polygons from gray_mask.geojson');
    } catch (e) {
      debugPrint('[NoSignalMaskService] Warning: Could not load gray_mask.geojson: $e');
      // Continues gracefully without blocking the map
    }
  }

  void _parsePolygon(List<dynamic> rings) {
    if (rings.isEmpty) return;
    final outer = (rings[0] as List<dynamic>).map((pt) {
      final lon = (pt[0] as num).toDouble();
      final lat = (pt[1] as num).toDouble();
      return ll.LatLng(lat, lon);
    }).toList();

    if (outer.isEmpty) return;
    _outerRings.add(outer);

    List<List<ll.LatLng>> holes = [];
    if (rings.length > 1) {
      for (int i = 1; i < rings.length; i++) {
        final hole = (rings[i] as List<dynamic>).map((pt) {
          final lon = (pt[0] as num).toDouble();
          final lat = (pt[1] as num).toDouble();
          return ll.LatLng(lat, lon);
        }).toList();
        if (hole.isNotEmpty) holes.add(hole);
      }
    }

    _polygons.add(
      Polygon(
        points: outer,
        holePointsList: holes.isNotEmpty ? holes : null,
        color: const Color(0x8C777777), // #777 with ~0.55 opacity
        borderColor: Colors.transparent,
        borderStrokeWidth: 0,
      ),
    );
  }

  /// Ray-casting point-in-polygon check.
  /// Returns true if [lat, lon] falls inside any outer ring of the no-signal mask.
  bool isInsideNoSignalZone(double lat, double lon) {
    if (!_isLoaded || _outerRings.isEmpty) return false;
    for (final ring in _outerRings) {
      if (_rayCast(lat, lon, ring)) {
        return true;
      }
    }
    return false;
  }

  bool _rayCast(double lat, double lon, List<ll.LatLng> ring) {
    int i, j = ring.length - 1;
    bool inPoly = false;
    for (i = 0; i < ring.length; i++) {
      if ((ring[i].longitude < lon && ring[j].longitude >= lon ||
              ring[j].longitude < lon && ring[i].longitude >= lon) &&
          (ring[i].latitude <= lat || ring[j].latitude <= lat)) {
        if (ring[i].latitude +
                (lon - ring[i].longitude) /
                    (ring[j].longitude - ring[i].longitude) *
                    (ring[j].latitude - ring[i].latitude) <
            lat) {
          inPoly = !inPoly;
        }
      }
      j = i;
    }
    return inPoly;
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_analytics_service.dart';
import 'pet_location_resolver.dart';

/// A single map pin for an active lost pet report.
class LostPetPin {
  final String petName;
  final double lat;
  final double lon;
  final String? reportId;
  final String? photoUrl;
  final String? breed;
  final String? species;
  final String? address;
  final String? sourceLabel;
  final String? recordedAt;
  final Map<String, dynamic>? rawReport;

  const LostPetPin({
    required this.petName,
    required this.lat,
    required this.lon,
    this.reportId,
    this.photoUrl,
    this.breed,
    this.species,
    this.address,
    this.sourceLabel,
    this.recordedAt,
    this.rawReport,
  });
}

/// Builds the pins for the lost pets map.
///
/// Resolves active lost reports to coordinates via [PetLocationResolver]
/// (GPS collar telemetry, reported pin coordinates, or address).
class ActiveLostPetPinsService {
  /// [barangay] optionally restricts results to one barangay (barangay admins).
  static Future<List<LostPetPin>> fetch({String? barangay}) async {
    try {
      final client = Supabase.instance.client;
      var query = client
          .from('lost_reports')
          .select('*, pets(*), owner_id(*)')
          .eq('status', 'active');
      if (barangay != null && barangay.isNotEmpty) {
        if (barangay.toLowerCase() == 'calatagan') {
          query = query.inFilter('barangay', ['Calatagan', 'San Isidro Village']);
        } else {
          query = query.eq('barangay', barangay);
        }
      }
      final data = await query.order('reported_at', ascending: false);
      final reports = List<Map<String, dynamic>>.from(data)
          .where((r) => !AdminAnalyticsService.isReportFound(r))
          .toList();

      final pins = await Future.wait(reports.map((r) async {
        final pet = r['pets'] is Map<String, dynamic>
            ? r['pets'] as Map<String, dynamic>
            : null;

        try {
          final res = await PetLocationResolver.resolve(
            report: r,
            petData: pet,
          );
          if (res == null) return null;

          final petName = (pet?['name'] ?? r['pet_name'] ?? 'Pet').toString();
          final photoUrl = pet?['photo_url']?.toString() ??
              pet?['image_url']?.toString() ??
              r['pet_photo_url']?.toString() ??
              r['photo_url']?.toString();
          final breed = pet?['breed']?.toString() ?? r['breed']?.toString();
          final species =
              pet?['species']?.toString() ?? r['species']?.toString();
          var address =
              r['last_seen_address']?.toString() ?? r['barangay']?.toString();

          // Sanitize legacy or mislabeled subdivision addresses
          if (address != null &&
              (address.contains('San Isidro Village') ||
                  r['barangay'] == 'San Isidro Village')) {
            address = 'Catanduanes State University, Brgy. Calatagan, Virac';
            // Self-heal authenticated report if owner is logged in
            final currentUserId = client.auth.currentUser?.id;
            if (currentUserId != null && currentUserId == r['owner_id']) {
              client.from('lost_reports').update({
                'barangay': 'Calatagan',
                'last_seen_address':
                    'Catanduanes State University, Brgy. Calatagan, Virac',
              }).eq('report_id', r['report_id']).then((_) {}).catchError((_) {});
            }
          }

          return LostPetPin(
            petName: petName,
            lat: res.lat,
            lon: res.lon,
            reportId: r['report_id']?.toString() ?? r['id']?.toString(),
            photoUrl: photoUrl,
            breed: breed,
            species: species,
            address: address,
            sourceLabel: res.sourceLabel,
            recordedAt: res.recordedAt,
            rawReport: r,
          );
        } catch (e) {
          debugPrint('[ActiveLostPetPins] resolution failed for report: $e');
          return null;
        }
      }));

      return pins.whereType<LostPetPin>().toList();
    } catch (e) {
      debugPrint('[ActiveLostPetPins] fetch failed: $e');
      return const [];
    }
  }
}

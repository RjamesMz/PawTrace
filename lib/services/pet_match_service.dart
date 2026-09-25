import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pet_embedding_service.dart';

/// Result of matching a scanned pet against active lost reports in the database.
class PetMatchResult {
  final String reportId;
  final String? petId;
  final String name;
  final String breed;
  final String species;
  final String color;
  final String barangay;
  final String photoUrl;
  final String ownerFullName;
  final String ownerPhone;
  final double similarity;
  final Map<String, dynamic> rawData;

  const PetMatchResult({
    required this.reportId,
    this.petId,
    required this.name,
    required this.breed,
    required this.species,
    required this.color,
    required this.barangay,
    required this.photoUrl,
    required this.ownerFullName,
    required this.ownerPhone,
    required this.similarity,
    required this.rawData,
  });

  int get percent => (similarity * 100).round();
  String get percentString => (similarity * 100).toStringAsFixed(1);
}

/// Fetches active lost reports with stored pet embeddings and finds the closest visual matches.
class PetMatchService {
  PetMatchService._();
  static final PetMatchService instance = PetMatchService._();

  Future<List<PetMatchResult>> findMatches(
    List<double> queryEmbedding, {
    required bool isDog,
    int topN = 5,
    double minSimilarity = 0.40, // lowered from 0.50 — classification-based
    // cosine similarity for the same pet typically falls in the 0.4-0.7 range.
  }) async {
    final results = await _findMatchesFiltered(
      queryEmbedding,
      isDog: isDog,
      topN: topN,
      minSimilarity: minSimilarity,
      strictSpecies: true,
    );

    // Fallback: if strict species filter yields nothing, retry without the
    // species constraint at a higher threshold (0.55) to catch edge cases
    // where detectSpecies() misclassified the scanned photo.
    if (results.isEmpty) {
      debugPrint(
          '[PawTrace] No matches with strict species filter — retrying without species filter');
      return _findMatchesFiltered(
        queryEmbedding,
        isDog: isDog,
        topN: topN,
        minSimilarity: 0.55,
        strictSpecies: false,
      );
    }

    return results;
  }

  Future<List<PetMatchResult>> _findMatchesFiltered(
    List<double> queryEmbedding, {
    required bool isDog,
    required int topN,
    required double minSimilarity,
    required bool strictSpecies,
  }) async {
    final data = await Supabase.instance.client
        .from('lost_reports')
        .select('report_id, pet_id, pets(*), owner_id(*)')
        .eq('status', 'active');

    final List<Map<String, dynamic>> reports =
        List<Map<String, dynamic>>.from(data);

    final results = <PetMatchResult>[];

    for (final report in reports) {
      final petData = report['pets'];
      if (petData == null || petData is! Map<String, dynamic>) continue;

      final species =
          (petData['species'] as String? ?? '').trim().toLowerCase();

      // Apply species filter only in strict mode
      if (strictSpecies) {
        if (isDog && species != 'dog') continue;
        if (!isDog && species != 'cat') continue;
      }

      final rawEmb = petData['embedding'];
      if (rawEmb == null) continue;

      List<dynamic> embList;
      if (rawEmb is String) {
        embList = jsonDecode(rawEmb) as List<dynamic>;
      } else if (rawEmb is List) {
        embList = rawEmb;
      } else {
        continue;
      }

      final stored =
          List<double>.from(embList.map((v) => (v as num).toDouble()));
      final sim = PetEmbeddingService.cosineSimilarity(queryEmbedding, stored);
      debugPrint(
          '[PawTrace] ${petData['name']} (${petData['species']}) sim=${sim.toStringAsFixed(3)}');

      if (sim >= minSimilarity) {
        // 'owner_id' is the FK-hint alias; fall back to 'users' key for safety
        final userData = (report['owner_id'] is Map<String, dynamic>
            ? report['owner_id'] as Map<String, dynamic>
            : (report['users'] is Map<String, dynamic>
                ? report['users'] as Map<String, dynamic>
                : (petData['users'] is Map<String, dynamic>
                    ? petData['users'] as Map<String, dynamic>
                    : null)));

        String ownerName = '';
        if (userData != null) {
          final fName = (userData['first_name'] as String? ?? '').trim();
          final mName = (userData['middle_name'] as String? ?? '').trim();
          final lName = (userData['surname'] as String? ?? '').trim();
          final suffix = (userData['suffix'] as String? ?? '').trim();

          final parts = [
            fName,
            if (mName.isNotEmpty) mName,
            lName,
            if (suffix.isNotEmpty) suffix
          ].where((p) => p.isNotEmpty).toList();
          ownerName = parts.join(' ');
          if (ownerName.isEmpty) {
            ownerName = (userData['full_name'] as String? ?? '').trim();
          }
        }
        final ownerPhone = (userData?['phone'] as String? ?? '').trim();

        results.add(
          PetMatchResult(
            reportId: (report['report_id'] ?? '').toString(),
            petId: (petData['pet_id'] ?? '').toString(),
            name: (petData['name'] as String? ?? 'Unknown Pet').trim(),
            breed: (petData['breed'] as String? ?? 'Unknown Breed').trim(),
            species: (petData['species'] as String? ?? (isDog ? 'Dog' : 'Cat'))
                .trim(),
            color: (petData['color'] as String? ?? '').trim(),
            barangay: (petData['barangay'] as String? ?? '').trim(),
            photoUrl: (petData['photo_url'] as String? ?? '').trim(),
            ownerFullName: ownerName.isNotEmpty ? ownerName : 'Anonymous Owner',
            ownerPhone: ownerPhone,
            similarity: sim,
            rawData: report,
          ),
        );
      }
    }

    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(topN).toList();
  }
}

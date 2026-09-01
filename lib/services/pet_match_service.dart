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
    double minSimilarity = 0.50,
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
      if (isDog && species != 'dog') continue;
      if (!isDog && species != 'cat') continue;

      final rawEmb = petData['embedding'];
      if (rawEmb == null) continue;

      final stored =
          List<double>.from((rawEmb as List).map((v) => (v as num).toDouble()));
      final sim = PetEmbeddingService.cosineSimilarity(queryEmbedding, stored);

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

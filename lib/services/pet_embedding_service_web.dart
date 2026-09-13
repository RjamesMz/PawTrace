// Web stub for PetEmbeddingService — TFLite and dart:ffi are not available
// on Flutter Web, so all methods return safe "not available" fallbacks.
import 'package:flutter/foundation.dart';

/// Stub result used on web where TFLite is unavailable.
class PetClassificationResult {
  final bool isDogOrCat;
  final String detectedSpecies;
  final String label;
  final double confidence;
  final int classIndex;
  final String? errorMessage;

  const PetClassificationResult({
    required this.isDogOrCat,
    required this.detectedSpecies,
    required this.label,
    required this.confidence,
    required this.classIndex,
    this.errorMessage,
  });
}

/// Web stub — no AI classification available on web.
class PetEmbeddingService {
  PetEmbeddingService._();
  static final PetEmbeddingService instance = PetEmbeddingService._();

  Future<void> loadModels() async {
    debugPrint('[PawTrace] TFLite not available on web — skipping model load.');
  }

  Future<Map<String, dynamic>> detectSpecies(dynamic imageFile) async {
    return {
      'label': 'Not Available',
      'isAccepted': false,
      'isDog': false,
      'isCat': false,
      'isAspin': false,
      'isPuspin': false,
      'confidence': 0.0,
    };
  }

  Future<PetClassificationResult> classifyImage(dynamic imageFile) async {
    return const PetClassificationResult(
      isDogOrCat: false,
      detectedSpecies: 'Unknown',
      label: 'AI scan not available on web',
      confidence: 0,
      classIndex: -1,
      errorMessage: 'AI scan is only available on mobile.',
    );
  }

  Future<List<double>?> extractEmbedding(dynamic imageFile) async => null;

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  void dispose() {}
}

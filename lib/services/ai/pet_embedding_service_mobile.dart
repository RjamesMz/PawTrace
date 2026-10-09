// PetTrace AI Service — server-backed implementation.
//
// All AI inference (species detection + DINOv2 embedding) is delegated to the
// PetTrace AI Server (FastAPI + YOLOv11 + DINOv2) running on the local laptop.
//
// The server URL is configured via [PetEmbeddingService.serverUrl].
// Change it to your ngrok URL when testing on a real device over the internet.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Typed exception for server unavailability ───────────────────────────────

/// Thrown when the PetTrace AI server cannot be reached.
/// The UI can catch this specifically to show a maintenance message.
class PetTraceServerException implements Exception {
  final String message;
  const PetTraceServerException([this.message = 'AI server is unreachable.']);

  @override
  String toString() => 'PetTraceServerException: $message';
}

/// Backward compatibility alias
typedef PawTraceServerException = PetTraceServerException;

// ─── Public result type (unchanged API) ──────────────────────────────────────

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

// ─── Service ─────────────────────────────────────────────────────────────────

class PetEmbeddingService {
  PetEmbeddingService._();
  static final PetEmbeddingService instance = PetEmbeddingService._();

  /// Fallback URL used if Supabase config cannot be fetched.
  /// Update this to your local IP for development without internet.
  static const String _fallbackUrl = 'http://192.168.1.5:8000';

  /// Cached server URL — fetched from Supabase `app_config` on first use.
  String? _resolvedUrl;

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Fetches the AI server URL from Supabase `app_config` table.
  /// Caches the result for the rest of the session.
  Future<String> _resolveServerUrl() async {
    if (_resolvedUrl != null) return _resolvedUrl!;

    try {
      final row = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'ai_server_url')
          .maybeSingle();

      final url = (row?['value'] as String?)?.trim();
      if (url != null && url.isNotEmpty) {
        _resolvedUrl = url;
        debugPrint('[PetTrace] AI server URL loaded from Supabase: $url');
        return url;
      }
    } catch (e) {
      debugPrint('[PetTrace] Could not fetch server URL from Supabase: $e');
    }

    debugPrint('[PetTrace] Using fallback server URL: $_fallbackUrl');
    _resolvedUrl = _fallbackUrl;
    return _fallbackUrl;
  }

  /// Clears the cached URL so the next call re-fetches from Supabase.
  /// Call this if you update the URL in Supabase and want the app to pick it
  /// up without restarting.
  void clearUrlCache() => _resolvedUrl = null;

  Future<Uri> _uri(String path) async =>
      Uri.parse('${await _resolveServerUrl()}$path');


  /// Posts [imageFile] as multipart to [path] and returns the decoded JSON.
  ///
  /// Includes automatic retry for cold starts, transient socket resets, and
  /// temporary gateway hiccups so users don't see false "server down" alerts.
  /// Throws [PetTraceServerException] when the server genuinely cannot be reached.
  Future<Map<String, dynamic>> _post(String path, File imageFile) async {
    const int maxAttempts = 2;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final uri = await _uri(path);
        final request = http.MultipartRequest('POST', uri);
        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );
        final streamed =
            await request.send().timeout(const Duration(seconds: 35));
        final body = await streamed.stream.bytesToString();
        if (streamed.statusCode != 200) {
          debugPrint('[PetTrace] Server error ${streamed.statusCode}: $body');
          if (attempt < maxAttempts &&
              (streamed.statusCode == 502 ||
                  streamed.statusCode == 503 ||
                  streamed.statusCode == 504)) {
            debugPrint(
                '[PetTrace] Gateway/cold start (${streamed.statusCode}) on attempt $attempt/$maxAttempts. Retrying in 1.2s...');
            await Future.delayed(const Duration(milliseconds: 1200));
            continue;
          }
          throw PetTraceServerException(
              'Server returned status ${streamed.statusCode}.');
        }
        return jsonDecode(body) as Map<String, dynamic>;
      } on SocketException catch (e) {
        debugPrint(
            '[PetTrace] SocketException ($path, attempt $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) {
          debugPrint('[PetTrace] Retrying after socket disconnect in 1.2s...');
          await Future.delayed(const Duration(milliseconds: 1200));
          continue;
        }
        throw const PetTraceServerException(
            'Could not connect to the AI server. It may be offline.');
      } on http.ClientException catch (e) {
        debugPrint(
            '[PetTrace] HTTP client error ($path, attempt $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) {
          debugPrint('[PetTrace] Retrying after client error in 1.2s...');
          await Future.delayed(const Duration(milliseconds: 1200));
          continue;
        }
        throw const PetTraceServerException(
            'Could not connect to the AI server. It may be offline.');
      } catch (e) {
        if (e is PetTraceServerException) {
          rethrow;
        }
        final msg = e.toString();
        debugPrint(
            '[PetTrace] Server call failed ($path, attempt $attempt/$maxAttempts): $msg');
        if (msg.contains('TimeoutException') || msg.contains('timed out')) {
          if (attempt < maxAttempts) {
            debugPrint('[PetTrace] Timeout on attempt $attempt, retrying...');
            await Future.delayed(const Duration(milliseconds: 1000));
            continue;
          }
          throw const PetTraceServerException(
              'The AI server did not respond in time. Please try again.');
        }
        rethrow;
      }
    }
    throw const PetTraceServerException(
        'Could not connect to the AI server. It may be offline.');
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Loads models — no-op for the server-backed implementation.
  /// Kept for API compatibility with callers that await this.
  Future<void> loadModels() async {
    debugPrint('[PetTrace] Server-backed mode — no local models to load.');
  }

  /// Calls /detect on the AI server to classify the pet species.
  ///
  /// Returns a map with keys: isAccepted, species, confidence, isDog, isCat.
  /// Throws [PetTraceServerException] if the server is unreachable.
  Future<Map<String, dynamic>> detectSpecies(File imageFile) async {
    // _post now throws PetTraceServerException on failure — let it propagate.
    final result = await _post('/detect', imageFile);

    final species    = result['species'] as String? ?? '';
    final isAccepted = result['isAccepted'] as bool? ?? false;
    final isDog      = result['isDog']      as bool? ?? false;
    final isCat      = result['isCat']      as bool? ?? false;
    final confidence = (result['confidence'] as num? ?? 0.0).toDouble();

    debugPrint('[PetTrace] detectSpecies: $species (conf=${confidence.toStringAsFixed(2)})');

    return {
      'label':      isAccepted ? species : 'Not a Pet',
      'breed':      species,
      'isAccepted': isAccepted,
      'isDog':      isDog,
      'isCat':      isCat,
      'isAspin':    false,   // server does not distinguish aspin/puspin
      'isPuspin':   false,
      'confidence': confidence,
    };
  }

  /// Calls /embed on the AI server to get the DINOv2 embedding.
  ///
  /// Returns a 768-dim L2-normalised list, or null if no pet was detected.
  /// Throws [PetTraceServerException] if the server is unreachable.
  Future<List<double>?> extractEmbedding(File imageFile) async {
    // _post throws PetTraceServerException on server failure — let it propagate.
    final result = await _post('/embed', imageFile);

    final isAccepted = result['isAccepted'] as bool? ?? false;
    if (!isAccepted) {
      debugPrint('[PetTrace] extractEmbedding: no pet detected by server.');
      return null;
    }

    final raw = result['embedding'];
    if (raw == null) return null;

    final embedding = List<double>.from((raw as List).map((v) => (v as num).toDouble()));
    debugPrint('[PetTrace] extractEmbedding: ${embedding.length}-dim DINOv2 vector received.');
    return embedding;
  }

  /// Cosine similarity between two L2-normalised vectors.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  /// Embeds pets in the Supabase pets table using DINOv2 via the server.
  /// By default, only processes pets missing an embedding (`forceAll: false`).
  Future<int> reEmbedAllPets({
    bool forceAll = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final supabase = Supabase.instance.client;
    var query = supabase
        .from('pets')
        .select('pet_id, photo_url, embedding');

    if (!forceAll) {
      query = query.filter('embedding', 'is', null);
    }

    final rows = await query.order('created_at', ascending: false);

    final pets = List<Map<String, dynamic>>.from(rows);
    if (pets.isEmpty) {
      debugPrint('[PetTrace] All pets already have embeddings. Skipping background sync.');
      return 0;
    }
    int done = 0;

    for (final pet in pets) {
      final photoUrl = (pet['photo_url'] as String? ?? '').trim();
      final petId    = pet['pet_id']?.toString();
      if (photoUrl.isEmpty || petId == null) continue;

      try {
        final httpClient = HttpClient();
        final request  = await httpClient.getUrl(Uri.parse(photoUrl));
        final response = await request.close();
        final bytes    = await response.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
        httpClient.close();

        final tmpFile = File('${Directory.systemTemp.path}/pettrace_reembed_$petId.jpg');
        await tmpFile.writeAsBytes(bytes);

        final embedding = await extractEmbedding(tmpFile);
        await tmpFile.delete();

        if (embedding != null) {
          await supabase.from('pets').update({'embedding': embedding}).eq('pet_id', petId);
          done++;
          debugPrint('[PetTrace] Re-embedded pet $petId ($done/${pets.length})');
        }
      } catch (e) {
        debugPrint('[PetTrace] Re-embed failed for pet $petId: $e');
      }

      onProgress?.call(done, pets.length);
    }

    debugPrint('[PetTrace] Re-embed complete: $done/${pets.length} pets updated');
    return done;
  }

  void dispose() {
    // No local resources to free in server-backed mode.
  }
}

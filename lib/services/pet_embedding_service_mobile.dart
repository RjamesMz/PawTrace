// PawTrace AI Service — server-backed implementation.
//
// All AI inference (species detection + DINOv2 embedding) is delegated to the
// PawTrace AI Server (FastAPI + YOLOv11 + DINOv2) running on the local laptop.
//
// The server URL is configured via [PetEmbeddingService.serverUrl].
// Change it to your ngrok URL when testing on a real device over the internet.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Typed exception for server unavailability ───────────────────────────────

/// Thrown when the PawTrace AI server cannot be reached.
/// The UI can catch this specifically to show a maintenance message.
class PawTraceServerException implements Exception {
  final String message;
  const PawTraceServerException([this.message = 'AI server is unreachable.']);

  @override
  String toString() => 'PawTraceServerException: $message';
}

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
        debugPrint('[PawTrace] AI server URL loaded from Supabase: $url');
        return url;
      }
    } catch (e) {
      debugPrint('[PawTrace] Could not fetch server URL from Supabase: $e');
    }

    debugPrint('[PawTrace] Using fallback server URL: $_fallbackUrl');
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
  /// Throws [PawTraceServerException] when the server cannot be reached
  /// (connection refused, timeout, or non-200 response).
  Future<Map<String, dynamic>> _post(String path, File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', await _uri(path));
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        debugPrint('[PawTrace] Server error ${streamed.statusCode}: $body');
        throw PawTraceServerException(
            'Server returned status ${streamed.statusCode}.');
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } on PawTraceServerException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('[PawTrace] Connection refused ($path): $e');
      throw const PawTraceServerException(
          'Could not connect to the AI server. It may be offline.');
    } on http.ClientException catch (e) {
      debugPrint('[PawTrace] HTTP client error ($path): $e');
      throw const PawTraceServerException(
          'Could not connect to the AI server. It may be offline.');
    } catch (e) {
      // Only convert timeout errors to PawTraceServerException.
      // All other errors (e.g. FormatException) propagate as-is so they
      // don't wrongly trigger the "server under maintenance" dialog.
      final msg = e.toString();
      debugPrint('[PawTrace] Server call failed ($path): $msg');
      if (msg.contains('TimeoutException') || msg.contains('timed out')) {
        throw const PawTraceServerException(
            'The AI server did not respond in time. Please try again.');
      }
      rethrow; // not a connectivity problem — let it surface normally
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Loads models — no-op for the server-backed implementation.
  /// Kept for API compatibility with callers that await this.
  Future<void> loadModels() async {
    debugPrint('[PawTrace] Server-backed mode — no local models to load.');
  }

  /// Calls /detect on the AI server to classify the pet species.
  ///
  /// Returns a map with keys: isAccepted, species, confidence, isDog, isCat.
  /// Throws [PawTraceServerException] if the server is unreachable.
  Future<Map<String, dynamic>> detectSpecies(File imageFile) async {
    // _post now throws PawTraceServerException on failure — let it propagate.
    final result = await _post('/detect', imageFile);

    final species    = result['species'] as String? ?? '';
    final isAccepted = result['isAccepted'] as bool? ?? false;
    final isDog      = result['isDog']      as bool? ?? false;
    final isCat      = result['isCat']      as bool? ?? false;
    final confidence = (result['confidence'] as num? ?? 0.0).toDouble();

    debugPrint('[PawTrace] detectSpecies: $species (conf=${confidence.toStringAsFixed(2)})');

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
  /// Throws [PawTraceServerException] if the server is unreachable.
  Future<List<double>?> extractEmbedding(File imageFile) async {
    // _post throws PawTraceServerException on server failure — let it propagate.
    final result = await _post('/embed', imageFile);

    final isAccepted = result['isAccepted'] as bool? ?? false;
    if (!isAccepted) {
      debugPrint('[PawTrace] extractEmbedding: no pet detected by server.');
      return null;
    }

    final raw = result['embedding'];
    if (raw == null) return null;

    final embedding = List<double>.from((raw as List).map((v) => (v as num).toDouble()));
    debugPrint('[PawTrace] extractEmbedding: ${embedding.length}-dim DINOv2 vector received.');
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

  /// Re-embeds every pet in the Supabase pets table using DINOv2 via the server.
  Future<int> reEmbedAllPets({
    void Function(int done, int total)? onProgress,
  }) async {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('pets')
        .select('pet_id, photo_url')
        .order('created_at', ascending: false);

    final pets = List<Map<String, dynamic>>.from(rows);
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

        final tmpFile = File('${Directory.systemTemp.path}/pawtrace_reembed_$petId.jpg');
        await tmpFile.writeAsBytes(bytes);

        final embedding = await extractEmbedding(tmpFile);
        await tmpFile.delete();

        if (embedding != null) {
          await supabase.from('pets').update({'embedding': embedding}).eq('pet_id', petId);
          done++;
          debugPrint('[PawTrace] Re-embedded pet $petId ($done/${pets.length})');
        }
      } catch (e) {
        debugPrint('[PawTrace] Re-embed failed for pet $petId: $e');
      }

      onProgress?.call(done, pets.length);
    }

    debugPrint('[PawTrace] Re-embed complete: $done/${pets.length} pets updated');
    return done;
  }

  void dispose() {
    // No local resources to free in server-backed mode.
  }
}

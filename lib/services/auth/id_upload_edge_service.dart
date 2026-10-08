import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/supabase_config.dart';

/// Calls the `upload-user-id` Supabase Edge Function to upload ID images
/// and persist the validation record server-side (with service-role access).
///
/// This bypasses RLS so it works even when the user has no session yet
/// (e.g., immediately after `auth.signUp()` when email confirmation is required).
class IdUploadEdgeService {
  /// Uploads front and back ID images for [userId] via the Edge Function.
  ///
  /// Returns a map `{ 'frontUrl': String, 'backUrl': String }` on success.
  /// Throws a descriptive [Exception] on failure.
  static Future<Map<String, String>> uploadViaEdgeFunction({
    required String userId,
    required Uint8List frontBytes,
    required String frontExt,
    required Uint8List backBytes,
    required String backExt,
    String? idType,
    String? ocrExtractedText,
    double? nameMatchScore,
    String? imageQuality,
  }) async {
    final edgeFunctionUrl = '$supabaseUrl/functions/v1/upload-user-id';
    final uri = Uri.parse(edgeFunctionUrl);
    final request = http.MultipartRequest('POST', uri);

    // Attach the anon key for Edge Function invocation
    request.headers['apikey'] = supabaseAnonKey;
    request.headers['Authorization'] = 'Bearer $supabaseAnonKey';

    request.fields['userId'] = userId;
    if (idType != null) request.fields['idType'] = idType;
    if (ocrExtractedText != null) request.fields['ocrText'] = ocrExtractedText;
    if (nameMatchScore != null) {
      request.fields['nameScore'] = nameMatchScore.toString();
    }
    if (imageQuality != null) request.fields['imageQuality'] = imageQuality;

    request.files.add(http.MultipartFile.fromBytes(
      'frontImage',
      frontBytes,
      filename: 'front.$frontExt',
      contentType: MediaType('image', frontExt == 'png' ? 'png' : 'jpeg'),
    ));
    request.files.add(http.MultipartFile.fromBytes(
      'backImage',
      backBytes,
      filename: 'back.$backExt',
      contentType: MediaType('image', backExt == 'png' ? 'png' : 'jpeg'),
    ));

    debugPrint('[IdUploadEdgeService] Sending to $edgeFunctionUrl ...');
    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200 ||
        streamedResponse.statusCode == 201) {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return {
        'frontUrl': json['frontUrl']?.toString() ?? '',
        'backUrl': json['backUrl']?.toString() ?? '',
      };
    }

    String errorMsg =
        'Edge function returned status ${streamedResponse.statusCode}';
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      if (json['error'] != null) errorMsg = json['error'].toString();
    } catch (_) {}

    debugPrint('[IdUploadEdgeService] Error: $errorMsg');
    throw Exception(errorMsg);
  }
}

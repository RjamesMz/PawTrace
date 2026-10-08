import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle secure storage and retrieval of user Valid ID images (Front & Back).
class UserIdService {
  static final _supabase = Supabase.instance.client;

  // In-memory cache for fast lookup and fallback across active session
  static final Map<String, Map<String, dynamic>> _memoryCache = {};

  /// Uploads one immutable ID side under the authenticated user's UID.
  static Future<String> uploadIdImage({
    required String userId,
    required String side, // 'front' or 'back'
    required Uint8List bytes,
    String ext = 'jpg',
  }) async {
    final storagePath = 'id-verification/$userId/$side';
    const bucket = 'valid-ids';
    await _supabase.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType:
                ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );

    debugPrint('Successfully uploaded ID $side for user $userId');
    return 'storage://$bucket/$storagePath';
  }

  /// Removes an incomplete upload before an id_validations row exists.
  static Future<void> deleteUploadedId(String reference) async {
    if (!reference.startsWith('storage://')) return;
    final separator = reference.indexOf('/', 'storage://'.length);
    if (separator == -1) return;
    final bucket = reference.substring('storage://'.length, separator);
    final path = reference.substring(separator + 1);
    await _supabase.storage.from(bucket).remove([path]);
  }

  /// Associates the uploaded ID URLs with the user in local cache and Supabase
  static Future<void> saveUserIds({
    required String userId,
    required String email,
    required String frontUrl,
    required String backUrl,
    String? uploadedAt,
    String? idType,
    String? ocrExtractedText,
    double? nameMatchScore,
    String? imageQuality,
  }) async {
    final ts = uploadedAt ?? DateTime.now().toIso8601String();
    final record = {
      'user_id': userId,
      'email': email.trim().toLowerCase(),
      'id_front_url': frontUrl,
      'id_back_url': backUrl,
      'id_uploaded_at': ts,
      if (idType != null) 'id_type': idType,
      if (ocrExtractedText != null) 'ocr_extracted_text': ocrExtractedText,
      if (nameMatchScore != null) 'name_match_score': nameMatchScore,
      if (imageQuality != null) 'image_quality': imageQuality,
    };

    // Persist ID data separately from the user's profile record.
    if (userId.isNotEmpty) {
      try {
        await _supabase.from('id_validations').insert({
          'user_id': userId,
          'id_type': idType,
          'id_front_url': frontUrl,
          'id_back_url': backUrl,
          'ocr_extracted_text': ocrExtractedText,
          'name_match_score': nameMatchScore,
          'image_quality': imageQuality,
        });
      } catch (e) {
        debugPrint('ID validation insert error: $e');
        try {
          final existing = await _supabase
              .from('id_validations')
              .select('id_front_url, id_back_url')
              .eq('user_id', userId)
              .maybeSingle();
          if (existing?['id_front_url'] == frontUrl &&
              existing?['id_back_url'] == backUrl) {
            debugPrint('ID validation already persisted; continuing safely.');
          } else {
            rethrow;
          }
        } catch (_) {
          rethrow;
        }
      }
    }

    // Cache only after the database insert succeeds.
    if (userId.isNotEmpty) {
      _memoryCache[userId] = record;
    }
  }

  /// Retrieves ID documents for a given user map
  static Future<Map<String, dynamic>> getIdData(
      Map<String, dynamic> user) async {
    final uid = (user['user_id'] ?? user['id'] ?? '').toString();
    final email = (user['email'] ?? '').toString().trim().toLowerCase();

    String? frontUrl = user['id_front_url']?.toString();
    String? backUrl = user['id_back_url']?.toString();
    String? uploadedAt = user['id_uploaded_at']?.toString();
    String? idType = user['id_type']?.toString();
    String? ocrExtractedText = user['ocr_extracted_text']?.toString();
    dynamic nameMatchScore = user['name_match_score'];
    String? imageQuality = user['image_quality']?.toString();

    // ID validation is stored separately from the user profile. Prefer the
    // latest submission so resubmissions remain supported.
    if (uid.isNotEmpty) {
      try {
        final validation = await _supabase
            .from('id_validations')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (validation != null) {
          frontUrl = validation['id_front_url']?.toString();
          backUrl = validation['id_back_url']?.toString();
          uploadedAt = validation['created_at']?.toString();
          idType = validation['id_type']?.toString();
          ocrExtractedText = validation['ocr_extracted_text']?.toString();
          nameMatchScore = validation['name_match_score'];
          imageQuality = validation['image_quality']?.toString();
        }
      } catch (e) {
        debugPrint('ID validation lookup error: $e');
      }
    }

    // Check user_metadata if available
    if (user['raw_user_meta_data'] is Map) {
      final meta = user['raw_user_meta_data'] as Map;
      frontUrl ??= meta['id_front_url']?.toString();
      backUrl ??= meta['id_back_url']?.toString();
      uploadedAt ??= meta['id_uploaded_at']?.toString();
      idType ??= meta['id_type']?.toString();
      ocrExtractedText ??= meta['ocr_extracted_text']?.toString();
      nameMatchScore ??= meta['name_match_score'];
      imageQuality ??= meta['image_quality']?.toString();
    }

    // Check in-memory cache
    if ((frontUrl == null || frontUrl.isEmpty) ||
        (backUrl == null || backUrl.isEmpty)) {
      Map<String, dynamic>? cached;
      if (uid.isNotEmpty && _memoryCache.containsKey(uid)) {
        cached = _memoryCache[uid];
      }
      if (cached == null &&
          email.isNotEmpty &&
          _memoryCache.containsKey(email)) {
        cached = _memoryCache[email];
      }

      if (cached != null) {
        frontUrl ??= cached['id_front_url']?.toString();
        backUrl ??= cached['id_back_url']?.toString();
        uploadedAt ??= cached['id_uploaded_at']?.toString();
        idType ??= cached['id_type']?.toString();
        ocrExtractedText ??= cached['ocr_extracted_text']?.toString();
        nameMatchScore ??= cached['name_match_score'];
        imageQuality ??= cached['image_quality']?.toString();
      }
    }

    uploadedAt ??= user['created_at']?.toString();

    frontUrl = await _resolveForAdmin(frontUrl);
    backUrl = await _resolveForAdmin(backUrl);

    return {
      'id_front_url': frontUrl,
      'id_back_url': backUrl,
      'id_uploaded_at': uploadedAt,
      'id_type': idType,
      'ocr_extracted_text': ocrExtractedText,
      'name_match_score':
          nameMatchScore is num ? nameMatchScore.toDouble() : null,
      'image_quality': imageQuality,
      'has_ids': (frontUrl != null && frontUrl.isNotEmpty) ||
          (backUrl != null && backUrl.isNotEmpty),
    };
  }

  /// Converts private Storage references to short-lived URLs for authorized viewers.
  static Future<String?> _resolveForAdmin(String? reference) async {
    if (reference == null || !reference.startsWith('storage://')) {
      return reference;
    }

    final separator = reference.indexOf('/', 'storage://'.length);
    if (separator == -1) return null;

    final bucket = reference.substring('storage://'.length, separator);
    final path = reference.substring(separator + 1);
    try {
      return await _supabase.storage.from(bucket).createSignedUrl(path, 3600);
    } catch (e) {
      debugPrint('Failed to create signed ID URL: $e');
      return null;
    }
  }
}

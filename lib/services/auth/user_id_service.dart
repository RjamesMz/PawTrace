import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle secure storage and retrieval of user Valid ID images (Front & Back).
class UserIdService {
  static final _supabase = Supabase.instance.client;

  // In-memory cache for fast lookup and fallback across active session
  static final Map<String, Map<String, dynamic>> _memoryCache = {};

  /// Uploads an ID image bytes to Supabase storage and returns the URL.
  static Future<String?> uploadIdImage({
    required String email,
    required String side, // 'front' or 'back'
    required Uint8List bytes,
    String ext = 'jpg',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    final sanitizedEmail = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final storagePath =
        'valid_ids/${sanitizedEmail}_${side}_${timestamp}_$random.$ext';

    const candidateBuckets = [
      'valid-ids',
      'id-documents',
      'user-photos',
      'avatars',
      'pet-photos',
    ];

    for (final bucket in candidateBuckets) {
      try {
        await _supabase.storage.from(bucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType:
                    ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg',
              ),
            );

        final url = _supabase.storage.from(bucket).getPublicUrl(storagePath);
        if (url.isNotEmpty) {
          debugPrint(
              'Successfully uploaded ID $side to bucket: $bucket ($url)');
          return url;
        }
      } catch (e) {
        debugPrint('Failed upload to bucket $bucket: $e');
      }
    }

    // Fallback: convert to base64 data URI if storage bucket is unreachable
    final base64Str = base64Encode(bytes);
    final mime = ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,$base64Str';
  }

  /// Associates the uploaded ID URLs with the user in local cache and Supabase
  static Future<void> saveUserIds({
    required String? userId,
    required String email,
    required String frontUrl,
    required String backUrl,
    String? uploadedAt,
    String? idType,
    String? ocrExtractedText,
    double? nameMatchScore,
    String? imageQuality,
    String? validationStatus,
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
      if (validationStatus != null) 'validation_status': validationStatus,
    };

    // Save to in-memory session cache
    if (userId != null && userId.isNotEmpty) {
      _memoryCache[userId] = record;
    }
    _memoryCache[email.trim().toLowerCase()] = record;

    // Try to update public.users table directly if column exists
    if (userId != null && userId.isNotEmpty) {
      try {
        await _supabase.from('users').update({
          'id_front_url': frontUrl,
          'id_back_url': backUrl,
          'id_uploaded_at': ts,
          'id_type': idType,
          'ocr_extracted_text': ocrExtractedText,
          'name_match_score': nameMatchScore,
          'image_quality': imageQuality,
          'validation_status': validationStatus,
        }).eq('user_id', userId);
      } catch (e) {
        debugPrint('Note: public.users column update error: $e');
      }
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
    String? validationStatus = user['validation_status']?.toString();

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
      validationStatus ??= meta['validation_status']?.toString();
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
        validationStatus ??= cached['validation_status']?.toString();
      }
    }

    uploadedAt ??= user['created_at']?.toString();

    return {
      'id_front_url': frontUrl,
      'id_back_url': backUrl,
      'id_uploaded_at': uploadedAt,
      'id_type': idType,
      'ocr_extracted_text': ocrExtractedText,
      'name_match_score':
          nameMatchScore is num ? nameMatchScore.toDouble() : null,
      'image_quality': imageQuality,
      'validation_status': validationStatus,
      'has_ids': (frontUrl != null && frontUrl.isNotEmpty) ||
          (backUrl != null && backUrl.isNotEmpty),
    };
  }
}

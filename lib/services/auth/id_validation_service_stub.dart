import 'dart:typed_data';

class IdValidationResult {
  const IdValidationResult({
    required this.frontQuality,
    required this.backQuality,
    required this.ocrExtractedText,
    required this.nameMatchScore,
    required this.validationStatus,
    this.message,
  });

  final String frontQuality;
  final String backQuality;
  final String ocrExtractedText;
  final double nameMatchScore;
  final String validationStatus;
  final String? message;

  bool get isUsableForRegistration =>
      validationStatus == 'passed' || validationStatus == 'needs_review';
}

class IdValidationService {
  static Future<IdValidationResult> validate({
    required Uint8List frontBytes,
    required Uint8List backBytes,
    required String firstName,
    required String surname,
  }) async {
    // On web/unsupported platforms, skip validation and flag for admin review.
    // ID images will still be uploaded — admins will verify manually.
    return const IdValidationResult(
      frontQuality: 'not_checked',
      backQuality: 'not_checked',
      ocrExtractedText: '',
      nameMatchScore: 0,
      validationStatus: 'needs_review',
      message: 'ID validation skipped on this platform. Admin will review manually.',
    );
  }
}

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

  bool get isUsableForRegistration => validationStatus == 'passed';
}

class IdValidationService {
  static Future<IdValidationResult> validate({
    required Uint8List frontBytes,
    required Uint8List backBytes,
    required String firstName,
    required String surname,
  }) async {
    return const IdValidationResult(
      frontQuality: 'not_checked',
      backQuality: 'not_checked',
      ocrExtractedText: '',
      nameMatchScore: 0,
      validationStatus: 'unsupported_platform',
      message: 'ID validation is available on Android and iOS only.',
    );
  }
}

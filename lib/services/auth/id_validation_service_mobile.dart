import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';

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
    final frontQuality = _checkQuality(frontBytes);
    final backQuality = _checkQuality(backBytes);
    if (frontQuality != 'good' || backQuality != 'good') {
      return IdValidationResult(
        frontQuality: frontQuality,
        backQuality: backQuality,
        ocrExtractedText: '',
        nameMatchScore: 0,
        validationStatus: 'rejected',
        message: 'Use clear, well-lit card photos with a visible full ID.',
      );
    }

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return IdValidationResult(
        frontQuality: frontQuality,
        backQuality: backQuality,
        ocrExtractedText: '',
        nameMatchScore: 0,
        validationStatus: 'unsupported_platform',
        message: 'ID validation is available on Android and iOS only.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/pawtrace_id_front.jpg');
    await file.writeAsBytes(frontBytes, flush: true);

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      final text = result.text.trim();
      final score = _nameMatchScore(text, '$firstName $surname');
      final status = score >= 55 ? 'passed' : 'needs_review';
      return IdValidationResult(
        frontQuality: frontQuality,
        backQuality: backQuality,
        ocrExtractedText: text,
        nameMatchScore: score,
        validationStatus: status,
        message: status == 'passed'
            ? 'ID quality and name check passed.'
            : 'The ID is readable, but the name needs admin review.',
      );
    } finally {
      await recognizer.close();
      if (await file.exists()) await file.delete();
    }
  }

  static String _checkQuality(Uint8List bytes) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null) return 'unreadable';

    final width = decoded.width;
    final height = decoded.height;
    final ratio = width / height;
    if (width < 400 || height < 250 || ratio < 1.3 || ratio > 2.0) {
      return 'poor_dimensions';
    }

    var totalLuma = 0.0;
    var samples = 0;
    for (var y = 0; y < height; y += math.max(1, height ~/ 40)) {
      for (var x = 0; x < width; x += math.max(1, width ~/ 40)) {
        final pixel = decoded.getPixel(x, y);
        totalLuma += 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
        samples++;
      }
    }
    final averageLuma = samples == 0 ? 0 : totalLuma / samples;
    if (averageLuma < 35 || averageLuma > 235) return 'poor_lighting';
    return 'good';
  }

  static double _nameMatchScore(String ocrText, String enteredName) {
    final ocr = _normalize(ocrText);
    final name = _normalize(enteredName);
    if (ocr.isEmpty || name.isEmpty) return 0;
    if (ocr.contains(name)) return 100;

    final tokens = name.split(' ').where((token) => token.isNotEmpty);
    final scores = tokens.map((token) {
      if (ocr.contains(token)) return 100.0;
      return _bestTokenScore(token, ocr.split(' '));
    }).toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  static double _bestTokenScore(String token, List<String> words) {
    if (words.isEmpty) return 0;
    return words.map((word) => _similarity(token, word)).reduce(math.max);
  }

  static double _similarity(String left, String right) {
    final distance = _levenshtein(left, right);
    final length = math.max(left.length, right.length);
    return length == 0 ? 100 : (1 - distance / length) * 100;
  }

  static int _levenshtein(String left, String right) {
    final previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      var diagonal = previous[0];
      previous[0] = i + 1;
      for (var j = 0; j < right.length; j++) {
        final above = previous[j + 1];
        previous[j + 1] = left[i] == right[j]
            ? diagonal
            : 1 + math.min(diagonal, math.min(previous[j], above));
        diagonal = above;
      }
    }
    return previous[right.length];
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

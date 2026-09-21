// Mobile implementation of PetEmbeddingService using tflite_flutter.
// Only compiled on non-web platforms.
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of AI pet classification checking if an image is a dog or cat.
class PetClassificationResult {
  final bool isDogOrCat;
  final String detectedSpecies; // 'Dog', 'Cat', or specific non-dog/cat label
  final String label; // e.g. "Golden Retriever", "Tabby", "Macaw"
  final double confidence; // 0.0 to 1.0
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

class PetEmbeddingService {
  PetEmbeddingService._();
  static final PetEmbeddingService instance = PetEmbeddingService._();
  Interpreter? mobileNet;
  Interpreter? aspinPuspin;
  List<String> mobileNetLabels = [];
  static const int _inputSize = 224;

  Future<void> loadModels() async {
    if (mobileNet == null) {
      debugPrint('[PawTrace] Loading MobileNet model...');
      mobileNet = await Interpreter.fromAsset(
          'assets/models/mobilenet_v1_1.0_224_quant.tflite');
      debugPrint('[PawTrace] MobileNet model loaded');
    }

    if (aspinPuspin == null) {
      try {
        debugPrint('[PawTrace] Loading Aspin/Puspin model...');
        aspinPuspin =
            await Interpreter.fromAsset('assets/models/pawtrace_model.tflite');
        debugPrint('[PawTrace] Aspin/Puspin model loaded');
      } catch (e) {
        debugPrint('[PawTrace] Aspin/Puspin model load failed: $e');
      }
    }

    if (mobileNetLabels.isEmpty) {
      try {
        final raw = await rootBundle.loadString('assets/models/labels.txt');
        mobileNetLabels = raw
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint('[PawTrace] labels.txt load failed: $e');
        mobileNetLabels = const [];
      }
    }
  }

  bool _isWildAnimalIndexOrLabel(int idx, String label) {
    // 1. Wild canids in MobileNet: timber wolf (270), white wolf (271), red wolf (272), coyote (273), dingo (274), dhole (275), african hunting dog (276), hyena (277), foxes (278..281)
    if (idx >= 270 && idx <= 281) return true;
    // 2. Wild felids / big cats in MobileNet: cougar (287), lynx (288), leopard (289), snow leopard (290), jaguar (291), lion (292), tiger (293), cheetah (294)
    if (idx >= 287 && idx <= 294) return true;
    // 3. Bears: brown bear (295), american black bear (296), ice/polar bear (297), sloth bear (298)
    if (idx >= 295 && idx <= 298) return true;
    // 4. Tiger shark (4)
    if (idx == 4) return true;

    const wildKeywords = [
      'wolf',
      'timber wolf',
      'white wolf',
      'red wolf',
      'coyote',
      'dingo',
      'dhole',
      'hyena',
      'fox',
      'jackal',
      'tiger',
      'lion',
      'leopard',
      'jaguar',
      'cheetah',
      'panther',
      'cougar',
      'puma',
      'lynx',
      'bobcat',
      'ocelot',
      'caracal',
      'serval',
      'bear',
    ];
    return wildKeywords.any((k) => label.contains(k));
  }

  bool _isDogIndexOrLabel(int idx, String label) {
    // Explicitly reject wild animals from ever being considered a dog
    if (_isWildAnimalIndexOrLabel(idx, label)) return false;
    // MobileNet domestic dog indices strictly span 152 through 269
    if (idx >= 152 && idx <= 269) return true;
    const dogKeywords = [
      'dog',
      'hound',
      'retriever',
      'shepherd',
      'terrier',
      'poodle',
      'bulldog',
      'beagle',
      'husky',
      'pug',
      'boxer',
      'collie',
      'spaniel',
      'setter',
      'pointer',
      'malamute',
      'samoyed',
      'corgi',
      'dachshund',
      'dalmatian',
      'doberman',
      'labrador',
      'chihuahua',
      'shih',
      'maltese',
      'pomeranian',
      'schnauzer',
      'rottweiler',
      'mastiff',
      'greyhound',
      'basenji',
      'ridgeback',
      'kelpie',
      'whippet',
      'saluki',
      'borzoi',
      'pekinese',
      'papillon',
      'kuvasz',
      'briard',
      'komondor',
      'malinois',
      'groenendael',
      'schipperke',
      'lhasa',
      'vizsla',
      'clumber',
      'airedale',
      'cairn',
      'appenzeller',
      'entlebucher',
      'leonberg',
      'newfoundland',
      'great pyrenees',
      'chow',
      'keeshond',
      'pembroke',
      'cardigan',
      'hairless',
      'puppy',
      'mutt',
      'mongrel',
      'aspin',
    ];
    return dogKeywords.any((k) => label.contains(k));
  }

  bool _isCatIndexOrLabel(int idx, String label) {
    // Explicitly reject wild animals / big cats from ever being considered a domestic cat
    if (_isWildAnimalIndexOrLabel(idx, label)) return false;
    // MobileNet domestic cat indices strictly span 282 through 286 (tabby, tiger cat, persian, siamese, egyptian)
    if (idx >= 282 && idx <= 286) return true;
    const catKeywords = [
      'domestic cat',
      'tabby',
      'persian',
      'siamese',
      'egyptian',
      'kitten',
      'feline',
      'puspin',
    ];
    return catKeywords.any((k) => label.contains(k));
  }

  Future<Map<String, dynamic>> detectSpecies(File imageFile) async {
    try {
      await loadModels();
      if (mobileNet == null) {
        return {
          'label': 'Not a Pet',
          'isAccepted': false,
          'isDog': false,
          'isCat': false,
          'isAspin': false,
          'isPuspin': false,
          'confidence': 0.0,
        };
      }

      final rawBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        return {
          'label': 'Not a Pet',
          'isAccepted': false,
          'isDog': false,
          'isCat': false,
          'isAspin': false,
          'isPuspin': false,
          'confidence': 0.0,
        };
      }

      final resized =
          img.copyResize(decoded, width: _inputSize, height: _inputSize);
      final input = List.generate(
        1,
        (_) => List.generate(
            _inputSize,
            (y) => List.generate(_inputSize, (x) {
                  final pixel = resized.getPixel(x, y);
                  return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
                })),
      );

      final mobileNetOutput = List.generate(1, (_) => List.filled(1001, 0));
      mobileNet!.run(input, mobileNetOutput);

      final scores = mobileNetOutput[0];
      final indexedScores =
          List.generate(scores.length, (i) => MapEntry(i, scores[i]))
            ..sort((a, b) => b.value.compareTo(a.value));

      // 1. FIRST: Check top predictions for wild animals (wolf, tiger, lion, bear, etc.)
      for (int i = 0; i < 5 && i < indexedScores.length; i++) {
        final entry = indexedScores[i];
        final idx = entry.key;
        final score = entry.value;
        if (score < 8) continue;

        final lbl = idx < mobileNetLabels.length
            ? mobileNetLabels[idx].toLowerCase()
            : '';
        if (_isWildAnimalIndexOrLabel(idx, lbl)) {
          debugPrint(
              '[PawTrace] Wild animal detected: $lbl (idx: $idx, score: $score). Rejecting registration.');
          return {
            'label': 'Wild Animal (${_formatLabel(lbl)})',
            'breed': _formatLabel(lbl),
            'isAccepted': false,
            'isDog': false,
            'isCat': false,
            'isWildAnimal': true,
            'confidence': (score / 255.0).clamp(0.0, 1.0),
          };
        }
      }

      int topDogIndex = -1;
      int topDogScore = 0;

      int topCatIndex = -1;
      int topCatScore = 0;

      for (int i = 0; i < 5 && i < indexedScores.length; i++) {
        final entry = indexedScores[i];
        final idx = entry.key;
        final score = entry.value;
        if (score < 5) continue;

        final lbl = idx < mobileNetLabels.length
            ? mobileNetLabels[idx].toLowerCase()
            : '';
        if (_isDogIndexOrLabel(idx, lbl)) {
          if (score > topDogScore) {
            topDogScore = score;
            topDogIndex = idx;
          }
        } else if (_isCatIndexOrLabel(idx, lbl)) {
          if (score > topCatScore) {
            topCatScore = score;
            topCatIndex = idx;
          }
        }
      }

      bool isDog = topDogScore >= 5 && topDogScore >= topCatScore;
      bool isCat = topCatScore >= 5 && topCatScore > topDogScore;
      bool isAspin = false;
      bool isPuspin = false;
      double confidence =
          (isDog ? topDogScore : (isCat ? topCatScore : 0)) / 255.0;

      // Second check: run custom Aspin/Puspin model ONLY IF image doesn't match an inanimate non-pet object
      final topEntry = indexedScores.isNotEmpty ? indexedScores.first : null;
      final topScore = topEntry?.value ?? 0;
      final topIdx = topEntry?.key ?? -1;
      final topLbl = topIdx >= 0 && topIdx < mobileNetLabels.length
          ? mobileNetLabels[topIdx].toLowerCase()
          : '';

      final bool isConfidentNonPet = topScore >= 40 &&
          !_isDogIndexOrLabel(topIdx, topLbl) &&
          !_isCatIndexOrLabel(topIdx, topLbl);

      if (!isDog && !isCat && !isConfidentNonPet && aspinPuspin != null) {
        final secondOutput = List.generate(1, (_) => List.filled(2, 0.0));
        try {
          aspinPuspin!.run(input, secondOutput);
          final aspinScore = (secondOutput[0][0] as num).toDouble();
          final puspinScore = (secondOutput[0][1] as num).toDouble();

          if (aspinScore >= 0.82) {
            isDog = true;
            isAspin = true;
            confidence = aspinScore;
          } else if (puspinScore >= 0.82) {
            isCat = true;
            isPuspin = true;
            confidence = puspinScore;
          }
        } catch (e) {
          debugPrint('[PawTrace] aspinPuspin inference error: $e');
        }
      }

      if (isDog) {
        final breedName = isAspin
            ? 'Aspin - Philippine Street Dog'
            : (topDogIndex >= 0 && topDogIndex < mobileNetLabels.length
                ? _formatLabel(mobileNetLabels[topDogIndex])
                : 'Dog');
        return {
          'label': 'Dog',
          'breed': breedName,
          'isAccepted': true,
          'isDog': true,
          'isCat': false,
          'isAspin': isAspin,
          'isPuspin': false,
          'confidence': confidence.clamp(0.0, 1.0),
        };
      }

      if (isCat) {
        final breedName = isPuspin
            ? 'Puspin - Philippine Street Cat'
            : (topCatIndex >= 0 && topCatIndex < mobileNetLabels.length
                ? _formatLabel(mobileNetLabels[topCatIndex])
                : 'Cat');
        return {
          'label': 'Cat',
          'breed': breedName,
          'isAccepted': true,
          'isDog': false,
          'isCat': true,
          'isAspin': false,
          'isPuspin': isPuspin,
          'confidence': confidence.clamp(0.0, 1.0),
        };
      }

      return {
        'label': 'Not a Pet',
        'isAccepted': false,
        'isDog': false,
        'isCat': false,
        'isAspin': false,
        'isPuspin': false,
        'confidence': 0.0,
      };
    } catch (e) {
      debugPrint('[PawTrace] detectSpecies error: $e');
      return {
        'label': 'Not a Pet',
        'isAccepted': false,
        'isDog': false,
        'isCat': false,
        'isAspin': false,
        'isPuspin': false,
        'confidence': 0.0,
      };
    }
  }

  /// Classifies whether an image is a Dog, Cat, or another animal/subject.
  Future<PetClassificationResult> classifyImage(File imageFile) async {
    try {
      final detected = await detectSpecies(imageFile);
      final isDog = detected['isDog'] == true;
      final isCat = detected['isCat'] == true;
      final accepted = detected['isAccepted'] == true;
      final label =
          (detected['breed'] ?? detected['label'] ?? 'Unknown').toString();
      final confidence = (detected['confidence'] as num?)?.toDouble() ?? 0.0;
      return PetClassificationResult(
        isDogOrCat: accepted,
        detectedSpecies: isDog ? 'Dog' : (isCat ? 'Cat' : 'Unknown'),
        label: label,
        confidence: confidence,
        classIndex: -1,
        errorMessage:
            accepted ? null : 'No supported dog/cat species detected.',
      );
    } catch (e) {
      debugPrint('[PawTrace] Classification exception: $e');
      return PetClassificationResult(
        isDogOrCat: false,
        detectedSpecies: 'Unknown',
        label: 'Error',
        confidence: 0,
        classIndex: -1,
        errorMessage: 'Classification error: $e',
      );
    }
  }

  static String _formatLabel(String raw) {
    return raw.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<List<double>?> extractEmbedding(File imageFile) async {
    try {
      debugPrint('[PawTrace] loadModels() start');
      await loadModels();
      debugPrint('[PawTrace] loadModels() done');
      final interpreter = mobileNet;
      if (interpreter == null) {
        debugPrint('[PawTrace] ERROR: MobileNet interpreter unavailable');
        return null;
      }
      final rawBytes = await imageFile.readAsBytes();
      debugPrint('[PawTrace] image bytes: ${rawBytes.length}');
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        debugPrint('[PawTrace] ERROR: image decode null!');
        return null;
      }
      debugPrint('[PawTrace] image decoded OK');
      final resized =
          img.copyResize(decoded, width: _inputSize, height: _inputSize);
      final input = List.generate(
          1,
          (_) => List.generate(
              _inputSize,
              (y) => List.generate(_inputSize, (x) {
                    final pixel = resized.getPixel(x, y);
                    return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
                  })));
      final output = List.generate(1, (_) => List.filled(1001, 0));
      interpreter.run(input, output);
      debugPrint('[PawTrace] inference done');
      final raw = output[0].map((v) => v.toDouble()).toList();
      return _l2Normalize(raw);
    } catch (e, stack) {
      debugPrint('[PawTrace] EXCEPTION: $e');
      debugPrint('[PawTrace] stack: $stack');
      return null;
    }
  }

  List<double> _l2Normalize(List<double> vec) {
    double sumSq = 0;
    for (final v in vec) {
      sumSq += v * v;
    }
    final norm = sqrt(sumSq);
    if (norm == 0) return vec;
    return vec.map((v) => v / norm).toList();
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  void dispose() {
    mobileNet?.close();
    aspinPuspin?.close();
    mobileNet = null;
    aspinPuspin = null;
  }
}

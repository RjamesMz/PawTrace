/// Platform-adaptive entry point for the PetEmbeddingService.
///
/// On **Flutter Web** (`pet_embedding_service_web.dart`):
/// - All methods return safe no-op results — TFLite / dart:ffi are unavailable on web.
///
/// On **Android / iOS / Desktop** (`pet_embedding_service_mobile.dart`):
/// - Full TFLite inference using tflite_flutter.
///
/// All callers import only THIS file; the platform is resolved at compile time.
export 'pet_embedding_service_mobile.dart'
    if (dart.library.html) 'pet_embedding_service_web.dart';

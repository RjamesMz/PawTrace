/// Platform-adaptive entry point for the PetEmbeddingService.
///
/// On **Flutter Web** (`pet_embedding_service_web.dart`):
/// - Safe fallback implementations.
///
/// On **Android / iOS / Desktop** (`pet_embedding_service_mobile.dart`):
/// - Server-backed inference using YOLOv11 and DINOv2 via PetTrace AI Server.
///
/// All callers import only THIS file; the platform is resolved at compile time.
library;

export 'pet_embedding_service_mobile.dart'
    if (dart.library.html) 'pet_embedding_service_web.dart';

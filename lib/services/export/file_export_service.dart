import 'file_export_stub.dart'
    if (dart.library.html) 'file_export_web.dart'
    if (dart.library.io) 'file_export_io.dart';

Future<void> saveAndShareFile(List<int> bytes, String filename) {
  return getExportPlatform().exportFile(bytes, filename);
}

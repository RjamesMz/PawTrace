// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'file_export_interface.dart';

class FileExportWeb implements FileExportPlatform {
  @override
  Future<void> exportFile(List<int> bytes, String filename) async {
    final mimeType = filename.toLowerCase().endsWith('.pdf')
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    final blob = html.Blob(
      [bytes],
      mimeType,
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

FileExportPlatform getExportPlatform() => FileExportWeb();

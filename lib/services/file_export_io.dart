import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'file_export_interface.dart';

class FileExportIo implements FileExportPlatform {
  @override
  Future<void> exportFile(List<int> bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ],
      subject: filename,
    );
  }
}

FileExportPlatform getExportPlatform() => FileExportIo();

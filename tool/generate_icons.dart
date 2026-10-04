// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final assetPath = 'assets/images/logo.png';
  final rawFile = File(assetPath);
  if (!rawFile.existsSync()) {
    print('Logo asset does not exist: $assetPath');
    return;
  }

  final rawBytes = rawFile.readAsBytesSync();
  final master = img.decodeImage(rawBytes);
  if (master == null) {
    print('Failed to decode master logo');
    return;
  }

  print('Loaded master logo: ${master.width}x${master.height}');

  // 1. Copy to build/flutter_assets
  final buildLogo = File('build/flutter_assets/assets/images/logo.png');
  if (buildLogo.existsSync()) {
    buildLogo.writeAsBytesSync(rawBytes);
    print('Updated build/flutter_assets logo');
  }

  // 2. Android mipmap icons
  final androidSizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in androidSizes.entries) {
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    final resized = img.copyResize(master,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.cubic);
    final bytes = img.encodePng(resized);
    file.writeAsBytesSync(bytes);
    // Also save as ic_launcher_round
    final roundFile =
        File(entry.key.replaceAll('ic_launcher.png', 'ic_launcher_round.png'));
    roundFile.writeAsBytesSync(bytes);
    print('Generated Android launcher icons: ${entry.key}');
  }

  // 3. iOS icons
  final iosSizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };

  for (final entry in iosSizes.entries) {
    final file =
        File('ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}');
    if (file.parent.existsSync()) {
      final resized = img.copyResize(master,
          width: entry.value,
          height: entry.value,
          interpolation: img.Interpolation.cubic);
      file.writeAsBytesSync(img.encodePng(resized));
      print('Generated iOS icon: ${entry.key}');
    }
  }

  // 4. Web icons & favicon
  final webSizes = {
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
    'web/favicon.png': 64,
  };

  for (final entry in webSizes.entries) {
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    final resized = img.copyResize(master,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.cubic);
    file.writeAsBytesSync(img.encodePng(resized));
    print('Generated Web icon: ${entry.key}');
  }

  // 5. Windows icon
  final winFile = File('windows/runner/resources/app_icon.ico');
  if (winFile.parent.existsSync()) {
    final win256 = img.copyResize(master,
        width: 256, height: 256, interpolation: img.Interpolation.cubic);
    try {
      winFile.writeAsBytesSync(img.encodeIco(win256));
      print('Generated Windows icon: ${winFile.path}');
    } catch (_) {
      winFile.writeAsBytesSync(img.encodePng(win256));
    }
  }

  print('All launcher icons and assets synchronized to original logo!');
}

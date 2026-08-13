import 'dart:io';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logger_utils.dart';
import 'notify.dart';

/// Utility helper to handle saving DevicePreview screenshots across platforms.
class ScreenshotUtils {
  ScreenshotUtils._();

  /// Captures and saves screenshot bytes to the local documents folder.
  static Future<String> handleScreenshot(
    BuildContext context,
    DeviceScreenshot screenshot,
  ) async {
    return createFile(
      screenshot.bytes,
      deviceName: screenshot.device.name,
    );
  }

  /// Creates a PNG file from image bytes in Documents/PolyglotStudio/Screenshots.
  static Future<String> createFile(
    Uint8List bytes, {
    String? deviceName,
  }) async {
    try {
      if (kIsWeb) {
        printI('Screenshot captured on Web platform (${bytes.length} bytes)');
        Notify.info('Screenshot Captured', description: 'Web screenshot recorded.');
        return '';
      }

      Directory baseDir;
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        baseDir = await getTemporaryDirectory();
      }

      final Directory screenshotDir = Directory(
        p.join(baseDir.path, 'PolyglotStudio', 'Screenshots'),
      );

      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }

      final String namePrefix = deviceName != null && deviceName.isNotEmpty
          ? deviceName.replaceAll(RegExp(r'[^\w\.-]'), '_')
          : 'screenshot';

      final String fileName =
          '${namePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      final String filePath = p.join(screenshotDir.path, fileName);

      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      printI('Screenshot saved successfully: $filePath');
      Notify.success(
        'Screenshot Saved',
        description: 'Saved to $filePath',
      );

      return filePath;
    } catch (e, stacktrace) {
      printE('Error creating screenshot file: $e', stacktrace: stacktrace);
      Notify.error('Screenshot Failed', description: e.toString());
      return '';
    }
  }
}

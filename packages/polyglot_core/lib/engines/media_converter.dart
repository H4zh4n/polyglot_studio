import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

/// Helper to normalize video/audio files to compliant MP4 container format.
class MediaConverter {
  /// Checks if system FFmpeg is available in the environment.
  static Future<bool> isFfmpegAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Normalizes video or audio file to standard H.264/AAC MP4.
  static Future<Uint8List> normalizeToMp4({
    required Uint8List inputMediaBytes,
    required bool isVideo,
    String? originalFilename,
  }) async {
    final hasFfmpeg = await isFfmpegAvailable();
    if (!hasFfmpeg) {
      // If FFmpeg is not installed, pass through the bytes as-is
      return inputMediaBytes;
    }

    final tempDir = Directory.systemTemp;
    final uniqueId = DateTime.now().microsecondsSinceEpoch.toString();
    final ext = originalFilename != null ? p.extension(originalFilename) : (isVideo ? '.mp4' : '.m4a');
    final inputTempPath = p.join(tempDir.path, 'polyglot_in_$uniqueId$ext');
    final outputTempPath = p.join(tempDir.path, 'polyglot_out_$uniqueId.mp4');

    try {
      await File(inputTempPath).writeAsBytes(inputMediaBytes);

      final List<String> args;
      if (isVideo) {
        args = [
          '-y',
          '-i', inputTempPath,
          '-c:v', 'libx264',
          '-strict', '-2',
          '-preset', 'fast',
          '-pix_fmt', 'yuv420p',
          '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
          '-movflags', '+faststart',
          '-f', 'mp4',
          outputTempPath,
        ];
      } else {
        args = [
          '-y',
          '-i', inputTempPath,
          '-vn',
          '-c:a', 'aac',
          '-b:a', '192k',
          '-movflags', '+faststart',
          '-f', 'mp4',
          outputTempPath,
        ];
      }

      final result = await Process.run('ffmpeg', args);
      if (result.exitCode == 0 && await File(outputTempPath).exists()) {
        final normalizedBytes = await File(outputTempPath).readAsBytes();
        return normalizedBytes;
      } else {
        return inputMediaBytes;
      }
    } catch (_) {
      return inputMediaBytes;
    } finally {
      try {
        final inFile = File(inputTempPath);
        if (await inFile.exists()) await inFile.delete();
        final outFile = File(outputTempPath);
        if (await outFile.exists()) await outFile.delete();
      } catch (_) {}
    }
  }
}

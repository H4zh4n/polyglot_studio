import 'dart:convert';
import 'dart:io' show File;
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Platform-agnostic file representation supporting Web, Desktop, and Mobile.
class AppFile {
  final String name;
  final String? path;
  final int? size;
  final Uint8List? bytes;
  final XFile? xFile;

  const AppFile({
    required this.name,
    this.path,
    this.size,
    this.bytes,
    this.xFile,
  });

  /// Extracts lowercase extension including dot, e.g. ".png"
  String get extension => p.extension(name).toLowerCase();

  bool get isImage => ['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.ico'].contains(extension);
  bool get isVideo => ['.mp4', '.m4v', '.mov', '.mkv', '.avi'].contains(extension);
  bool get isAudio => ['.mp3', '.m4a', '.aac', '.wav'].contains(extension);
  bool get isPdf => extension == '.pdf';
  bool get isHtml => ['.html', '.htm'].contains(extension);
  bool get isZip => ['.zip', '.jar', '.apk', '.docx', '.xlsx', '.pptx'].contains(extension);

  /// Asynchronously loads bytes across Web (via bytes / Blob API) and native platforms.
  Future<Uint8List> readAsBytes() async {
    if (bytes != null && bytes!.isNotEmpty) {
      return bytes!;
    }
    if (xFile != null) {
      return await xFile!.readAsBytes();
    }
    if (!kIsWeb && path != null && path!.isNotEmpty) {
      final f = File(path!);
      if (await f.exists()) {
        return await f.readAsBytes();
      }
    }
    return Uint8List(0);
  }

  /// Asynchronously reads content as a UTF-8 string.
  Future<String> readAsString() async {
    final b = await readAsBytes();
    return utf8.decode(b, allowMalformed: true);
  }

  /// Creates an [AppFile] from a [PlatformFile] (from `file_picker`).
  static AppFile fromPlatformFile(PlatformFile file) {
    return AppFile(
      name: file.name,
      path: file.path,
      size: file.size,
      bytes: file.bytes,
    );
  }

  /// Creates an [AppFile] from an [XFile] (from `desktop_drop`).
  static AppFile fromXFile(XFile file) {
    return AppFile(
      name: file.name.isNotEmpty ? file.name : p.basename(file.path),
      path: file.path,
      xFile: file,
    );
  }

  /// Creates an [AppFile] from a local file path.
  static AppFile fromPath(String filePath) {
    return AppFile(
      name: p.basename(filePath),
      path: filePath,
    );
  }

  /// Creates an in-memory [AppFile].
  static AppFile fromBytes({required String name, required Uint8List bytes}) {
    return AppFile(
      name: name,
      size: bytes.length,
      bytes: bytes,
    );
  }
}

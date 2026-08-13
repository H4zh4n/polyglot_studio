import 'dart:typed_data';

/// Encapsulates all input data required to generate a polyglot file.
class PolyglotInputs {
  /// Raw bytes of the primary image.
  final Uint8List imageBytes;
  final String? imageName;

  /// Raw bytes of the primary video or audio file (MP4 container).
  final Uint8List mediaBytes;
  final String? mediaName;
  final bool isVideo;

  /// Optional HTML text or document.
  final String? htmlContent;

  /// Optional PDF document bytes.
  final Uint8List? pdfBytes;

  /// Optional list of ZIP archives to merge and append.
  final List<Uint8List> zipArchives;

  /// Optional short extra string (< 200 bytes) inserted near the header.
  final String extraHeaderData;

  /// Optional raw binary payloads appended before the ZIP archives.
  final List<Uint8List> appendables;

  const PolyglotInputs({
    required this.imageBytes,
    this.imageName,
    required this.mediaBytes,
    this.mediaName,
    this.isVideo = true,
    this.htmlContent,
    this.pdfBytes,
    this.zipArchives = const [],
    this.extraHeaderData = '',
    this.appendables = const [],
  });
}

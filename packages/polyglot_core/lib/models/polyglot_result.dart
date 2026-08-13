import 'dart:typed_data';

/// Encapsulates the generated polyglot binary and metadata metrics.
class PolyglotResult {
  final Uint8List data;
  final int pngOffset;
  final int pngSize;
  final int mp4Size;
  final int? pdfOffset;
  final int? zipOffset;
  final List<String> supportedExtensions;
  final List<String> warnings;

  const PolyglotResult({
    required this.data,
    required this.pngOffset,
    required this.pngSize,
    required this.mp4Size,
    this.pdfOffset,
    this.zipOffset,
    required this.supportedExtensions,
    this.warnings = const [],
  });

  int get totalBytes => data.length;
}

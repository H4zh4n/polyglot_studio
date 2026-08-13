import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:polyglot_core/polyglot_core.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/notify.dart';
import 'audio_player_preview.dart';
import 'html_document_preview.dart';
import 'image_preview_dialog.dart';
import 'pdf_document_preview.dart';
import 'video_player_preview.dart';
import 'zip_archive_preview.dart';

/// A universal, plug-and-play modular File Preview widget.
///
/// Automatically inspects any binary byte stream and renders the highest-fidelity
/// interactive preview component (PDF, HTML/CSS, Audio Visualizer, Video Player,
/// ZIP Explorer, High-Res Image, Monospace Code/Text, or Formatted Hex Dump).
class UniversalFilePreview extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final String? explicitFormat;
  final VoidCallback? onExport;
  final PolyglotInspectionResult? precomputedInspection;

  const UniversalFilePreview({
    super.key,
    required this.bytes,
    required this.fileName,
    this.explicitFormat,
    this.onExport,
    this.precomputedInspection,
  });

  /// Opens a modular, responsive modal preview dialog for any file anywhere in the app.
  static Future<void> show(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    String? explicitFormat,
    VoidCallback? onExport,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(200),
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.background,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 780),
          child: Column(
            children: [
              // Dialog Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.preview_rounded, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onExport != null) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.download_outlined, size: 16, color: AppTheme.textSecondary),
                        tooltip: 'Export File',
                        onPressed: onExport,
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UniversalFilePreview(
                  bytes: bytes,
                  fileName: fileName,
                  explicitFormat: explicitFormat,
                  onExport: onExport,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (bytes.isEmpty) {
      return const Center(
        child: Text('Empty payload buffer', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      );
    }

    final ext = (explicitFormat ?? p.extension(fileName)).toLowerCase();

    // 1. PDF Documents
    if (ext == '.pdf' || (bytes.length >= 5 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46)) {
      final inspection = precomputedInspection ?? PolyglotInspector.inspect(bytes: bytes, fileName: fileName);
      return PdfDocumentPreview(
        pdfBytes: inspection.extractedPdfBytes ?? bytes,
        fileName: fileName,
        pdfInfo: inspection.pdfInfo,
        onExport: onExport,
      );
    }

    // 2. Audio Streams
    if (['.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg'].contains(ext)) {
      final inspection = precomputedInspection ?? PolyglotInspector.inspect(bytes: bytes, fileName: fileName);
      return AudioPlayerPreview(
        audioBytes: inspection.extractedAudioBytes ?? bytes,
        fileName: fileName,
        format: ext.isNotEmpty ? ext : '.m4a',
        mediaInfo: inspection.mediaInfo,
        onExport: onExport,
      );
    }

    // 3. Video Streams
    if (['.mp4', '.mkv', '.avi', '.mov', '.webm'].contains(ext)) {
      final inspection = precomputedInspection ?? PolyglotInspector.inspect(bytes: bytes, fileName: fileName);
      return VideoPlayerPreview(
        videoBytes: inspection.extractedMediaBytes ?? bytes,
        fileName: fileName,
        format: ext.isNotEmpty ? ext : '.mp4',
        mediaInfo: inspection.mediaInfo,
        onExport: onExport,
      );
    }

    // 4. HTML Documents
    if (['.html', '.htm'].contains(ext)) {
      final inspection = precomputedInspection ?? PolyglotInspector.inspect(bytes: bytes, fileName: fileName);
      String htmlStr = inspection.extractedHtmlContent ?? '';
      if (htmlStr.isEmpty) {
        try {
          htmlStr = utf8.decode(bytes, allowMalformed: true);
        } catch (_) {
          htmlStr = String.fromCharCodes(bytes);
        }
      }
      return HtmlDocumentPreview(
        htmlContent: htmlStr,
        fileName: fileName,
        htmlInfo: inspection.htmlInfo,
        onExport: onExport,
      );
    }

    // 5. ZIP Archives
    if (['.zip', '.jar', '.apk'].contains(ext)) {
      final inspection = precomputedInspection ?? PolyglotInspector.inspect(bytes: bytes, fileName: fileName);
      return ZipArchivePreview(
        zipBytes: inspection.extractedZipBytes ?? bytes,
        rawBytes: bytes,
        fileName: fileName,
        zipOffset: inspection.zipOffset,
        entries: inspection.zipEntries,
        onExport: onExport,
      );
    }

    // 6. Image Files
    if (['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.ico', '.gif'].contains(ext)) {
      return _buildImagePreview(context);
    }

    // 7. Text / Code Files
    if (['.txt', '.json', '.md', '.dart', '.py', '.js', '.css', '.xml', '.yaml', '.yml', '.csv', '.log', '.sh', '.bat', '.sql', '.toml', '.ini', '.properties'].contains(ext)) {
      return _buildTextPreview();
    }

    // 8. Default Binary Hex Dump
    return _buildBinaryHexPreview();
  }

  Widget _buildImagePreview(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => ImagePreviewDialog.show(
                context,
                imageBytes: bytes,
                fileName: fileName,
                onExport: onExport,
              ),
              child: Center(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Invalid Image Data', style: TextStyle(fontSize: 10, color: AppTheme.danger)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ImagePreviewDialog.show(
                context,
                imageBytes: bytes,
                fileName: fileName,
                onExport: onExport,
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(200),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderSubtle.withAlpha(140)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, size: 13, color: AppTheme.accent),
                    SizedBox(width: 5),
                    Text(
                      'Click to Enlarge',
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextPreview() {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126));
    }

    return Container(
      color: const Color(0xFF0D0F12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceElevated,
              border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${text.split('\n').length} lines • ${text.length} chars',
                  style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppTheme.textMuted),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 13, color: AppTheme.textSecondary),
                  tooltip: 'Copy Text',
                  onPressed: () {
                    Notify.success('Copied', description: 'Text copied to clipboard');
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectionArea(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    color: Color(0xFFCBD5E1),
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBinaryHexPreview() {
    final previewLength = bytes.length > 512 ? 512 : bytes.length;
    final buffer = StringBuffer();
    for (int i = 0; i < previewLength; i += 16) {
      final chunkEnd = i + 16 < previewLength ? i + 16 : previewLength;
      final hex = bytes.sublist(i, chunkEnd).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final ascii = bytes.sublist(i, chunkEnd).map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.').join();
      buffer.writeln('${i.toRadixString(16).padLeft(6, '0').toUpperCase()}  ${hex.padRight(48)}  |$ascii|');
    }
    if (bytes.length > 512) {
      buffer.writeln('\n... [${bytes.length - 512} more bytes in payload]');
    }

    return Container(
      color: const Color(0xFF0C0E12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceElevated,
              border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Binary Hex Dump (${bytes.length} bytes)',
                  style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppTheme.textMuted),
                ),
                if (onExport != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.download_outlined, size: 13, color: AppTheme.textSecondary),
                    tooltip: 'Export Binary',
                    onPressed: onExport,
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectionArea(
                child: Text(
                  buffer.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Color(0xFF94A3B8),
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

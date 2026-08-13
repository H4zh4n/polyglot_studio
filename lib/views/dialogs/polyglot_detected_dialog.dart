import 'package:flutter/material.dart';
import 'package:polyglot_core/polyglot_core.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_utils.dart';

/// Clean, understated modal dialog prompting the user when a multi-format polyglot binary is dropped in Studio.
class PolyglotDetectedDialog extends StatelessWidget {
  final String fileName;
  final int fileSize;
  final PolyglotInspectionResult inspection;

  const PolyglotDetectedDialog({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.inspection,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String fileName,
    required PolyglotInspectionResult inspection,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xCC080A0E),
      builder: (context) => PolyglotDetectedDialog(
        fileName: fileName,
        fileSize: inspection.fileSize,
        inspection: inspection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formats = inspection.detectedFormats;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderStrong),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(200),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      size: 22,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Polyglot Binary Detected',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: AppTheme.trackingHeader,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$fileName (${NumberUtils.formatSizeKb(fileSize)})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Description
              const Text(
                'This file contains multiple coexisting valid format personalities. Would you like to inspect its inner streams, or use it as an input asset in Studio?',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              // Detected Formats Pill List
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detected Format Layers',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: formats.map((fmt) => _buildFormatPill(fmt)).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceElevated,
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Use in Studio',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: const Color(0xFF0D0F12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text(
                      'Inspect Polyglot',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatPill(String format) {
    IconData icon = Icons.extension_outlined;
    String label = format.toUpperCase();

    if (format.contains('png') || format.contains('ico') || format.contains('jpg') || format.contains('webp') || format.contains('image')) {
      icon = Icons.image_outlined;
      label = 'Image (${format.toUpperCase()})';
    } else if (format.contains('mp4') || format.contains('m4a') || format.contains('video') || format.contains('audio')) {
      icon = Icons.play_circle_outline_rounded;
      label = format.contains('m4a') ? 'Audio (M4A)' : 'Video (MP4)';
    } else if (format.contains('pdf')) {
      icon = Icons.picture_as_pdf_outlined;
      label = 'Document (PDF v${inspection.pdfVersion ?? '1.4'})';
    } else if (format.contains('html') || format.contains('htm')) {
      icon = Icons.code_rounded;
      label = 'Webpage (HTML5)';
    } else if (format.contains('zip') || format.contains('jar') || format.contains('apk')) {
      icon = Icons.folder_zip_outlined;
      label = 'Archive (ZIP - ${inspection.zipEntries.length} items)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

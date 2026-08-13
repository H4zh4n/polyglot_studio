import 'package:flutter/material.dart';
import 'package:polyglot_core/polyglot_core.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_utils.dart';

/// Interactive summary panel showing packed format icons, combined extension, and a single Save to Disk button.
class GenerationSummarySheet extends StatelessWidget {
  final PolyglotResult result;
  final String combinedFileName;
  final String savedFilePath;
  final VoidCallback onSaveToDisk;
  final VoidCallback? onOpenFolder;

  const GenerationSummarySheet({
    super.key,
    required this.result,
    required this.combinedFileName,
    required this.savedFilePath,
    required this.onSaveToDisk,
    this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderStrong, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Icon(Icons.check, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Polyglot Ready in Memory',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: AppTheme.trackingTight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Multi-format binary assembled and verified',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                NumberUtils.formatSizeKb(result.totalBytes),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: AppTheme.borderSubtle, height: 1),
          const SizedBox(height: 14),

          // Formats packed in this binary with clean neutral chips
          const Text(
            'Supported File Extensions:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: result.supportedExtensions.map((ext) {
              return Container(
                constraints: const BoxConstraints(maxWidth: 140),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getFormatIcon(ext),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        ext,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Suggested combined filename badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.label_outline, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Combined Name: ',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Text(
                    combinedFileName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Single Primary "Save to Disk" Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: const Color(0xFF0D0F12),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: onSaveToDisk,
              icon: const Icon(Icons.save_alt, size: 16),
              label: Text(
                'Save to Disk ($combinedFileName)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Saved path indicator (if saved)
          if (savedFilePath.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saved File Location:',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                        ),
                        SelectableText(
                          savedFilePath,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onOpenFolder != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.textPrimary,
                      ),
                      onPressed: onOpenFolder,
                      icon: const Icon(Icons.folder_open, size: 13),
                      label: const Text('Open', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(color: AppTheme.borderSubtle, height: 1),
          const SizedBox(height: 10),

          // Byte Map Details with thousand separators
          const Text(
            'Internal Atom Details',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          _buildOffsetRow('Dual-Purpose Header (ICO / MP4)', 'Byte 0 .. ${NumberUtils.formatInt(288)} (288 B)'),
          _buildOffsetRow('Embedded PNG Image', 'Byte ${NumberUtils.formatInt(result.pngOffset)} (${NumberUtils.formatSizeKb(result.pngSize)})'),
          _buildOffsetRow('MP4 Video / Audio Container', NumberUtils.formatSizeKb(result.mp4Size)),
          if (result.pdfOffset != null)
            _buildOffsetRow('PDF Encapsulation Stream', 'Byte ${NumberUtils.formatInt(result.pdfOffset!)}'),
          if (result.zipOffset != null)
            _buildOffsetRow('Shifted ZIP Central Directory', 'Byte ${NumberUtils.formatInt(result.zipOffset!)}'),
        ],
      ),
    );
  }

  Widget _buildOffsetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getFormatIcon(String ext) {
    switch (ext) {
      case '.ico':
      case '.png':
        return const Icon(Icons.image_outlined, size: 13, color: AppTheme.textPrimary);
      case '.mp4':
        return const Icon(Icons.videocam_outlined, size: 13, color: AppTheme.textPrimary);
      case '.html':
        return const Icon(Icons.code_outlined, size: 13, color: AppTheme.textPrimary);
      case '.pdf':
        return const Icon(Icons.picture_as_pdf_outlined, size: 13, color: AppTheme.textPrimary);
      case '.zip':
        return const Icon(Icons.folder_zip_outlined, size: 13, color: AppTheme.textPrimary);
      default:
        return const Icon(Icons.insert_drive_file_outlined, size: 13, color: AppTheme.textPrimary);
    }
  }
}

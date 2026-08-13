import 'package:flutter/material.dart';
import 'package:polyglot_core/polyglot_core.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_utils.dart';

/// Visual byte structure and atom inspector with thousand separator formatting.
class AtomMapVisualizer extends StatelessWidget {
  final PolyglotResult? result;

  const AtomMapVisualizer({super.key, this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: const Column(
          children: [
            Icon(Icons.layers_outlined, color: AppTheme.textMuted, size: 28),
            SizedBox(height: 10),
            Text(
              'Atom & Byte Structure',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            SizedBox(height: 4),
            Text(
              'Synthesize a polyglot to inspect atom offsets and byte layout.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    final res = result!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.memory_outlined, size: 16, color: AppTheme.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'Binary Structure & Atom Map',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Text(
                  '${NumberUtils.formatSizeKb(res.totalBytes)} (${NumberUtils.formatInt(res.totalBytes)} B)',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Understated monochrome segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Tooltip(
                      message: 'Dual Header (288 B)',
                      child: Container(color: const Color(0xFFE5E7EB)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 3,
                    child: Tooltip(
                      message: 'Skip Atom: PNG & HTML (${NumberUtils.formatSizeKb(res.pngSize)})',
                      child: Container(color: const Color(0xFF9CA3AF)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 12,
                    child: Tooltip(
                      message: 'MP4 Media Container (${NumberUtils.formatSizeKb(res.mp4Size)})',
                      child: Container(color: const Color(0xFF6B7280)),
                    ),
                  ),
                  if (res.pdfOffset != null) ...[
                    const SizedBox(width: 2),
                    Expanded(
                      flex: 4,
                      child: Tooltip(
                        message: 'PDF Encapsulation Stream',
                        child: Container(color: const Color(0xFF4B5563)),
                      ),
                    ),
                  ],
                  if (res.zipOffset != null) ...[
                    const SizedBox(width: 2),
                    Expanded(
                      flex: 4,
                      child: Tooltip(
                        message: 'ZIP Shifted Central Directory',
                        child: Container(color: const Color(0xFF374151)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Clean offset table with thousand-separated numbers
          _buildDetailRow(
            tag: 'ftyp / ICO',
            name: 'Dual-Purpose Header',
            details: 'Byte 0 .. ${NumberUtils.formatInt(288)} (288 B)',
          ),
          _buildDetailRow(
            tag: 'skip',
            name: 'Embedded PNG Image',
            details: 'Byte ${NumberUtils.formatInt(res.pngOffset)} (${NumberUtils.formatSizeKb(res.pngSize)})',
          ),
          _buildDetailRow(
            tag: 'moov/mdat',
            name: 'MP4 Stream Container',
            details: NumberUtils.formatSizeKb(res.mp4Size),
          ),
          if (res.pdfOffset != null)
            _buildDetailRow(
              tag: '1 0 obj',
              name: 'PDF Encapsulation Stream',
              details: 'Byte ${NumberUtils.formatInt(res.pdfOffset!)}',
            ),
          if (res.zipOffset != null)
            _buildDetailRow(
              tag: 'PK\\x05\\x06',
              name: 'Shifted Central Directory',
              details: 'Byte ${NumberUtils.formatInt(res.zipOffset!)}',
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String tag,
    required String name,
    required String details,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          Text(
            details,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

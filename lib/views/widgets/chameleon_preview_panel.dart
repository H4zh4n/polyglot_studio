import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Chameleon format simulator demonstrating how the single binary adapts to each extension.
class ChameleonPreviewPanel extends StatefulWidget {
  final List<String> supportedExtensions;

  const ChameleonPreviewPanel({
    super.key,
    required this.supportedExtensions,
  });

  @override
  State<ChameleonPreviewPanel> createState() => _ChameleonPreviewPanelState();
}

class _ChameleonPreviewPanelState extends State<ChameleonPreviewPanel> {
  int _selectedFormatIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.supportedExtensions.isEmpty) return const SizedBox.shrink();

    final activeIndex = _selectedFormatIndex < widget.supportedExtensions.length ? _selectedFormatIndex : 0;
    final activeExt = widget.supportedExtensions[activeIndex];

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
          const Row(
            children: [
              Icon(Icons.visibility_outlined, size: 15, color: AppTheme.textSecondary),
              SizedBox(width: 8),
              Text(
                'Chameleon Format Inspector',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Clean monochrome format selection pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.supportedExtensions.asMap().entries.map((entry) {
                final idx = entry.key;
                final ext = entry.value;
                final isSelected = idx == activeIndex;

                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(
                      ext,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF0D0F12) : AppTheme.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surfaceElevated,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.borderSubtle,
                    ),
                    onSelected: (_) => setState(() => _selectedFormatIndex = idx),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Clean format explanation card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: _buildFormatExplanation(activeExt),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatExplanation(String ext) {
    switch (ext) {
      case '.mp4':
        return _buildInfo(
          icon: Icons.videocam_outlined,
          title: 'Video / Audio Container Execution',
          description: 'Media decoders parse atom sizes from byte 0 and secondary ftyp brand at byte 256. Media samples stream from mdat without error.',
        );
      case '.ico':
      case '.png':
        return _buildInfo(
          icon: Icons.image_outlined,
          title: 'Icon / Image Viewer Execution',
          description: 'Image decoders read byte 0 as an ICO directory header. The entry points directly to the 32bpp PNG stream inside the skip atom.',
        );
      case '.html':
        return _buildInfo(
          icon: Icons.code_outlined,
          title: 'Web Browser Document Execution',
          description: 'Web browsers parse the HTML stream. Embedded stylesheet suppresses binary noise with font-size:0, presenting the clean webpage.',
        );
      case '.pdf':
        return _buildInfo(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF Reader Document Execution',
          description: 'PDF engines start from %PDF-1.4 at byte 22, treat the MP4 body as an internal stream object, and resolve pages using the shifted xref table.',
        );
      case '.zip':
        return _buildInfo(
          icon: Icons.folder_zip_outlined,
          title: 'Archive Decompressor Execution',
          description: 'Archive utilities scan backward from EOF to find the End of Central Directory (EOCD). All internal relative file header offsets are aligned.',
        );
      default:
        return _buildInfo(
          icon: Icons.insert_drive_file_outlined,
          title: 'Binary Stream Mode',
          description: 'Raw binary stream accessible by custom scripts and parser routines.',
        );
    }
  }

  Widget _buildInfo({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Icon(icon, color: AppTheme.textPrimary, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

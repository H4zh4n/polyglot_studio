import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:polyglot_core/polyglot_core.dart';
import '../../controllers/polyglot_controller.dart';
import '../../models/app_file.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_utils.dart';
import 'widgets/audio_player_preview.dart';
import 'widgets/html_document_preview.dart';
import 'widgets/image_preview_dialog.dart';
import 'widgets/video_player_preview.dart';

class _InspectorTabItem {
  final String id;
  final String label;
  final IconData icon;

  const _InspectorTabItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Streamlined, unified Polyglot Inspector and Multi-Format Viewer.
class PolyglotInspectorView extends StatefulWidget {
  const PolyglotInspectorView({super.key});

  @override
  State<PolyglotInspectorView> createState() => _PolyglotInspectorViewState();
}

class _PolyglotInspectorViewState extends State<PolyglotInspectorView> {
  int _selectedTabIndex = 0;
  bool _showHexDump = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PolyglotController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final padding = isMobile ? const EdgeInsets.fromLTRB(16, 12, 16, 24) : const EdgeInsets.symmetric(horizontal: 24, vertical: 20);

        return Obx(() {
          final res = controller.inspectionResult.value;

          return SingleChildScrollView(
            padding: padding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Header Banner
                    _buildHeaderBanner(context, controller, res, isMobile),

                    const SizedBox(height: 14),

                    // Empty Drag-and-Drop or Unified Multi-Format Viewer
                    if (res == null)
                      _buildDropZone(controller)
                    else ...[
                      // File Metadata & Format Badges Bar
                      _buildMetadataBar(res, isMobile),

                      const SizedBox(height: 14),

                      // Single Unified Multi-Format Live Viewer Card
                      _buildUnifiedViewerCard(controller, res, isMobile),
                    ],
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildHeaderBanner(BuildContext context, PolyglotController controller, PolyglotInspectionResult? res, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Polyglot Inspector & Viewer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: AppTheme.trackingTight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (res != null) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Clear File',
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                    onPressed: () {
                      setState(() {
                        _selectedTabIndex = 0;
                        _showHexDump = false;
                      });
                      controller.clearInspection();
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'View media, explore archives, inspect headers, and extract payloads.',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: const Color(0xFF0D0F12),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => controller.pickAndInspectFile(),
              icon: const Icon(Icons.file_open_outlined, size: 14),
              label: Text(
                res != null ? 'Open Other File' : 'Open File to View',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: const Icon(Icons.visibility_outlined, size: 20, color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Polyglot Inspector & Viewer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: AppTheme.trackingTight,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'View and interact with embedded images, videos, zip archives, documents, and byte structures.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (res != null) ...[
            IconButton(
              tooltip: 'Clear File',
              icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
              onPressed: () {
                setState(() {
                  _selectedTabIndex = 0;
                  _showHexDump = false;
                });
                controller.clearInspection();
              },
            ),
            const SizedBox(width: 6),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: const Color(0xFF0D0F12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => controller.pickAndInspectFile(),
            icon: const Icon(Icons.file_open_outlined, size: 15),
            label: Text(
              res != null ? 'Open Other File' : 'Open File to View',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone(PolyglotController controller) {
    return DropTarget(
      onDragDone: (detail) {
        if (detail.files.isNotEmpty) {
          controller.inspectFile(AppFile.fromXFile(detail.files.first));
        }
      },
      child: InkWell(
        onTap: () => controller.pickAndInspectFile(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Icon(Icons.remove_red_eye_outlined, size: 28, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Drop any polyglot or media file here to view & inspect',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Live interactive preview of images, videos, zip contents, documents, and byte structures',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceElevated,
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  side: const BorderSide(color: AppTheme.borderSubtle),
                ),
                onPressed: () => controller.pickAndInspectFile(),
                icon: const Icon(Icons.file_open_outlined, size: 14),
                label: const Text('Select File from Disk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataBar(PolyglotInspectionResult res, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.fileName,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  NumberUtils.formatSizeKb(res.fileSize),
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: res.detectedFormats.map((ext) => _buildFormatBadge(ext)).toList(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              res.fileName,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            NumberUtils.formatSizeKb(res.fileSize),
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textMuted),
          ),
          const SizedBox(width: 14),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: res.detectedFormats.map((ext) => _buildFormatBadge(ext)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(String ext) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getFormatIconData(ext), size: 11, color: AppTheme.textPrimary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              ext,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  List<_InspectorTabItem> _getAvailableTabs(PolyglotInspectionResult res) {
    final tabs = <_InspectorTabItem>[];

    // 1. Detected file formats
    for (final ext in res.detectedFormats) {
      if (ext == '.bin') continue; // handled as dedicated payload tab below
      tabs.add(_InspectorTabItem(
        id: ext,
        label: ext,
        icon: _getFormatIconData(ext),
      ));
    }

    // 2. Dead Space Header data
    tabs.add(const _InspectorTabItem(
      id: 'header',
      label: 'Header Space',
      icon: Icons.edit_note_outlined,
    ));

    // 3. Appendable Binary Payload (if present)
    if (res.appendableBytes != null && res.appendableBytes!.isNotEmpty) {
      tabs.add(const _InspectorTabItem(
        id: 'payload',
        label: 'Payload (.bin)',
        icon: Icons.attach_file_outlined,
      ));
    }

    return tabs;
  }

  Widget _buildUnifiedViewerCard(PolyglotController controller, PolyglotInspectionResult res, bool isMobile) {
    final tabs = _getAvailableTabs(res);
    if (tabs.isEmpty) return const SizedBox.shrink();

    final activeIndex = _selectedTabIndex < tabs.length ? _selectedTabIndex : 0;
    final activeTab = tabs[activeIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_outlined, size: 16, color: AppTheme.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Multi-Format Live Viewer (${tabs.length} Formats Available)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Format / Layer Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.asMap().entries.map((entry) {
                final idx = entry.key;
                final tab = entry.value;
                final isSelected = idx == activeIndex;

                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    avatar: Icon(
                      tab.icon,
                      size: 13,
                      color: isSelected ? const Color(0xFF0D0F12) : AppTheme.textSecondary,
                    ),
                    label: Text(
                      tab.label,
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.borderSubtle,
                    ),
                    onSelected: (_) => setState(() {
                      _selectedTabIndex = idx;
                      _showHexDump = false;
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Format Personality / Execution Explanation Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: _buildTabExplanation(res, activeTab.id),
          ),

          const SizedBox(height: 12),

          // Live Content Viewer for Selected Tab
          _buildTabContent(controller, res, activeTab.id),
        ],
      ),
    );
  }

  Widget _buildTabContent(PolyglotController controller, PolyglotInspectionResult res, String tabId) {
    if (tabId == 'header') {
      return _buildHeaderSpacePreview(res);
    } else if (tabId == 'payload') {
      return _buildPayloadPreview(controller, res);
    }

    final clean = tabId.toLowerCase();
    if (['.ico', '.png', '.jpg', '.jpeg', '.webp', '.bmp', '.gif'].contains(clean)) {
      return _buildImagePreview(controller, res);
    } else if (['.zip', '.jar', '.apk', '.docx', '.xlsx', '.pptx'].contains(clean)) {
      return _buildZipPreview(res);
    } else if (['.html', '.htm'].contains(clean)) {
      return _buildHtmlPreview(res);
    } else if (clean == '.pdf') {
      return _buildPdfPreview(res);
    } else if (['.mp3', '.m4a', '.aac', '.wav'].contains(clean)) {
      return _buildAudioPreview(controller, res, clean);
    } else if (['.mp4', '.m4v', '.mov', '.mkv', '.avi'].contains(clean)) {
      return _buildVideoPreview(controller, res, clean);
    }
    return const SizedBox.shrink();
  }

  Widget _buildImagePreview(PolyglotController controller, PolyglotInspectionResult res) {
    final imageBytes = res.extractedImageBytes;
    if (imageBytes == null || imageBytes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Image stream offset is embedded in the ICO directory entry at byte 0.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    final info = res.imageInfo;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(Icons.image, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Decoded Image Stream Viewer',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (info.format != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Text(
                          info.format!,
                          style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.accent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Export Button
              IconButton(
                tooltip: 'Export Image to Disk',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.download_outlined, size: 14, color: AppTheme.textSecondary),
                onPressed: () => controller.extractImageFile(),
              ),
              const SizedBox(width: 4),

              // Expand & Zoom Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: const Color(0xFF0D0F12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => ImagePreviewDialog.show(
                  context,
                  imageBytes: imageBytes,
                  fileName: res.fileName,
                  imageInfo: info,
                  onExport: () => controller.extractImageFile(),
                ),
                icon: const Icon(Icons.zoom_in, size: 14),
                label: const Text('Expand & Zoom', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Interactive Center Thumbnail
          Center(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => ImagePreviewDialog.show(
                  context,
                  imageBytes: imageBytes,
                  fileName: res.fileName,
                  imageInfo: info,
                  onExport: () => controller.extractImageFile(),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 380),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                    color: const Color(0xFF14171D),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('Raw image stream bytes extracted from container', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0D0F12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x33FFFFFF)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, size: 12, color: AppTheme.accent),
                              SizedBox(width: 4),
                              Text(
                                'Tap / Click to expand & zoom',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Technical Specs Row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (info.width != null && info.height != null)
                _buildInfoBadge('Resolution', '${info.width} × ${info.height} px'),
              if (info.aspectRatioString.isNotEmpty)
                _buildInfoBadge('Ratio', info.aspectRatioString),
              if (info.colorDepth != null)
                _buildInfoBadge('Color', '${info.colorDepth}bpp${info.hasAlpha ? ' (Alpha)' : ''}'),
              _buildInfoBadge('Size', NumberUtils.formatSizeKb(imageBytes.length)),
              if (res.pngOffset != null)
                _buildInfoBadge('Stream Offset', 'Byte ${NumberUtils.formatInt(res.pngOffset!)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZipPreview(PolyglotInspectionResult res) {
    final entries = res.zipEntries;
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: const Row(
          children: [
            Icon(Icons.folder_zip_outlined, size: 14, color: AppTheme.textMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ZIP End of Central Directory (EOCD) signature located at file tail.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_zip, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Archive Explorer (${entries.length} ${entries.length == 1 ? 'entry' : 'entries'})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Central Dir: Byte ${NumberUtils.formatInt(res.zipOffset ?? 0)}',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
              itemBuilder: (context, i) {
                final entry = entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        entry.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                        size: 13,
                        color: entry.isDirectory ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.name,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: AppTheme.textPrimary,
                            fontWeight: entry.isDirectory ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NumberUtils.formatSizeKb(entry.size),
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHtmlPreview(PolyglotInspectionResult res) {
    final html = res.extractedHtmlContent;
    if (html == null || html.isEmpty) {
      return const SizedBox.shrink();
    }

    return HtmlDocumentPreview(
      htmlContent: html,
      fileName: res.fileName,
      htmlInfo: res.htmlInfo,
    );
  }

  Widget _buildPdfPreview(PolyglotInspectionResult res) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Encapsulated PDF Document Stream',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (res.extractedPdfBytes != null) ...[
                const SizedBox(width: 6),
                Text(
                  NumberUtils.formatSizeKb(res.extractedPdfBytes!.length),
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildInfoBadge('Spec Version', 'PDF v${res.pdfVersion ?? '1.4'}'),
              _buildInfoBadge('Page Objects', '${res.pdfPageCount > 0 ? res.pdfPageCount : 1} Page'),
              _buildInfoBadge('Stream Offset', 'Byte ${NumberUtils.formatInt(res.pdfOffset ?? 0)}'),
              _buildInfoBadge('Shifted XREF', 'Dual-Table Verified'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview(PolyglotController controller, PolyglotInspectionResult res, String format) {
    final audioBytes = res.extractedAudioBytes ?? res.rawBytes ?? res.headerBytes;
    return AudioPlayerPreview(
      audioBytes: audioBytes,
      fileName: res.fileName,
      format: format,
      mediaInfo: res.mediaInfo,
    );
  }

  Widget _buildVideoPreview(PolyglotController controller, PolyglotInspectionResult res, String format) {
    final videoBytes = res.extractedMediaBytes ?? res.rawBytes ?? res.headerBytes;
    return VideoPlayerPreview(
      videoBytes: videoBytes,
      fileName: res.fileName,
      format: format,
      mediaInfo: res.mediaInfo,
      headerBytes: res.headerBytes,
    );
  }

  Widget _buildHeaderSpacePreview(PolyglotInspectionResult res) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_outlined, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Dead Space Header Data (Byte 22 .. 240)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() => _showHexDump = !_showHexDump),
                icon: const Icon(Icons.code, size: 13, color: AppTheme.textSecondary),
                label: Text(
                  _showHexDump ? 'Hide Hex' : 'Header Hex',
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: res.extraHeaderString.isNotEmpty ? AppTheme.borderStrong : AppTheme.borderSubtle,
              ),
            ),
            child: res.extraHeaderString.isNotEmpty
                ? SelectableText(
                    res.extraHeaderString,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  )
                : const Text(
                    '<No extra string data present in header dead space>',
                    style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
          ),
          if (_showHexDump) ...[
            const SizedBox(height: 10),
            _buildHexDumpWidget(res.headerBytes),
          ],
        ],
      ),
    );
  }

  Widget _buildPayloadPreview(PolyglotController controller, PolyglotInspectionResult res) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Appendable Payload (${NumberUtils.formatBytesExact(res.appendableSize ?? 0)})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: const Color(0xFF0D0F12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => controller.extractAppendablePayload(),
                icon: const Icon(Icons.download_outlined, size: 13),
                label: const Text('Extract to Disk', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Offset: Byte ${NumberUtils.formatInt(res.appendableOffset ?? 0)} • Located before ZIP Central Directory',
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                res.appendablePreviewText ?? '<Raw Binary Data>',
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.textSecondary, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexDumpWidget(List<int> bytes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          _formatHexDump(bytes),
          style: const TextStyle(
            fontSize: 9.5,
            fontFamily: 'monospace',
            color: AppTheme.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
        softWrap: true,
      ),
    );
  }

  Widget _buildTabExplanation(PolyglotInspectionResult res, String tabId) {
    if (tabId == 'header') {
      return _buildInfo(
        icon: Icons.edit_note_outlined,
        title: 'Header Dead Space (Byte 22 .. 240)',
        description: 'Between the initial ICO image directory (byte 22) and the MP4 secondary ftyp brand (byte 256) lies 218 bytes of dead space used for metadata, comments, or scripts.',
        offsetInfo: 'Capacity: 218 Bytes',
      );
    } else if (tabId == 'payload') {
      return _buildInfo(
        icon: Icons.attach_file_outlined,
        title: 'Appendable Binary Payload',
        description: 'Raw binary payload appended before the archive boundary, accessible for direct extraction and analysis without corrupting media decoders.',
        offsetInfo: res.appendableOffset != null ? 'Byte ${NumberUtils.formatInt(res.appendableOffset!)}' : null,
      );
    }

    switch (tabId.toLowerCase()) {
      case '.mp4':
      case '.m4v':
      case '.mov':
      case '.mkv':
      case '.avi':
        return _buildInfo(
          icon: Icons.videocam_outlined,
          title: 'Video / Audio Container Execution (MP4 / ISOBMFF)',
          description: 'Media decoders parse atom boxes starting from byte 0 and secondary ftyp brand at byte 256. Media samples stream from mdat without error.',
          offsetInfo: res.hasSecondaryFtyp ? 'Secondary ftyp @ Byte 256' : 'ISO Atom Stream',
        );
      case '.mp3':
      case '.m4a':
      case '.aac':
      case '.wav':
        return _buildInfo(
          icon: Icons.audiotrack_outlined,
          title: 'Audio Container Execution ($tabId)',
          description: 'Audio players decode the audio track within the ISOBMFF container seamlessly.',
          offsetInfo: 'Audio Stream Track',
        );
      case '.ico':
        return _buildInfo(
          icon: Icons.image_outlined,
          title: 'Icon Resource Execution (ICO)',
          description: 'Image decoders read byte 0 as an ICO directory header (00 00 01 00). The entry points directly to the 32bpp PNG image stream.',
          offsetInfo: 'Header: Byte 0 .. 22',
        );
      case '.png':
        return _buildInfo(
          icon: Icons.image_outlined,
          title: 'Embedded PNG Image Viewer Execution',
          description: 'Image viewers load the embedded 32bpp PNG stream directly at the offset recorded in the ICO directory entry.',
          offsetInfo: res.pngOffset != null ? 'Offset: Byte ${NumberUtils.formatInt(res.pngOffset!)}' : null,
        );
      case '.html':
      case '.htm':
        return _buildInfo(
          icon: Icons.code_outlined,
          title: 'Web Browser Document Execution (HTML)',
          description: 'Web browsers parse the HTML stream. Embedded stylesheet suppresses binary noise with font-size:0, presenting the clean webpage.',
          offsetInfo: 'HTML Stylesheet Injection',
        );
      case '.pdf':
        return _buildInfo(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF Reader Document Execution',
          description: 'PDF engines start from %PDF-1.4, encapsulate the MP4 body as an internal stream object, and resolve pages using the shifted xref table.',
          offsetInfo: res.pdfOffset != null ? 'Offset: Byte ${NumberUtils.formatInt(res.pdfOffset!)}' : null,
        );
      case '.zip':
      case '.jar':
      case '.apk':
      case '.docx':
      case '.xlsx':
      case '.pptx':
        return _buildInfo(
          icon: Icons.folder_zip_outlined,
          title: 'Archive Decompressor Execution ($tabId)',
          description: 'Archive utilities scan backward from EOF to find the End of Central Directory (EOCD). All internal relative file header offsets are preserved.',
          offsetInfo: res.zipOffset != null ? 'Central Dir: Byte ${NumberUtils.formatInt(res.zipOffset!)}' : 'EOCD at File Tail',
        );
      default:
        return _buildInfo(
          icon: Icons.insert_drive_file_outlined,
          title: 'Binary Stream Mode ($tabId)',
          description: 'Raw multi-format binary layer recognized in output stream.',
          offsetInfo: null,
        );
    }
  }

  Widget _buildInfo({
    required IconData icon,
    required String title,
    required String description,
    String? offsetInfo,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  if (offsetInfo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Text(
                        offsetInfo,
                        style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
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

  IconData _getFormatIconData(String ext) {
    switch (ext.toLowerCase()) {
      case '.ico':
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.webp':
      case '.bmp':
        return Icons.image_outlined;
      case '.mp4':
      case '.m4v':
      case '.mov':
      case '.mkv':
      case '.avi':
        return Icons.videocam_outlined;
      case '.mp3':
      case '.m4a':
      case '.aac':
      case '.wav':
        return Icons.audiotrack_outlined;
      case '.html':
      case '.htm':
        return Icons.code_outlined;
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.zip':
      case '.jar':
      case '.apk':
      case '.docx':
      case '.xlsx':
      case '.pptx':
        return Icons.folder_zip_outlined;
      case '.bin':
        return Icons.attach_file_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatHexDump(List<int> bytes) {
    final buffer = StringBuffer();
    final maxLen = bytes.length >= 256 ? 256 : bytes.length;

    for (int i = 0; i < maxLen; i += 16) {
      buffer.write(i.toRadixString(16).padLeft(4, '0'));
      buffer.write(': ');

      final chunk = bytes.sublist(i, (i + 16 <= maxLen) ? i + 16 : maxLen);
      for (int j = 0; j < 16; j++) {
        if (j < chunk.length) {
          buffer.write(chunk[j].toRadixString(16).padLeft(2, '0'));
          buffer.write(' ');
        } else {
          buffer.write('   ');
        }
        if (j == 7) buffer.write(' ');
      }

      buffer.write(' |');
      for (final b in chunk) {
        if (b >= 32 && b <= 126) {
          buffer.write(String.fromCharCode(b));
        } else {
          buffer.write('.');
        }
      }
      buffer.write('|\n');
    }

    return buffer.toString().trimRight();
  }
}

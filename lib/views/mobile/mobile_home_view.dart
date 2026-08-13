import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/polyglot_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/drop_zone_card.dart';
import '../widgets/generation_summary_sheet.dart';
import '../widgets/header_data_info_dialog.dart';

/// Mobile touch-first layout with collapsible sections and floating command deck (Focused on Generator).
class MobileHomeView extends StatefulWidget {
  const MobileHomeView({super.key});

  @override
  State<MobileHomeView> createState() => _MobileHomeViewState();
}

class _MobileHomeViewState extends State<MobileHomeView> {
  bool _isOptionalExpanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PolyglotController>();

    return Obx(() {
      final res = controller.polyglotResult.value;
      final optionalCount = (controller.pdfFile.value != null ? 1 : 0) +
          (controller.htmlFile.value != null || controller.htmlDirectText.value.isNotEmpty ? 1 : 0) +
          controller.zipFiles.length +
          controller.appendableFiles.length +
          (controller.extraHeaderData.value.isNotEmpty ? 1 : 0);

      return Stack(
        children: [
          // Scrollable Touch Content
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Base Media Header
                  _buildMobileSectionTitle('1. Required Base Media', Icons.star_outline),
                  const SizedBox(height: 8),

                  DropZoneCard(
                    title: 'Primary Image',
                    description: 'Normalized to 32bpp PNG (ICO header)',
                    icon: Icons.image_outlined,
                    isRequired: true,
                    isCompact: true,
                    selectedFile: controller.imageFile.value,
                    onTap: () => controller.pickImage(),
                    onClear: () => controller.imageFile.value = null,
                  ),
                  const SizedBox(height: 8),
                  DropZoneCard(
                    title: 'Video / Audio',
                    description: 'MP4 container stream with shifted tables',
                    icon: Icons.videocam_outlined,
                    isRequired: true,
                    isCompact: true,
                    selectedFile: controller.mediaFile.value,
                    onTap: () => controller.pickMedia(),
                    onClear: () => controller.mediaFile.value = null,
                  ),

                  const SizedBox(height: 14),

                  // Optional Payloads Accordion
                  Material(
                    color: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: _isOptionalExpanded,
                        onExpansionChanged: (val) => setState(() => _isOptionalExpanded = val),
                        leading: const Icon(Icons.layers_outlined, size: 16, color: AppTheme.textSecondary),
                        title: const Text(
                          '2. Optional Payloads',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (optionalCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: Text(
                                  '$optionalCount added',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                              ),
                            const SizedBox(width: 4),
                            Icon(
                              _isOptionalExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            child: Column(
                              children: [
                                DropZoneCard(
                                  title: 'PDF Document',
                                  description: 'Stream encapsulated with shifted xref',
                                  icon: Icons.picture_as_pdf_outlined,
                                  isCompact: true,
                                  selectedFile: controller.pdfFile.value,
                                  onTap: () => controller.pickPdf(),
                                  onClear: () => controller.pdfFile.value = null,
                                ),
                                const SizedBox(height: 8),
                                DropZoneCard(
                                  title: 'HTML Document',
                                  description: 'Webpage with CSS font suppression',
                                  icon: Icons.code_outlined,
                                  isCompact: true,
                                  selectedFile: controller.htmlFile.value,
                                  onTap: () => controller.pickHtml(),
                                  onClear: () => controller.htmlFile.value = null,
                                ),
                                const SizedBox(height: 8),
                                DropZoneCard(
                                  title: 'ZIP Archives',
                                  description: 'Merged & shifted (ZIP, APK, DOCX)',
                                  icon: Icons.folder_zip_outlined,
                                  isCompact: true,
                                  selectedFiles: controller.zipFiles.toList(),
                                  onTap: () => controller.pickZipFiles(),
                                  onClear: () => controller.zipFiles.clear(),
                                ),
                                const SizedBox(height: 8),
                                DropZoneCard(
                                  title: 'Appendable Binaries',
                                  description: 'Raw binary files appended before ZIP',
                                  icon: Icons.attach_file_outlined,
                                  isCompact: true,
                                  selectedFiles: controller.appendableFiles.toList(),
                                  onTap: () => controller.pickAppendables(),
                                  onClear: () => controller.appendableFiles.clear(),
                                ),
                                const SizedBox(height: 8),

                                // Extra Header Data with Strict 200B limit on Mobile
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.borderSubtle),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.edit_note_outlined, size: 15, color: AppTheme.textSecondary),
                                          const SizedBox(width: 6),
                                          const Expanded(
                                            child: Text(
                                              'Header Extra Data',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surface,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppTheme.borderSubtle),
                                            ),
                                            child: Text(
                                              '${controller.extraHeaderData.value.length}/200 B',
                                              style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () => HeaderDataInfoDialog.show(context),
                                            borderRadius: BorderRadius.circular(10),
                                            child: const Padding(
                                              padding: EdgeInsets.all(2.0),
                                              child: Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.background,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text(
                                              '> ',
                                              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                maxLength: 200,
                                                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                                cursorColor: AppTheme.textPrimary,
                                                cursorWidth: 1.5,
                                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
                                                decoration: const InputDecoration(
                                                  counterText: '',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                  hintText: 'e.g. MagicHeader / Custom Tag',
                                                  hintStyle: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textMuted),
                                                  border: InputBorder.none,
                                                  enabledBorder: InputBorder.none,
                                                  focusedBorder: InputBorder.none,
                                                ),
                                                onChanged: (val) => controller.extraHeaderData.value = val,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Result Card if generated
                  if (res != null) ...[
                    const SizedBox(height: 14),
                    GenerationSummarySheet(
                      result: res,
                      combinedFileName: controller.combinedFileName,
                      savedFilePath: controller.lastSavedFilePath.value,
                      onSaveToDisk: () => controller.saveToDisk(),
                      onOpenFolder: () => controller.openContainingFolder(),
                    ),
                  ],

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Floating Glassmorphic Bottom Command Deck
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.9),
                    border: const Border(top: BorderSide(color: AppTheme.borderSubtle)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.isGenerating.value) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: controller.progress.value > 0 ? controller.progress.value : null,
                              backgroundColor: AppTheme.surfaceElevated,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                              minHeight: 2.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            controller.statusMessage.value,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          children: [
                            // Always present Generate / Re-generate button
                            Expanded(
                              flex: res != null ? 5 : 10,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: res != null ? AppTheme.surfaceElevated : AppTheme.primary,
                                  foregroundColor: res != null ? AppTheme.textPrimary : const Color(0xFF0D0F12),
                                  side: res != null ? const BorderSide(color: AppTheme.borderSubtle) : null,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: controller.canGenerate ? () => controller.generatePolyglotInMemory() : null,
                                icon: Icon(
                                  controller.isGenerating.value
                                      ? Icons.hourglass_top
                                      : (res != null ? Icons.refresh : Icons.bolt),
                                  size: 15,
                                ),
                                label: Text(
                                  controller.isGenerating.value
                                      ? 'Synthesizing...'
                                      : (res != null ? 'Re-generate' : 'Generate Polyglot'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            // Dedicated Save button when ready
                            if (res != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: const Color(0xFF0D0F12),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => controller.saveToDisk(),
                                  icon: const Icon(Icons.save_alt, size: 15),
                                  label: const Text(
                                    'Save to Disk',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMobileSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

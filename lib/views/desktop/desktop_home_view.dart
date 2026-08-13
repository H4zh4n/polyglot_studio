import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/polyglot_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_utils.dart';
import '../widgets/atom_map_visualizer.dart';
import '../widgets/chameleon_preview_panel.dart';
import '../widgets/desktop_workbench_card.dart';
import '../widgets/header_data_info_dialog.dart';

/// Desktop Studio 2-Pane Layout for wide screens (Focused purely on Polyglot Generation).
class DesktopHomeView extends StatelessWidget {
  const DesktopHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PolyglotController>();

    return Obx(() {
      final res = controller.polyglotResult.value;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pane: Media Workbench
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 24, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Base Media
                  _buildSectionHeader('1. Core Base Media', 'Image and Video container foundations', Icons.star_outline),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DesktopWorkbenchCard(
                            title: 'Primary Image',
                            description: 'Normalized to 32bpp PNG in ICO header',
                            icon: Icons.image_outlined,
                            isRequired: true,
                            selectedFile: controller.imageFile.value,
                            onTap: () => controller.pickImage(),
                            onClear: () => controller.imageFile.value = null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DesktopWorkbenchCard(
                            title: 'Video / Audio',
                            description: 'ISO Base Media MP4/M4A container',
                            icon: Icons.videocam_outlined,
                            isRequired: true,
                            selectedFile: controller.mediaFile.value,
                            onTap: () => controller.pickMedia(),
                            onClear: () => controller.mediaFile.value = null,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Step 2: Payloads
                  _buildSectionHeader('2. Polyglot Payloads', 'Optional multi-format payload embeddings', Icons.layers_outlined),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DesktopWorkbenchCard(
                            title: 'PDF Document',
                            description: 'Stream encapsulated with shifted xref',
                            icon: Icons.picture_as_pdf_outlined,
                            selectedFile: controller.pdfFile.value,
                            onTap: () => controller.pickPdf(),
                            onClear: () => controller.pdfFile.value = null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DesktopWorkbenchCard(
                            title: 'HTML Document',
                            description: 'CSS font-suppressed webpage embedding',
                            icon: Icons.code_outlined,
                            selectedFile: controller.htmlFile.value,
                            onTap: () => controller.pickHtml(),
                            onClear: () => controller.htmlFile.value = null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DesktopWorkbenchCard(
                            title: 'ZIP Archives',
                            description: 'Merged & shifted (ZIP, APK, JAR, DOCX)',
                            icon: Icons.folder_zip_outlined,
                            selectedFiles: controller.zipFiles.toList(),
                            onTap: () => controller.pickZipFiles(),
                            onClear: () => controller.zipFiles.clear(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DesktopWorkbenchCard(
                            title: 'Appendable Binaries',
                            description: 'Raw binary files appended before ZIP tail',
                            icon: Icons.attach_file_outlined,
                            selectedFiles: controller.appendableFiles.toList(),
                            onTap: () => controller.pickAppendables(),
                            onClear: () => controller.appendableFiles.clear(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Extra Data String with Strict 200B Cap & Info Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note_outlined, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Header Extra Data',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceElevated,
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
                              const Text(
                                'Inserted into dead space at byte offset 22 (Max 200 bytes)',
                                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 190,
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                    hintText: 'e.g. MagicHeader',
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
          ),

          // Right Pane: Inspector & Action Center
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step 3: Synthesis & Inspector Header (Levels with Left Pane Step 1)
                  _buildSectionHeader('3. Output & Synthesis', 'Assembly pipeline and atom inspector', Icons.auto_awesome_outlined),
                  const SizedBox(height: 12),

                  // Hero Synthesis Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: res != null ? AppTheme.borderStrong : AppTheme.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.borderSubtle),
                              ),
                              child: Icon(
                                res != null ? Icons.check : Icons.auto_awesome_outlined,
                                color: res != null ? AppTheme.accent : AppTheme.textPrimary,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    res != null ? 'Polyglot Ready' : 'Polyglot Studio',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: AppTheme.trackingTight,
                                    ),
                                  ),
                                  Text(
                                    res != null ? 'Synthesized in memory' : 'Configure assets on left to synthesize',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (res != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: Text(
                                  NumberUtils.formatSizeKb(res.totalBytes),
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (controller.isGenerating.value) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: controller.progress.value > 0 ? controller.progress.value : null,
                              backgroundColor: AppTheme.surfaceElevated,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            controller.statusMessage.value,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Always-present "Generate Polyglot" Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: res != null ? AppTheme.surfaceElevated : AppTheme.primary,
                              foregroundColor: res != null ? AppTheme.textPrimary : const Color(0xFF0D0F12),
                              side: res != null ? const BorderSide(color: AppTheme.borderSubtle) : null,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                                  : (res != null ? 'Re-generate Polyglot' : 'Generate Polyglot in Memory'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        // Dedicated "Save to Disk" Button when polyglot is ready
                        if (res != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: const Color(0xFF0D0F12),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => controller.saveToDisk(),
                              icon: const Icon(Icons.save_alt, size: 15),
                              label: Text(
                                'Save to Disk (${controller.combinedFileName})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],

                        if (res != null && controller.lastSavedFilePath.value.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 13, color: AppTheme.accent),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    controller.lastSavedFilePath.value,
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: AppTheme.textPrimary,
                                  ),
                                  onPressed: () => controller.openContainingFolder(),
                                  icon: const Icon(Icons.folder_open, size: 12),
                                  label: const Text('Open', style: TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Atom Map Visualizer
                  AtomMapVisualizer(result: res),

                  const SizedBox(height: 14),

                  // Chameleon Simulator Panel
                  if (res != null)
                    ChameleonPreviewPanel(supportedExtensions: res.supportedExtensions),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: AppTheme.trackingTight,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

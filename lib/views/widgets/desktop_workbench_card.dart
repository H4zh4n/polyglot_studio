import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/app_file.dart';
import '../../theme/app_theme.dart';

/// Highly crafted workbench card tailored for desktop studio layout with responsive file badges and overflow safety.
class DesktopWorkbenchCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final AppFile? selectedFile;
  final List<AppFile>? selectedFiles;
  final bool isRequired;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Widget? trailing;

  const DesktopWorkbenchCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.selectedFile,
    this.selectedFiles,
    this.isRequired = false,
    required this.onTap,
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final hasSingle = selectedFile != null;
    final hasMultiple = selectedFiles != null && selectedFiles!.isNotEmpty;
    final hasSelection = hasSingle || hasMultiple;

    return Container(
      decoration: BoxDecoration(
        color: hasSelection ? AppTheme.surfaceElevated : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasSelection ? AppTheme.borderStrong : AppTheme.borderSubtle,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top section: Icon, Title, Required Pill, Action
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: hasSelection ? AppTheme.surfaceHighlight : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: hasSelection ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: AppTheme.trackingTight,
                                ),
                              ),
                              if (isRequired)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.borderSubtle),
                                  ),
                                  child: const Text(
                                    'Required',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (onClear != null && hasSelection)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 15, color: AppTheme.textMuted),
                        onPressed: onClear,
                        tooltip: 'Remove',
                      )
                    else if (hasSelection)
                      const Icon(Icons.check_circle, size: 15, color: AppTheme.accent)
                    else
                      const Icon(Icons.add, size: 15, color: AppTheme.textMuted),
                  ],
                ),

                // Lower slot: file details or clean empty dropzone
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: hasSingle
                      ? _buildSingleFileSlot(selectedFile!)
                      : hasMultiple
                          ? _buildMultiFileSlot(selectedFiles!)
                          : _buildEmptySlot(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.file_upload_outlined, size: 12, color: AppTheme.textMuted),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Drop file or click to select',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(AppFile file) {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return Image.memory(
        file.bytes!,
        width: 22,
        height: 22,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 13, color: AppTheme.textPrimary),
      );
    }
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      return Image.file(
        File(file.path!),
        width: 22,
        height: 22,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 13, color: AppTheme.textPrimary),
      );
    }
    return const Icon(Icons.image_outlined, size: 13, color: AppTheme.textPrimary);
  }

  Widget _buildSingleFileSlot(AppFile file) {
    final name = file.name;
    final isImg = file.isImage;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          if (isImg)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildThumbnail(file),
            )
          else
            const Icon(Icons.insert_drive_file_outlined, size: 13, color: AppTheme.textPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiFileSlot(List<AppFile> files) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: files.map((f) {
        final name = f.name;
        return Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 11, color: AppTheme.textPrimary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

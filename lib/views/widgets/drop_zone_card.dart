import 'package:flutter/material.dart';
import '../../models/app_file.dart';
import '../../theme/app_theme.dart';

/// Symmetrical responsive card component for selecting or dropping input assets.
class DropZoneCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final AppFile? selectedFile;
  final List<AppFile>? selectedFiles;
  final bool isRequired;
  final bool isCompact;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Widget? customTrailing;

  const DropZoneCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.selectedFile,
    this.selectedFiles,
    this.isRequired = false,
    this.isCompact = false,
    required this.onTap,
    this.onClear,
    this.customTrailing,
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
            padding: EdgeInsets.all(isCompact ? 12.0 : 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top section: Icon, Title, Description, Action
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isCompact ? 6 : 7),
                          decoration: BoxDecoration(
                            color: hasSelection ? AppTheme.surfaceHighlight : AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Icon(
                            icon,
                            size: isCompact ? 16 : 18,
                            color: hasSelection ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: isCompact ? 13 : 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                        letterSpacing: AppTheme.trackingTight,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isRequired) ...[
                                    const SizedBox(width: 6),
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
                                ],
                              ),
                              if (!isCompact) ...[
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
                  ],
                ),

                // Bottom section: File badge or empty placeholder
                Padding(
                  padding: EdgeInsets.only(top: isCompact ? 8.0 : 10.0),
                  child: hasSingle
                      ? _buildFileBadge(selectedFile!)
                      : hasMultiple
                          ? Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: selectedFiles!.map((f) => _buildFileBadge(f)).toList(),
                            )
                          : _buildEmptyPlaceholder(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    if (isCompact) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: const Text(
        'Drop file or click to select',
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.textMuted,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFileBadge(AppFile file) {
    final name = file.name;
    return Container(
      constraints: BoxConstraints(maxWidth: isCompact ? 160 : 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 12, color: AppTheme.textPrimary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 11,
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
  }
}

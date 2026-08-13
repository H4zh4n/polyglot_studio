import 'dart:io' show Directory, File;
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:polyglot_core/polyglot_core.dart';
import 'image_preview_dialog.dart';
import 'universal_file_preview.dart';
import '../../../controllers/polyglot_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/notify.dart';
import '../../../utils/number_utils.dart';

enum ZipViewTab {
  files,
  overview,
  audit,
}

/// Comprehensive, pro-grade interactive ZIP Archive Explorer, In-App Decompression Viewer, and Central Directory Inspector.
class ZipArchivePreview extends StatefulWidget {
  final Uint8List zipBytes;
  final Uint8List? rawBytes;
  final String fileName;
  final int? zipOffset;
  final List<ZipEntryInfo> entries;
  final VoidCallback? onExport;

  const ZipArchivePreview({
    super.key,
    required this.zipBytes,
    this.rawBytes,
    required this.fileName,
    this.zipOffset,
    this.entries = const [],
    this.onExport,
  });

  @override
  State<ZipArchivePreview> createState() => _ZipArchivePreviewState();
}

class _ZipArchivePreviewState extends State<ZipArchivePreview> {
  ZipViewTab _selectedTab = ZipViewTab.files;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ZipEntryInfo? _selectedEntry;

  Archive? _decodedArchive;
  final Map<String, Uint8List> _decompressedCache = {};
  bool _isDecompressing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    if (widget.entries.isNotEmpty) {
      _selectedEntry = widget.entries.firstWhere(
        (e) => !e.isDirectory,
        orElse: () => widget.entries.first,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ZipArchivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zipBytes != widget.zipBytes || oldWidget.rawBytes != widget.rawBytes) {
      _decodedArchive = null;
      _decompressedCache.clear();
      if (widget.entries.isNotEmpty) {
        _selectedEntry = widget.entries.firstWhere(
          (e) => !e.isDirectory,
          orElse: () => widget.entries.first,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Archive? _getArchive() {
    if (_decodedArchive != null) return _decodedArchive;
    if (widget.zipBytes.isNotEmpty) {
      try {
        _decodedArchive = ZipDecoder().decodeBytes(widget.zipBytes, verify: false);
        if (_decodedArchive != null && _decodedArchive!.isNotEmpty) {
          return _decodedArchive;
        }
      } catch (_) {}
    }
    if (widget.rawBytes != null && widget.rawBytes!.isNotEmpty) {
      try {
        _decodedArchive = ZipDecoder().decodeBytes(widget.rawBytes!, verify: false);
        if (_decodedArchive != null && _decodedArchive!.isNotEmpty) {
          return _decodedArchive;
        }
      } catch (_) {}
    }
    return null;
  }

  Uint8List? _getDecompressedBytes(String entryName) {
    if (_decompressedCache.containsKey(entryName)) {
      return _decompressedCache[entryName];
    }
    final archive = _getArchive();
    if (archive == null) return null;

    final file = archive.findFile(entryName);
    if (file != null && file.isFile) {
      final bytes = file.content;
      _decompressedCache[entryName] = bytes;
      return bytes;
    }
    return null;
  }

  Future<void> _extractSingleEntry(ZipEntryInfo entry) async {
    final bytes = _getDecompressedBytes(entry.name);
    if (bytes == null) {
      Notify.error('Extraction Failed', description: 'Could not decompress ${entry.name}');
      return;
    }

    final cleanFileName = p.basename(entry.name);
    final ext = p.extension(cleanFileName).replaceAll('.', '').toLowerCase();

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save Extracted File to Disk',
      fileName: cleanFileName,
      type: ext.isNotEmpty ? FileType.custom : FileType.any,
      allowedExtensions: ext.isNotEmpty ? [ext] : null,
      bytes: bytes,
    );

    if (kIsWeb) {
      Notify.success('File Downloaded', description: 'Downloaded $cleanFileName (${NumberUtils.formatSizeKb(bytes.length)})');
      return;
    }

    if (savePath != null) {
      final file = File(savePath);
      await file.writeAsBytes(bytes);
      Notify.success('File Extracted', description: 'Saved $cleanFileName to $savePath');
    }
  }

  Future<void> _extractAllFiles() async {
    final archive = _getArchive();
    if (archive == null || archive.isEmpty) {
      Notify.error('Extraction Failed', description: 'Could not decode ZIP archive structure');
      return;
    }

    if (kIsWeb) {
      Notify.info('Web Environment', description: 'Select individual files to decompress and download on Web');
      return;
    }

    final targetDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Output Directory for Extracted Files',
    );

    if (targetDir == null) return;

    setState(() => _isDecompressing = true);

    try {
      int extractedCount = 0;
      for (final file in archive.files) {
        final outPath = p.join(targetDir, file.name);
        if (!file.isFile || file.name.endsWith('/')) {
          Directory(outPath).createSync(recursive: true);
        } else {
          File(outPath).createSync(recursive: true);
          final content = file.content;
          File(outPath).writeAsBytesSync(content);
          extractedCount++;
        }
      }

      Notify.success(
        'Archive Extracted',
        description: 'Successfully extracted $extractedCount files to $targetDir',
      );
    } catch (e) {
      Notify.error('Extraction Error', description: '$e');
    } finally {
      if (mounted) setState(() => _isDecompressing = false);
    }
  }

  void _copyFileListToClipboard() {
    final buffer = StringBuffer();
    buffer.writeln('=== ZIP Archive Contents: ${widget.fileName} ===');
    buffer.writeln('Total Entries: ${widget.entries.length}');
    buffer.writeln('Archive Size: ${NumberUtils.formatSizeKb(widget.zipBytes.length)}');
    buffer.writeln('----------------------------------------------------');
    for (final e in widget.entries) {
      final type = e.isDirectory ? '[DIR] ' : '[FILE]';
      buffer.writeln('$type ${e.name} (${NumberUtils.formatSizeKb(e.size)}) [CRC32: ${e.crc32 != null ? '0x${e.crc32!.toRadixString(16).toUpperCase()}' : 'N/A'}]');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    Notify.success('Copied File List', description: 'Archive entries copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PolyglotController>() ? Get.find<PolyglotController>() : null;
    final entries = widget.entries;
    final totalUncompressed = entries.fold<int>(0, (sum, e) => sum + e.size);
    final totalCompressed = entries.fold<int>(0, (sum, e) => sum + e.compressedSize);
    final savingsPercent = totalUncompressed > 0
        ? (((totalUncompressed - totalCompressed) / totalUncompressed) * 100).clamp(0.0, 99.9).toStringAsFixed(1)
        : '0.0';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Row: Archive Title, Format Badge, Badges, and Action Buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Icon(Icons.folder_zip_outlined, size: 16, color: AppTheme.accent),
                  Text(
                    widget.fileName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(
                      '${entries.length} ${entries.length == 1 ? 'Item' : 'Items'}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  _buildTechBadge(NumberUtils.formatSizeKb(widget.zipBytes.length), const Color(0xFF38BDF8), Icons.data_usage_rounded),
                  _buildTechBadge('$savingsPercent% Saved', const Color(0xFF34D399), Icons.compress_rounded),
                  if (widget.zipOffset != null && widget.zipOffset! > 0)
                    _buildTechBadge('Byte ${NumberUtils.formatInt(widget.zipOffset!)}', const Color(0xFFFBBF24), Icons.place_outlined),
                ],
              ),

              // Action Buttons: Extract All, Copy List, Export ZIP
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceElevated,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isDecompressing ? null : _extractAllFiles,
                    icon: _isDecompressing
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary))
                        : const Icon(Icons.folder_open_outlined, size: 13, color: AppTheme.textSecondary),
                    label: const Text(
                      'Extract All',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
                    tooltip: 'Copy File List',
                    onPressed: _copyFileListToClipboard,
                  ),
                  if (widget.onExport != null || controller != null) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.download_outlined, size: 14, color: AppTheme.textSecondary),
                      tooltip: 'Export ZIP Archive',
                      onPressed: () {
                        if (widget.onExport != null) {
                          widget.onExport!();
                        } else {
                          controller?.extractZipFile();
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Navigation Tabs (Archive Files / Overview / Central Directory Audit)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(child: _buildNavTab(ZipViewTab.files, 'Archive Files (${entries.length})', Icons.folder_open_rounded)),
                Expanded(child: _buildNavTab(ZipViewTab.overview, 'Overview & Stats', Icons.dashboard_outlined)),
                Expanded(child: _buildNavTab(ZipViewTab.audit, 'Central Directory Audit', Icons.account_tree_outlined)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Active Tab View
          _buildActiveTabContent(),

          const SizedBox(height: 12),

          // 4. Document Specs Footer
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildInfoBadge('Archive Size', NumberUtils.formatSizeKb(widget.zipBytes.length)),
              _buildInfoBadge('Uncompressed', NumberUtils.formatSizeKb(totalUncompressed)),
              _buildInfoBadge('Files', '${entries.where((e) => !e.isDirectory).length} files'),
              _buildInfoBadge('Directories', '${entries.where((e) => e.isDirectory).length} folders'),
              if (widget.zipOffset != null)
                _buildInfoBadge('Offset', 'Byte ${NumberUtils.formatInt(widget.zipOffset!)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab(ZipViewTab tab, String label, IconData icon) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.background : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected
              ? [
                  const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTab) {
      case ZipViewTab.files:
        return _buildFilesTab();
      case ZipViewTab.overview:
        return _buildOverviewTab();
      case ZipViewTab.audit:
        return _buildAuditTab();
    }
  }

  /// Tab 1: Interactive File Explorer with Search & In-App Decompression Preview
  Widget _buildFilesTab() {
    final filteredEntries = widget.entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.name.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Search Bar & Filter Summary
        Row(
          children: [
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search files inside archive...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 14, color: AppTheme.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 13, color: AppTheme.textMuted),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '${filteredEntries.length} found',
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),

        const SizedBox(height: 10),

        // Responsive Master-Detail Split or Stack
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 620;

            if (isCompact) {
              return Column(
                children: [
                  _buildFileListContainer(filteredEntries, maxHeight: 220),
                  if (_selectedEntry != null) ...[
                    const SizedBox(height: 10),
                    _buildSelectedEntryPreview(_selectedEntry!),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left File List
                Expanded(
                  flex: 5,
                  child: _buildFileListContainer(filteredEntries, maxHeight: 520),
                ),
                const SizedBox(width: 10),
                // Right Live Preview Drawer
                Expanded(
                  flex: 6,
                  child: _selectedEntry != null
                      ? _buildSelectedEntryPreview(_selectedEntry!)
                      : Container(
                          height: 520,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C0E12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: const Text('Select a file to inspect and preview', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFileListContainer(List<ZipEntryInfo> list, {required double maxHeight}) {
    if (list.isEmpty) {
      return Container(
        height: maxHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: const Text('No matching files found in archive', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1B1E24)),
        itemBuilder: (context, i) {
          final entry = list[i];
          final isSelected = _selectedEntry?.name == entry.name;

          return InkWell(
            onTap: () => setState(() => _selectedEntry = entry),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: isSelected ? AppTheme.accent.withAlpha(25) : Colors.transparent,
              child: Row(
                children: [
                  Icon(
                    _getFileIcon(entry),
                    size: 14,
                    color: isSelected ? AppTheme.accent : (entry.isDirectory ? const Color(0xFF38BDF8) : AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontWeight: isSelected || entry.isDirectory ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    NumberUtils.formatSizeKb(entry.size),
                    style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Right Preview Panel: Details, Decompressed Text/Image Previews, and Single File Export
  Widget _buildSelectedEntryPreview(ZipEntryInfo entry) {
    final bytes = entry.isDirectory ? null : _getDecompressedBytes(entry.name);
    final ext = p.extension(entry.name).toLowerCase();
    final isImageFile = ['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.ico', '.gif'].contains(ext);

    return Container(
      constraints: const BoxConstraints(minHeight: 380, maxHeight: 520),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Name + Action Buttons
          Row(
            children: [
              Icon(_getFileIcon(entry), size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.name,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!entry.isDirectory) ...[
                if (isImageFile && bytes != null) ...[
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceElevated,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => ImagePreviewDialog.show(
                      context,
                      imageBytes: bytes,
                      fileName: entry.name,
                      onExport: () => _extractSingleEntry(entry),
                    ),
                    icon: const Icon(Icons.fullscreen_rounded, size: 13, color: AppTheme.accent),
                    label: const Text('Enlarge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _extractSingleEntry(entry),
                  icon: const Icon(Icons.download_rounded, size: 12, color: AppTheme.textSecondary),
                  label: const Text('Extract', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),

          // Metadata Details Pill Grid
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildSmallBadge('Size', NumberUtils.formatSizeKb(entry.size)),
              _buildSmallBadge('Compressed', NumberUtils.formatSizeKb(entry.compressedSize)),
              _buildSmallBadge('Method', entry.compressionMethod),
              if (entry.crc32 != null)
                _buildSmallBadge('CRC32', '0x${entry.crc32!.toRadixString(16).toUpperCase()}'),
            ],
          ),

          const SizedBox(height: 8),

          // Live In-App Content Decompression Area
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF090B0E),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppTheme.borderSubtle.withAlpha(40)),
              ),
              clipBehavior: Clip.antiAlias,
              child: entry.isDirectory
                  ? const Center(
                      child: Text('Directory / Folder Node', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                    )
                  : bytes == null
                      ? const Center(
                          child: Text('Could not decompress payload stream', style: TextStyle(fontSize: 10.5, color: AppTheme.danger)),
                        )
                      : _buildEntryEnginePreview(entry, bytes, ext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryEnginePreview(ZipEntryInfo entry, Uint8List bytes, String ext) {
    return UniversalFilePreview(
      key: ValueKey('zip_entry_${entry.name}'),
      bytes: bytes,
      fileName: entry.name,
      explicitFormat: ext,
      onExport: () => _extractSingleEntry(entry),
    );
  }

  Widget _buildSmallBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(ZipEntryInfo entry) {
    if (entry.isDirectory) return Icons.folder_outlined;
    final ext = p.extension(entry.name).toLowerCase();
    if (['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.ico', '.gif'].contains(ext)) {
      return Icons.image_outlined;
    } else if (['.mp4', '.mkv', '.avi', '.mov', '.webm'].contains(ext)) {
      return Icons.video_file_outlined;
    } else if (['.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg'].contains(ext)) {
      return Icons.audio_file_outlined;
    } else if (ext == '.pdf') {
      return Icons.picture_as_pdf_outlined;
    } else if (['.html', '.htm', '.css', '.js', '.dart', '.py', '.json', '.xml', '.yaml'].contains(ext)) {
      return Icons.code_rounded;
    } else if (['.zip', '.jar', '.apk', '.docx', '.xlsx', '.pptx'].contains(ext)) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  /// Tab 2: Overview & Archive Statistics
  Widget _buildOverviewTab() {
    final entries = widget.entries;
    final fileCount = entries.where((e) => !e.isDirectory).length;
    final dirCount = entries.where((e) => e.isDirectory).length;
    final totalUncompressed = entries.fold<int>(0, (sum, e) => sum + e.size);
    final totalCompressed = entries.fold<int>(0, (sum, e) => sum + e.compressedSize);
    final spaceSaved = totalUncompressed > totalCompressed ? totalUncompressed - totalCompressed : 0;
    final ratio = totalUncompressed > 0 ? ((spaceSaved / totalUncompressed) * 100).toStringAsFixed(1) : '0.0';

    // Group by file extension
    final extMap = <String, int>{};
    for (final e in entries) {
      if (!e.isDirectory) {
        final ext = p.extension(e.name).toLowerCase();
        final label = ext.isNotEmpty ? ext.substring(1).toUpperCase() : 'OTHER';
        extMap[label] = (extMap[label] ?? 0) + 1;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Archive Summary & Storage Metrics', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatCard('Total Files', '$fileCount', Icons.insert_drive_file_outlined, const Color(0xFF38BDF8)),
              _buildStatCard('Folders', '$dirCount', Icons.folder_outlined, AppTheme.accent),
              _buildStatCard('Uncompressed', NumberUtils.formatSizeKb(totalUncompressed), Icons.unarchive_outlined, const Color(0xFFA78BFA)),
              _buildStatCard('Compressed', NumberUtils.formatSizeKb(totalCompressed), Icons.archive_outlined, const Color(0xFF34D399)),
              _buildStatCard('Space Saved', '$ratio%', Icons.compress_rounded, const Color(0xFFFBBF24)),
              if (widget.zipOffset != null)
                _buildStatCard('Offset', 'Byte ${widget.zipOffset!}', Icons.place_outlined, AppTheme.primary),
            ],
          ),

          const SizedBox(height: 14),

          // File Format Breakdown
          const Text('Contained File Types Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: extMap.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value} ${entry.value == 1 ? 'file' : 'files'}',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                count,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Tab 3: Central Directory Technical Audit Table
  Widget _buildAuditTab() {
    final entries = widget.entries;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 14, color: Color(0xFFFBBF24)),
              SizedBox(width: 6),
              Text(
                'ZIP Central Directory & Local Headers Audit',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
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
                final e = entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        e.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                        size: 13,
                        color: e.isDirectory ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name,
                              style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${e.compressionMethod} • CRC: ${e.crc32 != null ? '0x${e.crc32!.toRadixString(16).toUpperCase()}' : 'N/A'}',
                              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            NumberUtils.formatSizeKb(e.size),
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          Text(
                            'Comp: ${NumberUtils.formatSizeKb(e.compressedSize)}',
                            style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppTheme.textMuted),
                          ),
                        ],
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

  Widget _buildInfoBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
